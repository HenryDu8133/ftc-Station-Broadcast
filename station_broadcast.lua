-- Station Broadcast System for CC:Tweaked
-- Communicates with central server, receives train information and plays appropriate & departure broadcasts

--  ____    _             _     _                           _                                  _                        _   
-- / ___|  | |_    __ _  | |_  (_)   ___    _ __           | |__    _ __    ___     __ _    __| |   ___    __ _   ___  | |_ 
-- \___ \  | __|  / _` | | __| | |  / _ \  | '_ \          | '_ \  | '__|  / _ \   / _` |  / _` |  / __|  / _` | / __| | __|
--  ___) | | |_  | (_| | | |_  | | | (_) | | | | |         | |_) | | |    | (_) | | (_| | | (_| | | (__  | (_| | \__ \ | |_ 
-- |____/   \__|  \__,_|  \__| |_|  \___/  |_| |_|  _____  |_.__/  |_|     \___/   \__,_|  \__,_|  \___|  \__,_| |___/  \__|
-- By Henry_Du 813367384@qq.com ©                  |_____|                                                                  

-- Set up wireless communication
local modem = peripheral.find("modem") or error("Modem required")
modem.open(65001)  -- Station listening channel
modem.open(65000)  -- Central server channel

-- Audio file paths
local AUDIO_BASE = "/Audio/"
local AUDIO_STATION = "disk/Audio/Station/"

-- Initialize peripherals
local monitor = peripheral.find("monitor")
local allSpeakers = {}
for _, side in pairs(peripheral.getNames()) do
    if peripheral.getType(side) == "speaker" then
        table.insert(allSpeakers, peripheral.wrap(side))
    end
end



local station = peripheral.wrap("back", "train_station") or error("Train station peripheral required")

-- Find all displays
for _, side in pairs(peripheral.getNames()) do
    if peripheral.getType(side) == "monitor" then
        local monitor = peripheral.wrap(side)
        monitor.setTextScale(0.5)
        table.insert(monitor, {name = side, monitor = monitor})
        if not primaryMonitor then
            primaryMonitor = monitor
            primaryMonitor.setTextScale(0.5)
        end
    end
end

local debugMonitor = monitor[1] or monitor or error("Monitor required for debug information")
local debugW, debugH = debugMonitor.getSize()  -- Get the size of the debug monitor

local infoMonitor = monitor[2] or monitor or error("Monitor required for information display")
local infoW, infoH = infoMonitor.getSize()  -- Get the size of the info monitor



-- Debug colors
local debugColors = {
    INFO = colors.white,
    WARNING = colors.yellow,
    ERROR = colors.red,
    DEBUG = colors.cyan,
    SUCCESS = colors.green
}

-- Debug output function
local logLines = {}
local maxLogLines = 100

local function displayLogs()
    debugMonitor.clear()
    debugMonitor.setCursorPos(1, 1)
    debugMonitor.setTextColor(colors.yellow)
    debugMonitor.write("=== Debug Log ===")
    local maxDisplayLines = debugH - 1
    for i = 1, math.min(#logLines, maxDisplayLines) do
        local line = logLines[i]
        if line then
            local y = i + 1  -- 标题占用第一行
            debugMonitor.setCursorPos(1, y)
            
            -- 根据日志级别设置颜色
            if line:match("%[ERROR%]") then
                debugMonitor.setTextColor(colors.red)
            elseif line:match("%[WARNING%]") then
                debugMonitor.setTextColor(colors.orange)
            elseif line:match("%[SUCCESS%]") then
                debugMonitor.setTextColor(colors.lime)
            elseif line:match("%[INFO%]") then
                debugMonitor.setTextColor(colors.white)
            else
                debugMonitor.setTextColor(colors.lightGray)
            end
            
            debugMonitor.write(line)
        end
    end
end

local function debugPrint(level, message)
    local timestamp = os.date("%H:%M:%S")
    local logMessage = string.format("[%s][%s] %s", timestamp, level, message)
    
    table.insert(logLines, 1, logMessage)
    
    if #logLines > maxLogLines then
        table.remove(logLines)
    end
    
    --displayLogs()
end


-- Parse train ID, get train type and number
local function parseTrainId(trainId)
    if not trainId then return "unknown", "" end
    
    -- Check if it's an express train (format: [Rapid]Rapid Name No.x)
    local expressName, expressNum = trainId:match("^%[???%](.+) No%.(%d+)$")
    if expressName and expressNum then
        return "express", expressName, expressNum
    end
    
    -- Check if it's a regular train (format: [Type]Line+4-digit vigesimal (base-20) encoded value)
    local trainType, lineCode, trainNum = trainId:match("^%[(.+)%](.+)(%w%w%w%w)$")
    if trainType and lineCode and trainNum then
        return "regular", trainType, lineCode..trainNum
    end
    
    return "unknown", trainId
end

-- Extract platform number from station name
local function getPlatformNumber(stationName)
    local stationName = stationName or station.getStationName() or "Unknown Station"
    return stationName:match("%d+$") or "1"
end

-- Extract station code from station name
local function getStationCode(stationName)
    local stationName = stationName or station.getStationName() or "Unknown Station"
    return stationName:match("(%u+)%s*%d*$") or "UNK"
end

-- Load station list
local stationList = {}
local function loadStationList()
    stationList = {}
    local file = fs.open("list.txt", "r")
    if file then
        for line in file.readLine do
            local stationCode, files = line:match("^(%d%d%-%d%d)==(.+)$")
            if stationCode and files then
                local fileList = {}
                for file in files:gmatch("[^,]+") do
                    if file and type(file) == "string" and file ~= "" then
                        local cleaned_file = file:gsub("%.dfpwm$", "")
                        table.insert(fileList, cleaned_file)
                    else
                        debugPrint("WARNING", "Skipped invalid file entry: "..tostring(file))
                    end
                end
                if #fileList > 0 then
                    stationList[stationCode] = fileList
                    debugPrint("INFO", "Loaded station " .. stationCode .. " with " .. #fileList .. " audio files")
                end
            end
        end
        file.close()
    else
        debugPrint("WARNING", "Could not open list.txt")
    end
end

-- Load station list at program startup
loadStationList()

-- Get destination
local function getDestination(schedule)
    if not schedule or not schedule.entries then 
        return "Unknown Destination" 
    end
    
    local lastDestination = "Unknown Destination"
    for _, entry in ipairs(schedule.entries) do
        if entry.instruction and entry.instruction.id == "create:destination" then
            lastDestination = entry.instruction.data.text
        end
    end
    local stationCode = lastDestination:match("(%d%d%-%d%d)")
    return stationCode or lastDestination
end


-- Audio playback function
local function playAudioSequence(files)
    for _, file in ipairs(files) do
        local path = AUDIO_STATION..file..".dfpwm"
        if not fs.exists(path) then
            path = AUDIO_BASE..file..".dfpwm"
            if not fs.exists(path) then
                debugPrint("ERROR", "Audio file not found: " .. file)
                return
            end
        end
        
        if fs.exists(path) then
            print("Playing:", path)
            shell.run("austream "..path.." volume=3.0")
        else
            print("ERROR: NO File", path)
        end
    end
end


-- Play train arrival announcement
local function playArrivalAnnouncement(trainId, trainType, platform, destination)
    local stationCode = destination:match("(%d%d%-%d%d)")
    if not stationCode then
        debugPrint("ERROR", "Invalid station code format in: "..destination)
        return
    end
    stationCode = stationCode:gsub("[^%d-]", "")
    debugPrint("DEBUG", "Looking for station code: "..stationCode)
    debugPrint("INFO", "Playing arrival announcement for train " .. trainId .. " to platform " .. platform)
    debugPrint("DEBUG", "Destination: " .. (destination or "nil"))
     local stationCode = destination:match("(%d%d%-%d%d)") or destination
    debugPrint("DEBUG", "Looking for station code: "..stationCode)
    
    if stationList[stationCode] then
        for _, file in ipairs(stationList[stationCode]) do
            local jaFile = "ja-"..file
            local path = AUDIO_STATION..jaFile..".dfpwm"
            if not fs.exists(path) then
                path = AUDIO_BASE..jaFile..".dfpwm"
            end
            
            if fs.exists(path) then
                shell.run("austream "..path.." volume=3.0")
            else
                --debugPrint("WARNING", "No Japanese audio found for "..stationCode)
            end
    end
    
    local sequence = {}
    
    -- Start tone
    table.insert(sequence, "ksts")
    
    -- Japanese part
    table.insert(sequence, "ja-lcjz1")
    table.insert(sequence, "ja-"..tostring(tonumber(platform)).."zt")
    table.insert(sequence, trainType == "express" and "ja-tj" or "ja-pt")
    
    -- Get destination audio (Japanese)
    if destination then
        debugPrint("DEBUG", "Searching Japanese audio for " .. destination)
        local foundJapaneseAudio = false
        for destName, audioFiles in pairs(stationList) do
            if string.match(destName, destination) then
                debugPrint("DEBUG", "Found matching station: " .. destName)
                for _, audioFile in ipairs(audioFiles) do
                    if audioFile:match("^ja-") then
                        local cleaned = tostring(audioFile:gsub(".dfpwm$", ""))
                        table.insert(sequence, cleaned)
                        foundJapaneseAudio = true
                        debugPrint("DEBUG", "Added Japanese audio: " .. cleaned)
                        break
                    end
                end
                if foundJapaneseAudio then break end
            end
        end
        if not foundJapaneseAudio then
            debugPrint("WARNING", "No Japanese audio found for " .. destination)
        end
    end
    
    table.insert(sequence, "ja-lcjz2")
    
    -- Chinese part
    table.insert(sequence, "ch-lcjz1")
    table.insert(sequence, "ch-"..tostring(tonumber(platform)).."zt")
    table.insert(sequence, "ch-lcjz2")
    table.insert(sequence, trainType == "express" and "ch-tj" or "ch-pt")
    table.insert(sequence, "ch-lcjz3")

    if destination then
        local foundChineseAudio = false
        for destName, audioFiles in pairs(stationList) do
            if destination == destName then -- Exact match
                for _, audioFile in ipairs(audioFiles) do
                    if audioFile:match("^ch-") then
                        table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                        foundChineseAudio = true
                        break
                    end
                end
                if foundChineseAudio then break end
            end
        end
    end
    
    table.insert(sequence, "ch-lcjz4")
    
    -- English part
    table.insert(sequence, "en-lcjz1")
    table.insert(sequence, "en-"..tostring(tonumber(platform)).."zt")
    table.insert(sequence, "en-lcjz2")
    table.insert(sequence, trainType == "express" and "en-tj" or "en-pt")
    table.insert(sequence, "en-lcjz3")
    
    -- Get destination audio (English)
    if destination then
        local foundEnglishAudio = false
        for destName, audioFiles in pairs(stationList) do
            if destination == destName then -- Exact match
                for _, audioFile in ipairs(audioFiles) do
                    if audioFile:match("^en-") then
                        table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                        foundEnglishAudio = true
                        break
                    end
                end
                if foundEnglishAudio then break end
            end
        end
    end
    
    table.insert(sequence, "en-lcjz4")
    
    -- Play audio sequence
    playAudioSequence(sequence)
end
end
-- Play train departure announcement
local function playDepartureAnnouncement(trainId, trainType, platform, destination, stationTime)
    debugPrint("INFO", "Playing departure announcement for train " .. trainId .. " from platform " .. platform .. " with station time: " .. stationTime .. "s")
    
    local sequence = {}
    
    -- Check if station time is less than or equal to 60 seconds for short version
    local isShortVersion = stationTime <= 60
    if isShortVersion then
        debugPrint("INFO", "Using short departure announcement (station time <= 60s)")
    else
        debugPrint("INFO", "Using regular departure announcement (station time > 60s)")
    end
    
    -- Start tone
    table.insert(sequence, "fc")
    
    if isShortVersion then
        
        -- Japanese part
        table.insert(sequence, "ja-"..tostring(tonumber(platform)).."zt")
        
        -- Get destination audio (Japanese)
        if destination then
            local foundJapaneseAudio = false
            for destName, audioFiles in pairs(stationList) do
                if destination == destName then -- Exact match
                    for _, audioFile in ipairs(audioFiles) do
                        if audioFile:match("^ja-") then
                            table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                            foundJapaneseAudio = true
                            break
                        end
                    end
                    if foundJapaneseAudio then break end
                end
            end
        end
        table.insert(sequence, "ja-lcczjd1")
        
        -- Chinese part
        table.insert(sequence, "ch-"..tostring(tonumber(platform)).."zt")
        table.insert(sequence, "ch-lcczjd1")
        
        -- Get destination audio (Chinese)
        if destination then
            local foundChineseAudio = false
            for destName, audioFiles in pairs(stationList) do
                if destination == destName then -- Exact match
                    for _, audioFile in ipairs(audioFiles) do
                        if audioFile:match("^ch-") then
                            table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                            foundChineseAudio = true
                            break
                        end
                    end
                    if foundChineseAudio then break end
                end
            end
        end
        table.insert(sequence, "ch-lcczjd2")
        
        -- English part
        table.insert(sequence, "en-lcczjd1")
        table.insert(sequence, "en-"..tostring(tonumber(platform)).."zt")
        table.insert(sequence, "en-lcczjd2")
        
        -- Get destination audio (English)
        if destination then
            local foundEnglishAudio = false
            for destName, audioFiles in pairs(stationList) do
                if destination == destName then -- Exact match
                    for _, audioFile in ipairs(audioFiles) do
                        if audioFile:match("^en-") then
                            table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                            foundEnglishAudio = true
                            break
                        end
                    end
                    if foundEnglishAudio then break end
                end
            end
        end
        table.insert(sequence, "en-lcczjd3")
    else
        -- Original long version
        -- Japanese part
        table.insert(sequence, "ja-"..tostring(tonumber(platform)).."zt")
        table.insert(sequence, "ja-lccz1")
        table.insert(sequence, trainType == "express" and "ja-tj" or "ja-pt")
        
        -- Get destination audio (Japanese)
        if destination then
            local foundJapaneseAudio = false
            for destName, audioFiles in pairs(stationList) do
                if destination == destName then -- Exact match
                    for _, audioFile in ipairs(audioFiles) do
                        if audioFile:match("^ja-") then
                            table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                            foundJapaneseAudio = true
                            break
                        end
                    end
                    if foundJapaneseAudio then break end
                end
            end
            if not foundJapaneseAudio then
                debugPrint("WARNING", "No Japanese audio found for " .. destination)
            end
        end
        table.insert(sequence, "ja-lccz3")
        
        -- Chinese part
        table.insert(sequence, "ch-"..tostring(tonumber(platform)).."zt")
        table.insert(sequence, "ch-lccz1")
        table.insert(sequence, trainType == "express" and "ch-tj" or "ch-pt")
        table.insert(sequence, "ch-lccz2")
        
        -- Get destination audio (Chinese)
        if destination then
            local foundChineseAudio = false
            for destName, audioFiles in pairs(stationList) do
                if destination == destName then -- Exact match
                    for _, audioFile in ipairs(audioFiles) do
                        if audioFile:match("^ch-") then
                            table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                            foundChineseAudio = true
                            break
                        end
                    end
                    if foundChineseAudio then break end
                end
            end
        end
        table.insert(sequence, "ch-lccz3")
        
        -- English part
        table.insert(sequence, "en-lccz1")
        table.insert(sequence, trainType == "express" and "en-tj" or "en-pt")
        table.insert(sequence, "en-lccz2")
        table.insert(sequence, "en-"..tostring(tonumber(platform)).."zt")
        table.insert(sequence, "en-lccz3")

        -- Get destination audio (English)
        if destination then
            local foundEnglishAudio = false
            for destName, audioFiles in pairs(stationList) do
                if destination == destName then -- Exact match
                    for _, audioFile in ipairs(audioFiles) do
                        if audioFile:match("^en-") then
                            table.insert(sequence, tostring(audioFile:gsub(".dfpwm", ""))) -- 确保移除.dfpwm后缀
                            foundEnglishAudio = true
                            break
                        end
                    end
                    if foundEnglishAudio then break end
                end
            end
        end
        
        table.insert(sequence, "en-lccz4")
    end
    
    -- Play audio sequence
    playAudioSequence(sequence)
end

-- Status variables
local currentTrainInfo = nil
local expectedTrains = {}
local departingBroadcastPlayed = false
local arrivalBroadcastPlayed = false
local stationRegistered = false
local currentTimeToBroadcast = "0:00"

-- Register station with central server
local function registerStation()
    local stationName = station.getStationName()
    local stationCode = getStationCode(stationName)
    
    debugPrint("INFO", "Registering station " .. stationName .. " (" .. stationCode .. ") with central server")
    
    modem.transmit(65000, 65001, {
        type = "station_register",
        stationName = stationName,
        stationCode = stationCode
    })
    
    return true
end

-- Send train arrival info to central server
local function sendTrainArrival(trainId, schedule)
    local stationName = station.getStationName()
    
    debugPrint("INFO", "Sending train arrival info for " .. trainId .. " at " .. stationName)
    
    modem.transmit(65000, 65001, {
        type = "train_arrival",
        trainId = trainId,
        stationName = stationName,
        schedule = schedule,
        arrivalTime = os.time()
    })
    
    return true
end

-- Send train departure info to central server
local function sendTrainDeparture(trainId, schedule, stationTime)
    local stationName = station.getStationName()
    
    debugPrint("INFO", "Sending train departure info for " .. trainId .. " from " .. stationName)
    
    modem.transmit(65000, 65001, {
        type = "train_departure",
        trainId = trainId,
        stationName = stationName,
        schedule = schedule,
        departureTime = os.time(),
        stationTime = stationTime
    })
    
    return true
end

local function getTimeInSeconds()
    return os.epoch("utc") / 1000
end


local hasPlayedArrivalTone = false
local departingBroadcastPlayed = false 

local function checkTrainArrival() 
    if station.isTrainPresent() then
        if currentTrainInfo then
            local currentTime = getTimeInSeconds()
            local remainingTime = math.max(0, currentTrainInfo.scheduledDepartureTime - currentTime)
            local minutes = math.floor(remainingTime / 60)
            local seconds = math.floor(remainingTime % 60)
            currentTimeToBroadcast = string.format("%d:%02d", minutes, seconds)
            if not departingBroadcastPlayed and remainingTime <= 50 then
                playDepartureAnnouncement(currentTrainInfo.trainId, currentTrainInfo.trainType, currentTrainInfo.platform, currentTrainInfo.destination, currentTrainInfo.scheduledDepartureTime - currentTrainInfo.arrivalTime)
                departingBroadcastPlayed = true
            end
        else
            local trainId = station.getTrainName()
            local schedule = station.getSchedule()
            local currentTime = getTimeInSeconds()
            
            if not schedule then
                infoMonitor.setCursorPos(1, 12)
                infoMonitor.setTextColor(colors.red)
                infoMonitor.write("No Schedule")
                return
            end
            
            if not hasPlayedArrivalTone then
                playAudioSequence({"ksts"})
                hasPlayedArrivalTone = true
            end
            sendTrainArrival(trainId, schedule)
            local stationTime = 60
            if schedule and schedule.entries then
                for _, entry in ipairs(schedule.entries) do
                    if entry.instruction and entry.instruction.id == "create:destination" 
                       and entry.instruction.data.text == station.getStationName() and entry.conditions then
                        for _, condition in ipairs(entry.conditions) do
                            for _, subCondition in ipairs(condition) do
                                if subCondition.id == "create:delay" then
                                    stationTime = subCondition.data.value
                                    break
                                end
                            end
                        end
                    end
                end
            end
            modem.transmit(65000, 65001, {
                type = "request_station_time",
                trainId = trainId,
                stationName = station.getStationName()
            })
            for _, trainInfo in ipairs(expectedTrains) do
                if trainInfo.trainId == trainId then
                    stationTime = trainInfo.stationTime or stationTime
                    break
                end
            end
            currentTrainInfo = {
                trainId = trainId,
                trainType = parseTrainId(trainId),
                platform = getPlatformNumber(),
                destination = getDestination(schedule),
                schedule = schedule,
                arrivalTime = currentTime, 
                scheduledDepartureTime = currentTime + stationTime 
            }
        if channel == 65000 and message.type == "station_time_response" then
            for _, trainInfo in ipairs(expectedTrains) do
                if trainInfo.trainId == message.trainId then
                    trainInfo.stationTime = message.stationTime
                    break
                end
            end
            if currentTrainInfo and currentTrainInfo.trainId == message.trainId then
                currentTrainInfo.scheduledDepartureTime = currentTrainInfo.arrivalTime + message.stationTime
            end
        end
    end
    else
        if currentTrainInfo then
            local stationTime = math.floor(getTimeInSeconds() - currentTrainInfo.arrivalTime)
            sendTrainDeparture(currentTrainInfo.trainId, currentTrainInfo.schedule, stationTime)
        end
        currentTrainInfo = nil
        departingBroadcastPlayed = false
        hasPlayedArrivalTone = false
    end
end

-- Check expected trains
local function checkExpectedTrains()
    local currentTime = getTimeInSeconds() 
    for i, trainInfo in ipairs(expectedTrains) do
        debugPrint("DEBUG", "Time diff: "..(trainInfo.expectedArrival - currentTime))
        if not trainInfo.arrivalBroadcastPlayed and trainInfo.expectedArrival - currentTime <= 30 then
            playArrivalAnnouncement(trainInfo.trainId, trainInfo.trainType, trainInfo.platform, trainInfo.destination)
            trainInfo.arrivalBroadcastPlayed = true
            debugPrint("INFO", "Playing arrival announcement for expected train " .. trainInfo.trainId)
        end
        if station.isTrainPresent() or currentTime > trainInfo.expectedArrival + 300 then
            table.remove(expectedTrains, i)
            break
        end
    end
end

-- Display train information
local function displayTrainInfo()
    infoMonitor.clear()
    infoMonitor.setCursorPos(1, 1)
    infoMonitor.setTextColor(colors.yellow)
    infoMonitor.write("=== Station Information ===")
    
    infoMonitor.setCursorPos(1, 3)
    infoMonitor.setTextColor(colors.white)
    infoMonitor.write("Station: " .. (station.getStationName() or "Unknown"))
    
    infoMonitor.setCursorPos(1, 4)
    infoMonitor.setTextColor(colors.white)
    infoMonitor.write("Current Time: " .. os.date("%H:%M:%S"))
    
    -- Display current train info
    if station.isTrainPresent() and currentTrainInfo then
        infoMonitor.setCursorPos(1, 6)
        infoMonitor.setTextColor(colors.lime)
        infoMonitor.write("Current Train:")
        
        infoMonitor.setCursorPos(1, 7)
        infoMonitor.setTextColor(colors.white)
        infoMonitor.write("ID: " .. currentTrainInfo.trainId)
        
        infoMonitor.setCursorPos(1, 8)
        infoMonitor.write("Type: " .. (currentTrainInfo.trainType == "express" and "Express" or "Local"))
        
        infoMonitor.setCursorPos(1, 9)
        infoMonitor.write("Platform: " .. currentTrainInfo.platform)
        
        infoMonitor.setCursorPos(1, 10)
        infoMonitor.write("Destination: " .. currentTrainInfo.destination)
        
        infoMonitor.setCursorPos(1, 11)
        infoMonitor.write("Departure in: " .. currentTimeToBroadcast)  -- 修复：确保正确显示
    else
        infoMonitor.setCursorPos(1, 6)
        infoMonitor.setTextColor(colors.orange)
        infoMonitor.write("No train at station")
    end
    
    -- Display expected trains
    if #expectedTrains > 0 then
        infoMonitor.setCursorPos(1, 13)
        infoMonitor.setTextColor(colors.cyan)
        infoMonitor.write("Expected Trains:")
        
        local line = 14
        for i, trainInfo in ipairs(expectedTrains) do
            if line > infoH - 2 then break end
            
            infoMonitor.setCursorPos(1, line)
            infoMonitor.setTextColor(colors.white)
            infoMonitor.write(trainInfo.trainId .. " from " .. trainInfo.fromStation)
            
            line = line + 1
            infoMonitor.setCursorPos(1, line)
            infoMonitor.write("Arrival: " .. os.date("%H:%M:%S", trainInfo.expectedArrival))
            
            line = line + 1
            infoMonitor.setCursorPos(1, line)
            infoMonitor.write("ETA: " .. math.floor((trainInfo.expectedArrival - os.time()) / 60) .. ":" .. string.format("%02d", (trainInfo.expectedArrival - os.time()) % 60))
            
            line = line + 2
        end
    end
    if #expectedTrains == 0 then
        monitor.write(" *ftc-bc.sys.")
        return
    end
    
    for i, train in ipairs(expectedTrains) do
        if i > 5 then break end
        
        if not train.schedule or #train.schedule == 0 then
            monitor.write("No Schedule")
        else
            monitor.write(train.trainType.." "..train.fromStation.." -> "..train.destination)
        end
        monitor.setCursorPos(1, i*2+1)
    end
    
    -- Display status information
    infoMonitor.setCursorPos(1, infoH)
    infoMonitor.setTextColor(colors.lime)
    infoMonitor.write("System running - " .. os.date("%Y-%m-%d"))
end

local function handleAudioUpdate(message)
    if message and message.type == "audio_update" then
            fs.delete(AUDIO_STATION)
            fs.makeDir(AUDIO_STATION)
            for name, content in pairs(message.files) do
                local f = fs.open(fs.combine(AUDIO_STATION, name), "wb")
                f.write(content)
                f.close()
            end
            debugPrint("SYNC", "Updated "..message.total.." audio files")
       end
end
-- Handle received messages
local function handleMessages()
    local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
    if type(message) == "table" then
        if channel == 65001 and message.type == "train_notice" then
            -- Received train notice
            local stationName = station.getStationName()
            
            -- Check if message is for this station
            if message.toStation == stationName then
                debugPrint("INFO", "Received train notice for " .. message.trainId .. " from " .. message.fromStation)
                
                -- Parse train type
                local trainType = parseTrainId(message.trainId)
                
                -- Add to expected trains list
                table.insert(expectedTrains, {
                    trainId = message.trainId,
                    trainType = trainType,
                    fromStation = message.fromStation,
                    platform = getPlatformNumber(),
                    destination = getDestination(message.schedule),
                    expectedArrival = message.expectedArrival,
                    stationTime = message.stationTime,
                    schedule = message.schedule,
                    arrivalBroadcastPlayed = false
                })
                
                -- Sort by expected arrival time
                table.sort(expectedTrains, function(a, b)
                    return a.expectedArrival < b.expectedArrival
                end)
            end
        elseif channel == 65000 and message.type == "station_register_ack" then
            -- Received station registration confirmation
            if message.stationName == station.getStationName() then
                stationRegistered = true
                debugPrint("SUCCESS", "Station registration confirmed by central server")
            end
        elseif channel == 65000 and message.type == "audio_update" then
            handleAudioUpdate(message)
        end
    end
end

local SYNC_INTERVAL = 10
local lastSyncTime = 0


local function asyncTXTFiles()
    debugPrint("INFO", "Starting audio files synchronization...")
            modem.transmit(65000, 65001, {
                type = "request_list_txt",
                stationName = station.getStationName()
            })
            local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
            if message.type == "list_txt" then
                local file = fs.open("list.txt", "w")
                file.write(message.content)
                file.close()
                loadStationList()
                debugPrint("INFO", "Updated list.txt from central server")
                lastListSyncTime = os.time()
        end
end


local elapsedSeconds = 0
-- Run multiple tasks in parallel
parallel.waitForAny(
    function()
        -- Main loop
        local updateInterval = 0.1 -- 100ms
 
        while true do
            checkExpectedTrains()
            checkTrainArrival()
            displayTrainInfo()
            local loopStartTime = os.epoch("utc")
            if elapsedSeconds >= 240 then
                elapsedSeconds = 0
            end
            
            if os.time() - lastSyncTime > SYNC_INTERVAL then
                parallel.waitForAny(
                    asyncTXTFiles()
                )
                lastSyncTime = os.time()
            end
            local endTime = os.epoch("utc")
            local elapsed = (endTime - loopStartTime) / 1000
            local sleepTime = math.max(0, updateInterval - elapsed)
            if sleepTime > 0 then
                os.sleep(sleepTime)
            end
        end

    end,
    function()
        -- Message handling loop
        while true do
            handleMessages()
        end
    end,
    function()
        -- Periodically re-register station
        while true do
            os.sleep(10) 
            handleAudioUpdate()
            if not stationRegistered then
                registerStation()
            end
            stationRegistered = false  -- Reset registration status, wait for next confirmation
        end
    end,
    function()
        -- Periodically re-register station
        while true do
            os.sleep(1) 
            elapsedSeconds = elapsedSeconds + 1
        end
    end
)



