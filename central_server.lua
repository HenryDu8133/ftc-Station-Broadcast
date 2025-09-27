-- Central Processing Server
-- Receives train data, stores to database, and sends alerts to next station

--   ____                  _                    _           ____                                      
--  / ___|   ___   _ __   | |_   _ __    __ _  | |         / ___|    ___   _ __  __   __   ___   _ __ 
-- | |      / _ \ | '_ \  | __| | '__|  / _` | | |         \___ \   / _ \ | '__| \ \ / /  / _ \ | '__|
-- | |___  |  __/ | | | | | |_  | |    | (_| | | |          ___) | |  __/ | |     \ V /  |  __/ | |   
--  \____|  \___| |_| |_|  \__| |_|     \__,_| |_|  _____  |____/   \___| |_|      \_/    \___| |_|   
--   By Henry_Du 813367384@qq.com ©                |_____|                                            


-- Set up wireless communication
local modem = peripheral.find("modem") or error("Need a modem")
modem.open(65000)  -- Central server channel

local AUDIO_STATION_DIR = "disk/Audio/Station/"

-- Initialize peripherals
local monitors = {}
local primaryMonitor = nil

-- Find all displays
for _, side in pairs(peripheral.getNames()) do
    if peripheral.getType(side) == "monitor" then
        local monitor = peripheral.wrap(side)
        table.insert(monitors, {name = side, monitor = monitor})
        if not primaryMonitor then
            primaryMonitor = monitor
        end
    end
end

if #monitors == 0 then
    error("At least ONE MONITOR")
end





-- Adjust display scale 
local function adjustTextScale(monitor)
    monitor.setTextScale(0.8)
    return monitor.getSize()
end

-- Scale all displays
local monitorSizes = {}
for _, monitorData in ipairs(monitors) do
    local w, h = adjustTextScale(monitorData.monitor)
    monitorSizes[monitorData.name] = {width = w, height = h}
end

-- Debug Colors
local debugColors = {
    INFO = colors.white,
    WARNING = colors.yellow,
    ERROR = colors.red,
    DEBUG = colors.cyan,
    SUCCESS = colors.green
}

-- Debug
function debugPrint(level, message, targetMonitor)
    local monitor = targetMonitor or primaryMonitor
    
    if monitor then
        local width, height = monitor.getSize()
        local x, y = monitor.getCursorPos()
        local lines = {}
        for line in message:gmatch("[^\n]+") do
            while #line > width do
                table.insert(lines, line:sub(1, width))
                line = line:sub(width + 1)
            end
            table.insert(lines, line)
        end
        if y + #lines - 1 > height then
            monitor.scroll(y + #lines - height)
            y = height - #lines + 1
        end
        monitor.setTextColor(debugColors[level] or colors.white)
        for i, line in ipairs(lines) do
            monitor.setCursorPos(1, y + i - 1)
            monitor.write(os.date("[%H:%M:%S]")..":"..(level and "["..level.."] " or "")..line)
        end
        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1, math.min(y + #lines, height))
    else
        print(os.date("[%H:%M:%S]")..":"..(level and "["..level.."] " or "")..message)
    end
end

-- Database initialization  
-- Add new tables to the database structure  
local database = {  
    stations = {},    -- Station information  
    trains = {},      -- Train data  
    segments = {},    -- Segment running times  
    stationTimes = {},-- Dwell times at stations  
    schedules = {},   -- Timetable data  
    runningTimes = {} -- Historical segment running times  
}  


-- Save database to file
local function saveDatabase()
    local file = fs.open("train_database.db", "w")
    if file then
        file.write(textutils.serialize(database))
        file.close()
        debugPrint("SUCCESS", "Database saved successfully")
        return true
    end
    debugPrint("ERROR", "Failed to save database")
    return false
end

-- Load database from file
local function loadDatabase()
    if fs.exists("train_database.db") then
        local file = fs.open("train_database.db", "r")
        if file then
            local data = file.readAll()
            file.close()
            
            local success, result = pcall(textutils.unserialize, data)
            if success and type(result) == "table" then
                database = result
                debugPrint("SUCCESS", "Database loaded successfully")
                return true
            end
        end
    end
    
    debugPrint("WARNING", "No database found or failed to load, using empty database")
    return false
end

-- Parse train ID, get train type and number
local function parseTrainId(trainId)
    if not trainId then return "unknown", "" end
    
    -- Check if it's an express train (format: [Rapid]Rapid Name No.x)
    local expressName, expressNum = trainId:match("^%[特急%](.+) No%.(%d+)$")
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

-- Get next station Info
local function getNextStation(schedule, currentStation)
    if not schedule or not schedule.entries then return nil end
    
    local foundCurrent = false
    for _, entry in ipairs(schedule.entries) do
        if entry.instruction and entry.instruction.id == "create:destination" then
            local stationName = entry.instruction.data.text
            
            if foundCurrent then
                return stationName
            end
            
            if stationName == currentStation then
                foundCurrent = true
            end
        end
    end
    
    return nil
end

-- Calculate segment running time
local function calculateSegmentTime(trainId, fromStation, toStation, arrivalTime)
    local segmentKey = fromStation .. "-" .. toStation
    
    if database.segments[segmentKey] and database.segments[segmentKey].departureTime then
        local departureTime = database.segments[segmentKey].departureTime
        local runningTime = math.floor(arrivalTime - departureTime)
        if not database.segments[segmentKey].runningTimes then
            database.segments[segmentKey].runningTimes = {}
        end
        
        table.insert(database.segments[segmentKey].runningTimes, runningTime)
        local sum = 0
        local count = 0
        for _, time in ipairs(database.segments[segmentKey].runningTimes) do
            sum = sum + time
            count = count + 1
        end
        database.segments[segmentKey].averageTime = math.floor(sum / count)
        
        debugPrint("INFO", "Segment " .. segmentKey .. " running time: " .. runningTime .. "s, average: " .. database.segments[segmentKey].averageTime .. "s")
        return runningTime
    end
    
    return nil
end

-- Get average segment running time
local function getAverageSegmentTime(fromStation, toStation)
    local segmentKey = fromStation .. "-" .. toStation
    
    if database.segments[segmentKey] and database.segments[segmentKey].averageTime then
        return database.segments[segmentKey].averageTime
    end
    
    return 10
end

-- Process train arrival message
local HISTORY_FILE = "train_history.db"


local function saveHistoryData(eventType, trainId, stationName, timestamp)
    local file = fs.open(HISTORY_FILE, "a")
    if file then
        file.writeLine(textutils.serialize({
            type = eventType,
            trainId = trainId,
            station = stationName,
            time = timestamp,
            date = os.date("%Y-%m-%d %H:%M:%S", timestamp)
        }))
        file.close()
    end
end

local function handleTrainArrival(trainId, stationName, schedule, arrivalTime) 
    saveHistoryData("arrival", trainId, stationName, arrivalTime)
    if schedule and schedule.entries then
        for _, entry in ipairs(schedule.entries) do
            if entry.instruction and entry.instruction.id == "create:destination" 
               and entry.instruction.data.text == stationName and entry.conditions then
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
    
    if not database.trains[trainId] then
        database.trains[trainId] = {}
    end
    
    local train = database.trains[trainId]
    train.currentStation = stationName
    train.arrivalTime = arrivalTime
    train.schedule = schedule
    

    if train.lastStation then
        calculateSegmentTime(trainId, train.lastStation, stationName, arrivalTime)
    end
    
    -- Save
    saveDatabase()
    
    debugPrint("INFO", "Train " .. trainId .. " arrived at " .. stationName .. " at " .. os.date("%H:%M:%S", arrivalTime))
    return true
end

-- Process train departure message
local function handleTrainDeparture(trainId, stationName, schedule, departureTime) 
    if not database.trains[trainId] then
        database.trains[trainId] = {}
    end
    
    local train = database.trains[trainId]
    train.lastStation = stationName
    train.departureTime = departureTime
    
    local nextStation = getNextStation(schedule, stationName)
    if nextStation then
        local segmentKey = stationName .. "-" .. nextStation
        
        if not database.segments[segmentKey] then
            database.segments[segmentKey] = {}
        end
        
        database.segments[segmentKey].departureTime = departureTime
        
        if not database.stationTimes[trainId] then
            database.stationTimes[trainId] = {}
        end
        
        database.stationTimes[trainId][stationName] = stationTime

        local averageTime = getAverageSegmentTime(stationName, nextStation)
        local expectedArrival = departureTime + averageTime
        
        local avgStationTime = 60
        if database.stationTimes[trainId] and database.stationTimes[trainId][stationName] then
            avgStationTime = database.stationTimes[trainId][stationName]
        end
        
        modem.transmit(65001, 65000, {
            type = "train_notice",
            trainId = trainId,
            fromStation = stationName,
            toStation = nextStation,
            expectedArrival = expectedArrival,
            stationTime = avgStationTime,
            schedule = schedule
        })
        
        debugPrint("INFO", "Sent train notice to " .. nextStation .. ", expected arrival: " .. os.date("%H:%M:%S", expectedArrival))
    end
    
    -- Save
    saveDatabase()
    
    debugPrint("INFO", "Train " .. trainId .. " departed from " .. stationName .. " at " .. os.date("%H:%M:%S", departureTime))
    return true
end

-- Display server status  
local function displayServerStatus()
    primaryMonitor.clear()
    primaryMonitor.setCursorPos(1, 1)
    primaryMonitor.setTextColor(colors.yellow)
    primaryMonitor.write("=== Central Train Server ===")
    
    primaryMonitor.setCursorPos(1, 3)
    primaryMonitor.setTextColor(colors.white)
    primaryMonitor.write("Server Time: " .. os.date("%H:%M:%S"))
    
    primaryMonitor.setCursorPos(1, 5)
    primaryMonitor.setTextColor(colors.lime)
    local trainCount = 0
    for _ in pairs(database.trains) do trainCount = trainCount + 1 end
    primaryMonitor.write("Active Trains: " .. trainCount)
    
    primaryMonitor.setCursorPos(1, 6)
    local stationCount = 0
    for _ in pairs(database.stations) do stationCount = stationCount + 1 end
    primaryMonitor.write("Known Stations: " .. stationCount)
    
    primaryMonitor.setCursorPos(1, 7)
    local segmentCount = 0
    for _ in pairs(database.segments) do segmentCount = segmentCount + 1 end
    primaryMonitor.write("Tracked Segments: " .. segmentCount)
    
    primaryMonitor.setCursorPos(1, 9)
    primaryMonitor.setTextColor(colors.cyan)
    primaryMonitor.write("Recent Train Activity:")
    
    local line = 10
    local w, h = primaryMonitor.getSize()
    for trainId, train in pairs(database.trains) do
        if line > h - 2 then break end
        
        primaryMonitor.setCursorPos(1, line)
        primaryMonitor.setTextColor(colors.white)
        local trainType, trainInfo = parseTrainId(trainId)
        local displayName = trainId
        if trainType == "express" then
            primaryMonitor.setTextColor(colors.orange)
            displayName = "[Express] " .. trainInfo
        end
        
        primaryMonitor.write(displayName .. ": " .. (train.currentStation or "Unknown"))
        line = line + 1
    end
    
    primaryMonitor.setCursorPos(1, h)
    primaryMonitor.setTextColor(colors.lime)
    primaryMonitor.write("Server running - " .. os.date("%Y-%m-%d"))
    
    if #monitors > 1 then
        local secondMonitor = monitors[2].monitor
        secondMonitor.clear()
        secondMonitor.setCursorPos(1, 1)
        secondMonitor.setTextColor(colors.yellow)
        secondMonitor.write("=== Train Details ===")
        
        local detailLine = 3
        local w2, h2 = secondMonitor.getSize()
        
        for trainId, train in pairs(database.trains) do
            if detailLine > h2 - 3 then break end
            
            secondMonitor.setCursorPos(1, detailLine)
            secondMonitor.setTextColor(colors.orange)
            secondMonitor.write(trainId)
            detailLine = detailLine + 1
            
            secondMonitor.setCursorPos(2, detailLine)
            secondMonitor.setTextColor(colors.white)
            secondMonitor.write("Current: " .. (train.currentStation or "Unknown"))
            detailLine = detailLine + 1
            
            secondMonitor.setCursorPos(2, detailLine)
            secondMonitor.write("Last: " .. (train.lastStation or "Unknown"))
            detailLine = detailLine + 1
            
            if train.arrivalTime then
                secondMonitor.setCursorPos(2, detailLine)
                secondMonitor.write("Arrival: " .. os.date("%H:%M:%S", train.arrivalTime))
                detailLine = detailLine + 1
            end
            
            if train.departureTime then
                secondMonitor.setCursorPos(2, detailLine)
                secondMonitor.write("Departure: " .. os.date("%H:%M:%S", train.departureTime))
                detailLine = detailLine + 1
            end
            
            detailLine = detailLine + 1 
        end
    end
    
    if #monitors > 2 then
        local thirdMonitor = monitors[3].monitor
        thirdMonitor.clear()
        thirdMonitor.setCursorPos(1, 1)
        thirdMonitor.setTextColor(colors.yellow)
        thirdMonitor.write("=== Station & Segment Info ===")
        
        local infoLine = 3
        local w3, h3 = thirdMonitor.getSize()
        
        thirdMonitor.setCursorPos(1, infoLine)
        thirdMonitor.setTextColor(colors.cyan)
        thirdMonitor.write("Registered Stations:")
        infoLine = infoLine + 1
        
        for stationName, station in pairs(database.stations) do
            if infoLine > h3 - 10 then break end
            
            thirdMonitor.setCursorPos(2, infoLine)
            thirdMonitor.setTextColor(colors.white)
            thirdMonitor.write(stationName .. " (" .. (station.code or "???") .. ")")
            infoLine = infoLine + 1
        end
        
        infoLine = infoLine + 1
        thirdMonitor.setCursorPos(1, infoLine)
        thirdMonitor.setTextColor(colors.cyan)
        thirdMonitor.write("Segment Times:")
        infoLine = infoLine + 1
        
        for segmentKey, segment in pairs(database.segments) do
            if infoLine > h3 - 2 then break end
            if segment.averageTime then
                thirdMonitor.setCursorPos(2, infoLine)
                thirdMonitor.setTextColor(colors.white)
                thirdMonitor.write(segmentKey .. ": " .. segment.averageTime .. "s")
                infoLine = infoLine + 1
            end
        end
    end
end

local messageQueue = {}
local processingMessage = false

local function queueMessage(message, replyChannel)
    table.insert(messageQueue, {message = message, replyChannel = replyChannel})
end


local function processMessageQueue()
    if processingMessage or #messageQueue == 0 then
        return
    end
    
    processingMessage = true
    local messageData = table.remove(messageQueue, 1)
    local message = messageData.message
    local replyChannel = messageData.replyChannel
    
    if message.type == "request_station_time" then
        local stationTime = 60 
        if database.stationTimes[message.trainId] and database.stationTimes[message.trainId][message.stationName] then
            stationTime = database.stationTimes[message.trainId][message.stationName]
        end

        modem.transmit(replyChannel, 65000, {
            type = "station_time_response",
            trainId = message.trainId,
            stationName = message.stationName,
            stationTime = stationTime
        })
    end
    
    if message.type == "train_arrival" then
        handleTrainArrival(message.trainId, message.stationName, message.schedule, message.arrivalTime)
    elseif message.type == "train_departure" then
        handleTrainDeparture(message.trainId, message.stationName, message.schedule, message.departureTime, message.stationTime)
    elseif message.type == "station_register" then
        database.stations[message.stationName] = {
            name = message.stationName,
            code = message.stationCode,
            lastSeen = os.time()
        }
        
        saveDatabase()
        debugPrint("INFO", "Registered station: " .. message.stationName)
        modem.transmit(replyChannel, 65000, {
            type = "station_register_ack",
            stationName = message.stationName
        })
    elseif message.type == "sync_request" then
        local files = {}
        for _, f in ipairs(fs.list("disk/Audio/Station")) do
            if not fs.isDir(f) then
                local file = fs.open(f, "rb")
                files[f] = file.readAll()
                file.close()
            end
        end

        modem.transmit(message.replyChannel, 65000, {
            type = "sync_package",
            files = files,
            total = #files
        })
        
        modem.transmit(replyChannel, 65000, {
            type = "folder_contents",
            files = files
        })
    end
    processingMessage = false

    while true do
        local event, side, channel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
        if message and message.type == "request_list_txt" then
            debugPrint("INFO", "Received list.txt request from "..message.stationName)
            if fs.exists("list.txt") then
                local file = fs.open("list.txt", "r")
                local content = file.readAll()
                file.close()
                
                modem.transmit(replyChannel, 65000, {
                    type = "list_txt",
                    content = content
                })
                debugPrint("INFO", "Sent list.txt content")
            else
                debugPrint("ERROR", "list.txt not found")
            end
        elseif message and message.type == "request_audio_files" then
            debugPrint("INFO", "Received audio files request from "..message.stationName)
            
            -- 获取基本的音频文件列表
            local audioFiles = {}
            if fs.exists("Audio") then
                for _, filename in ipairs(fs.list("Audio")) do
                    if string.sub(filename, -7) == ".dfpwm" then
                        table.insert(audioFiles, filename)
                    end
                end
            end
            
            -- 获取Station目录下的文件列表
            local stationFiles = {}
            if fs.exists("Audio/Station") then
                for _, filename in ipairs(fs.list("Audio/Station")) do
                    if string.sub(filename, -7) == ".dfpwm" then
                        table.insert(stationFiles, filename)
                    end
                end
            end
            
            modem.transmit(replyChannel, 65000, {
                type = "audio_files_list",
                audioFiles = audioFiles,
                stationFiles = stationFiles
            })
            debugPrint("INFO", "Sent audio files list: " .. #audioFiles .. " audio files, " .. #stationFiles .. " station files")
        end
    end
end

local function broadcastAudioFiles()
    local files = {}
    for _, name in ipairs(fs.list(AUDIO_STATION_DIR)) do
        local f = fs.open(fs.combine(AUDIO_STATION_DIR, name), "rb")
        files[name] = f.readAll()
        f.close()
    end
    modem.transmit(65000, 65000, {
        type = "audio_update",
        files = files,
        total = #files
    })
end


loadDatabase()

-- Main
debugPrint("INFO", "Central server started on channel 65000")

parallel.waitForAny(
    function()
        while true do
            local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
            
            if channel == 65000 and type(message) == "table" then
                queueMessage(message, replyChannel)
            end
        end
    end,
    
    function()
        while true do
            processMessageQueue()
            os.sleep(0.05)
        end
    end,
    
    function()
        while true do
            displayServerStatus()
            os.sleep(0.5)
        end
    end,
    function ()
        while true do
            broadcastAudioFiles()
            os.sleep(10)
        end
    end
)


