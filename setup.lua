-- ftc-BC System Installer
-- Graphical Installation Interface
--By Henry_Du ftc@fse-media.group

-- Use local terminal for display
local monitor = term
monitor.setBackgroundColor(colors.black)
monitor.clear()

local currentPage = 1
local kstsNumber = 0

local function showWelcomePage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    -- Yellow title
            monitor.setCursorPos(10, 5)
            monitor.setTextColor(colors.yellow)
            monitor.write("Welcome to ftc-BC. sys [client] Setup")
            
            -- Green button
            local buttonX = 15
            local buttonY = 10
            local buttonWidth = 10
    
    monitor.setCursorPos(buttonX, buttonY)
    monitor.setBackgroundColor(colors.green)
    monitor.setTextColor(colors.black)
    monitor.write(" START ")
    
    -- 按钮点击区域
    local buttonArea = {
        x = buttonX, y = buttonY,
        width = buttonWidth, height = 1
    }
    
    return buttonArea
end

-- Interface 2: Select departure music
local function showMusicSelectionPage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    -- White title
    monitor.setCursorPos(8, 3)
    monitor.setTextColor(colors.white)
    monitor.write("Please select the departure music of this station/platform")
    
    -- ksts text and input box
    monitor.setCursorPos(15, 8)
    monitor.setTextColor(colors.white)
    monitor.write("ksts")
    
    monitor.setCursorPos(20, 8)
    monitor.setBackgroundColor(colors.white)
    monitor.setTextColor(colors.black)
    monitor.write("     ") 
    
    -- Green OK button
    monitor.setCursorPos(15, 12)
    monitor.setBackgroundColor(colors.green)
    monitor.setTextColor(colors.black)
    monitor.write("   OK   ")
    
    return {
        inputBox = {x = 20, y = 8, width = 5, height = 1},
        okButton = {x = 15, y = 12, width = 8, height = 1}
    }
end
-- Interface 4: Installation Progress
local function showInstallationProgress(progress)
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    monitor.setCursorPos(12, 5)
    monitor.setTextColor(colors.green)
    monitor.write("Installation in progress")
    
    -- Progress bar background
    monitor.setCursorPos(5, 8)
    monitor.setBackgroundColor(colors.gray)
    monitor.write("                    ")
    
    -- Progress bar fill
    local fillWidth = math.floor(progress * 20)
    if fillWidth > 0 then
        monitor.setCursorPos(5, 8)
        monitor.setBackgroundColor(colors.green)
        monitor.write(string.rep(" ", fillWidth))
    end
    
    -- Percentage display
    monitor.setCursorPos(15, 10)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.write(string.format("%d%%", progress * 100))
    
    -- Display current step information
    monitor.setCursorPos(5, 12)
    monitor.setTextColor(colors.yellow)
    monitor.write("Installing components...")

    
    return true
end

-- Interface 5: Installation Successful
local function showInstallationSuccess()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    monitor.setCursorPos(15, 5)
    monitor.setTextColor(colors.green)
    monitor.write("Installation successful")
    
    return true
end

-- Check if touch event is within area
            local function isInArea(x, y, area)
                return x >= area.x and x <= area.x + area.width - 1 and
                       y >= area.y and y <= area.y + area.height - 1
            end

-- Main Loop
local function main()
    while true do
        if currentPage == 1 then
            local buttonArea = showWelcomePage()
            
            local event, button, x, y = os.pullEvent("mouse_click")
            if event == "mouse_click" and button == 1 and isInArea(x, y, buttonArea) then
                currentPage = 2
            end
            
        elseif currentPage == 2 then
            local areas = showMusicSelectionPage()
            
            local inputText = ""
            local cursorVisible = true
            local cursorTimer = os.startTimer(0.5)
            
            while true do
                monitor.setCursorPos(areas.inputBox.x, areas.inputBox.y)
                monitor.setBackgroundColor(colors.white)
                monitor.setTextColor(colors.black)
                local displayText = inputText
                if cursorVisible and os.clock() % 1 > 0.5 then
                    displayText = displayText .. "_"
                else
                    displayText = displayText .. " "
                end
                monitor.write(string.sub(displayText .. "     ", 1, 5))
                
                local event, p1, p2, p3 = os.pullEvent()
                
                if event == "mouse_click" then
                    local button, x, y = p1, p2, p3
                    if button == 1 and isInArea(x, y, areas.okButton) then
                        if #inputText > 0 then
                            kstsNumber = tonumber(inputText)
                            currentPage = 4
                            break
                        end
                    elseif isInArea(x, y, areas.inputBox) then
                    end
                elseif event == "key" then
                    local key = p1
                    if key == keys.enter then
                        if #inputText > 0 then
                            kstsNumber = tonumber(inputText)
                            currentPage = 4
                            break
                        end
                    elseif key == keys.backspace then
                        inputText = string.sub(inputText, 1, -2)
                    end
                elseif event == "char" then
                    local char = p1
                    if tonumber(char) and #inputText < 3 then
                        inputText = inputText .. char
                    end
                elseif event == "timer" and p1 == cursorTimer then
                    cursorVisible = not cursorVisible
                    cursorTimer = os.startTimer(0.5)
                end
            end
            
        elseif currentPage == 4 then
            local totalSteps = 8 
            local currentStep = 0
            
            showInstallationProgress(currentStep / totalSteps)
            shell.run("wget", "http://192.140.163.241:5244/d/API/StationBroadcast/station_broadcast.lua?sign=xXsMwezjnEs4c6QrjkJkbvz1rARokmm87zwDcDDS5dk=:0")
            currentStep = currentStep + 1
            
            showInstallationProgress(currentStep / totalSteps)
            shell.run("wget", "http://192.140.163.241:5244/d/API/StationBroadcast/aukit.lua?sign=02_QDktYbSrHrtCDsFlKMkbEOWJGDautZaOtWkvg5q8=:0")
            currentStep = currentStep + 1
            
            showInstallationProgress(currentStep / totalSteps)
            shell.run("wget", "http://192.140.163.241:5244/d/API/StationBroadcast/austream.lua?sign=DrLbf9CIX1ZY8DaL8vliZiCMQzGos10nhG26Wf5lbgA=:0")
            currentStep = currentStep + 1
            
            showInstallationProgress(currentStep / totalSteps)
            shell.run("mkdir", "Audio")
            currentStep = currentStep + 1
                        local modem = peripheral.find("modem") or peripheral.find("wired_modem") or peripheral.find("wireless_modem")
            print("Downloading audio files via wget...")
            if not fs.exists("Audio") then
                fs.makeDir("Audio")
            end
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-1zt.dfpwm?sign=WlU0MzU8GSeBwkd8mgf7f6Msnr9dbUegnbH8zmvfaug=:0 Audio/ch-1zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-2zt.dfpwm?sign=cstkv3h7-a5DU7H3EfwLzz4VJupPzoADDE5Bl1mHtTw=:0 Audio/ch-2zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-3zt.dfpwm?sign=qphoHyi1gg-nrHHLux6niTWoKJxVArgEvTuXjLkLbcM=:0 Audio/ch-3zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-4zt.dfpwm?sign=_4dGyQODF5q-WqFtuQ_BIjtdnQqL-veWK2vPTVAtzZY=:0 Audio/ch-4zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-5zt.dfpwm?sign=qfIptlZHOikEscgEF8JqwEaFZXXRBFFPBOw7j_nhsxY=:0 Audio/ch-5zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-6zt.dfpwm?sign=xqo8aAfS6OzvNiHRWbmAPFhn1lb1Lt3F51eKXWaNCzg=:0 Audio/ch-6zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-7zt.dfpwm?sign=Jc0_p9jnA2hYWI4XpjjWO2whv6PF7oD12nrT09Da1zI=:0 Audio/ch-7zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-8zt.dfpwm?sign=_YOl4AqzJl7yhuzk1GI6kaTn_BI04-IRonI4mEPAIys=:0 Audio/ch-8zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-9zt.dfpwm?sign=_blohblQJJOklOZB_DssqTCpJzylvKIQLCig2j2iyak=:0 Audio/ch-9zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-10zt.dfpwm?sign=MEFzEVFmw2xp-BaUCBsMVs2rUwspJZv0tlFbepYRf80=:0 Audio/ch-10zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-11zt.dfpwm?sign=1H5NwRvgUj91V1bcbyXeICLQBCHZ6-xlD72RRrYfJP4=:0 Audio/ch-11zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-12zt.dfpwm?sign=N1nRaRH22smF3QCgnp1eVpY9_Cm3g0yZq4B9WFb3-0w=:0 Audio/ch-12zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-13zt.dfpwm?sign=kJQQ5q_xha7a8MdbTDTqOW4NJTqx7h0Z3cWYikuMTpc=:0 Audio/ch-13zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-14zt.dfpwm?sign=1GboU0PM27zG6SbjzxkUPfbagVDO3pSUPK_1U5a9rf0=:0 Audio/ch-14zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lccz1.dfpwm?sign=34MjBT80D0dQm9mzHYK8ho9MlPR2zeg33vceyYq-SuY=:0 Audio/ch-lccz1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lccz2.dfpwm?sign=MFQ6CehXJwt_VWFORow74vki20YoZTwtYYkgQG4onQg=:0 Audio/ch-lccz2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lccz3.dfpwm?sign=BV6EKzIzP7X3gEShltuO14AXYDxqASJC1nO2bUxQwIE=:0 Audio/ch-lccz3.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lcczjd1.dfpwm?sign=JYEk4rhj5nfiR_qKd6YGNpIADzxdkwEc_UPfGhr2nnI=:0 Audio/ch-lcczjd1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lcczjd2.dfpwm?sign=Yuvt4vNVjCWAPIdml1DTeZuWVSv92yoN8hfe6JcwdLo=:0 Audio/ch-lcczjd2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lcjz1.dfpwm?sign=epfaqd58FKrTBbFuoqNNubpgH2zaA0qX8-YzGNPkCCQ=:0 Audio/ch-lcjz1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lcjz2.dfpwm?sign=xQSMAOOvB4hjucXt-VLZvNjOv4gCYQjY67wsJzYqRuM=:0 Audio/ch-lcjz2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lcjz3.dfpwm?sign=u6w7vz6bTAzF5_IIk2N0PK5MCToYY-CLPCudISpGQjs=:0 Audio/ch-lcjz3.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-lcjz4.dfpwm?sign=jdBSe82DFDe2gedl6_tUql_L3zrao4j3hz00zGZ7H2U=:0 Audio/ch-lcjz4.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-pt.dfpwm?sign=whOL6dtYWL0j1w7hQMsFYCuQRW_cPXSeVKOByeUhNoA=:0 Audio/ch-pt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ch-tj.dfpwm?sign=dtfLJyYx9KIi3bz1OVuYniTtaVe1x5-Z9-XDXNowF0s=:0 Audio/ch-tj.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-1zt.dfpwm?sign=KAUXDFSZfnactJ8WCrjiJci5weXNABmY50RZHrlIAT4=:0 Audio/en-1zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-2zt.dfpwm?sign=fW-nBFwPHzOEKhf-Uh19-HEqnLaeC0ly6UU6CDUH6hw=:0 Audio/en-2zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-3zt.dfpwm?sign=HCXCwSfi3Bb1qPakM2DWGG9WwuGYTZRtjDh8BHGU33E=:0 Audio/en-3zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-4zt.dfpwm?sign=EMlfRWq40EZmZYY4XN5BJsY_ruGyMX9BMtdW7kzgvJI=:0 Audio/en-4zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-5zt.dfpwm?sign=-qTWjeGpJ87wVfG4BSR6ugK4yjZEpeHZLE95YhpVUEo=:0 Audio/en-5zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-6zt.dfpwm?sign=BFtitzAvOoMaCzbZj9qEUb5jOTIGvxbjstAc9s0_9y0=:0 Audio/en-6zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-7zt.dfpwm?sign=JJ4jQHmlnyjZ7MuproLYawo8lqDwbUKs7JMDmNpdLLk=:0 Audio/en-7zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-8zt.dfpwm?sign=vfwgYGV6qHAhBe5-6nrFFbFLt6KRrfPnue__MwxIFeA=:0 Audio/en-8zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-9zt.dfpwm?sign=PB6Er8X1fnXJjfAxzPfjCY0wUJDIIovnYZLYxPMV2OM=:0 Audio/en-9zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-10zt.dfpwm?sign=-ZCgTyUJoZG3Wyaj_jEYge9cRUcPk9qLVtaGUDQYwUA=:0 Audio/en-10zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-11zt.dfpwm?sign=vdsuTAv7_ExA8v5_6XxPoErOYmk-X1E65lztcjoLWlI=:0 Audio/en-11zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-12zt.dfpwm?sign=noyTrcQSAchx1JXSXVwJOB3DkxpRJVzTKKji2dI0IL8=:0 Audio/en-12zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-13zt.dfpwm?sign=S6m6ErEhYm9mjuOvP1_7LWHkmRHTs0UI4PeCZd2Z-YY=:0 Audio/en-13zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-14zt.dfpwm?sign=8TilXRZmqnFdmIEvyBhZl4u8-S32iANUYLZZBiTvND4=:0 Audio/en-14zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lccz1.dfpwm?sign=wnPYlhXoNzpHJza0gIsIF5Gx7bKZ7CXmigDBsaaP0Ao=:0 Audio/en-lccz1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lccz2.dfpwm?sign=XFC_4pPLZd0l2KZpPVyA_IljLW-LzwJ0mAMWefcsKFs=:0 Audio/en-lccz2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lccz3.dfpwm?sign=gWdfAtgbepN43ByL1XDve2Ubcwl3muGbDhnoJ8P_JK4=:0 Audio/en-lccz3.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lccz4.dfpwm?sign=IJOytmeh6JjGh4VPpNaYuuctYEd5FpUCKXCBjSfPWw0=:0 Audio/en-lccz4.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lcczjd1.dfpwm?sign=DQOfEl-Kh8Z-7kaT_8koGxtyPqNbzGRrKbO25Ioa_ng=:0 Audio/en-lcczjd1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lcczjd2.dfpwm?sign=cIfXzq6CUppyCj1wrApj7TC8s8SyFJ_LZ38CT1BChDY=:0 Audio/en-lcczjd2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lcczjd3.dfpwm?sign=YzUvyyJnsE_jsxCI9Cyk9QC-JLAaUlsnkENeP1cdTvA=:0 Audio/en-lcczjd3.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lcjz1.dfpwm?sign=lmnr-oyoew9u4N0GyFSjqcf4QpPZ4_koAVDcO2zuKUg=:0 Audio/en-lcjz1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lcjz2.dfpwm?sign=IkFZGOqASRX6fTp_WG0Bqh8hQkz9Sv96tRq7C92HW6k=:0 Audio/en-lcjz2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lcjz3.dfpwm?sign=EJ8GFE9mdOl7ZDfk3ZakhkER54MTA3weRuwHG7D07AQ=:0 Audio/en-lcjz3.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-lcjz4.dfpwm?sign=gl0D8PdQxamKlsIHFDKZ_BtIOE6qRGt2ilVHmxbxC34=:0 Audio/en-lcjz4.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-pt.dfpwm?sign=YIStAlmgp2MULWahW0N0p0UE3sCufidKGTh60-qIqUs=:0 Audio/en-pt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/en-tj.dfpwm?sign=vDGB0vOMMRsLn9T0OijkBcMLyyx-MeQP1tXFbkHM4vE=:0 Audio/en-tj.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/fc.dfpwm?sign=_qqUdgW0Xy-R4vQARXnauvog7LXN2Pp9BDPWeY4uln0=:0 Audio/fc.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-1zt.dfpwm?sign=S-1QH7RzVePmi_xkSGTOY9WEXnMQcV46nZ-dONeCQqs=:0 Audio/ja-1zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-2jt.dfpwm?sign=0akCzLEM9L6BW0ipC1eAB1pYQtFbNBcriyGHQ-nRxeQ=:0 Audio/ja-2jt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-3zt.dfpwm?sign=GX0Au1v5PCyD2Chsc5NJVtdJpjLldW75nUINrpIy7xc=:0 Audio/ja-3zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-4zt.dfpwm?sign=NcuacAqkB1gdYRINiIsC49busqOO_KFSpqiIVRa-Os8=:0 Audio/ja-4zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-5zt.dfpwm?sign=jFyRbREJLuLbyVBksquD7ak2jt8GXRV7XedCi3KocOo=:0 Audio/ja-5zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-6zt.dfpwm?sign=mNswG8lQrfxQ8KDuWNGfUdPIpBikcjr5Ic-Mhdtqd3A=:0 Audio/ja-6zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-7zt.dfpwm?sign=24ucy2da7onWd9Z4X232F5lzl16lb9A2-D518TyJ6JU=:0 Audio/ja-7zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-8zt.dfpwm?sign=bI8O7Eow8i1B36CsBBeIPf8cGN6t8jY59WF7xTUfWko=:0 Audio/ja-8zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-9zt.dfpwm?sign=nv6mZB85lR8l9f1XYmKhizAk1Sh86Nc3WS4adY6QGhk=:0 Audio/ja-9zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-10zt.dfpwm?sign=YY1yB8hTYZZ3uAzrXRWI_S9YTNeVYfWXfnjyh3X6d6c=:0 Audio/ja-10zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-11zt.dfpwm?sign=f7Q3iyVBgTnRocjy73pj07lPM34yG55tYdB4Wcth63E=:0 Audio/ja-11zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-12zt.dfpwm?sign=6qJYODvZPHEx-kuOe0O0gJsBo14t5wqc1_mzwSm4iNE=:0 Audio/ja-12zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-13zt.dfpwm?sign=XuGcUYMC1SphoJYIxDMdv-hU6gYQ1Gv4uRtXztfpqVc=:0 Audio/ja-13zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-14zt.dfpwm?sign=rU2un_A0iHQMVYr58SqreAsU0adgX67LREhovHkNbvE=:0 Audio/ja-14zt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-lccz1.dfpwm?sign=7JFVyyiwwrXNyscZWkTERTblBKofM9u3J5bd7BAvpu8=:0 Audio/ja-lccz1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-lccz2.dfpwm?sign=aXl5FfOD48MAtEI3AJPipfmopF9fw1p5R9tHGa-Eq1s=:0 Audio/ja-lccz2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-lccz3.dfpwm?sign=QcTp9-M-sDSpBqJINSBYYINuAsHHK-r3rLetHCYfS18=:0 Audio/ja-lccz3.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-lcczjd1.dfpwm?sign=jYKINdY2_Mjc1-1LGIm-OEqkK_RTLlTTXwdOI1AiqOU=:0 Audio/ja-lcczjd1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-lcjz1.dfpwm?sign=Ek9mL_XStBHkt3Et0SM61pLH-M6QtHLA5tMAzaZYGVY=:0 Audio/ja-lcjz1.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-lcjz2.dfpwm?sign=RZkIvEn_v2_GlTcHPHm5RNbexKbn9UbFfrvvaD-vWOE=:0 Audio/ja-lcjz2.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-pt.dfpwm?sign=gg_F2bbYs4avKA6w8gprum-bVR0Vdtkaxcvo7jWostM=:0 Audio/ja-pt.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ja-tj.dfpwm?sign=dfqUVSb-7Um8ewassy3RpnVak6ne-EZf0X_ylNSACsI=:0 Audio/ja-tj.dfpwm")
            shell.run("wget http://192.140.163.241:5244/d/API/StationBroadcast/Audio/ksts.dfpwm?sign=gVmBK3YhW50S8O1vJ1MeDaLOV6uZ3844-z52kg4ZZWs=:0 Audio/ksts.dfpwm")
            print("[Info]: Audio file download completed!")
            
            currentStep = currentStep + 1
            showInstallationProgress(currentStep / totalSteps)
            if kstsNumber then
            if kstsNumber == 1 then
                    KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts1/ksts1.dfpwm?sign=DAGlIpphcPkIUuK7l7z9Ww7KoYgsPT_xR4qhrGLZR5U=:0'
            elseif kstsNumber == 2 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts2/ksts2.dfpwm?sign=HgWiXPbrSxumzhFhA5ANqQOdevxwgoOEQanr8A4OhCo=:0'
            elseif kstsNumber == 3 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts3/ksts3.dfpwm?sign=14SDQLNl84suaHkyhDTnvmNjUvgzm96S_zYfSkKcpew=:0'
            elseif kstsNumber == 4 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts4/ksts4.dfpwm?sign=frCC3WsPrGn79_lSE9PxKc9HkwNu09QiqPPOa4x5eCE=:0'
            elseif kstsNumber == 5 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts5/ksts5.dfpwm?sign=Xs0SaJ_86-1AT7kVuWGbK1CaLPVyGYN46LMQiFzdh3o=:0'
            elseif kstsNumber == 6 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts6/ksts6.dfpwm?sign=scX8tE2-96EUjiIvbG6WTHnLfR_8O8OIlwJCCCAevEA=:0' 
            elseif kstsNumber == 7 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts7/ksts7.dfpwm?sign=C3jY1znyU-xexVotQfhZwxuInU6nybDJsBerp5cwdIY=:0'
            elseif kstsNumber == 8 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts8/ksts8.dfpwm?sign=M1Jw2Qcpr-ekytJwhYwm7wyGlKL7Py6CXgrf2A-OQDc=:0'
            elseif kstsNumber == 9 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts9/ksts9.dfpwm?sign=0cXT2OcocXaOh1D3o2dolJGNF7-RPvJxOB_HAVaAI_0=:0'
            elseif kstsNumber == 10 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts10/ksts10.dfpwm?sign=ex_lwFk3VyM7Bn3tdY7PQRmCnOl6uj0WfgL7W-_eR_M=:0'
            elseif kstsNumber == 11 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts11/ksts11.dfpwm?sign=qboe8gutlFgsciaHheWirize7cBP7uhVgOKwX2_QsIk=:0'
            elseif kstsNumber == 12 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts12/ksts12.dfpwm?sign=7_ki80oxxxAic6HKjGDOacd_yWb4o3DhtE0ITrt2jkY=:0'
            elseif kstsNumber == 13 then
                KstsUrl = 'http://192.140.163.241:5244/d/API/StationBroadcast/ksts13/ksts13.dfpwm?sign=HzM3o228ya6i82lFWtO_9e_bA4icOYi7_lY0kQv5CjQ=:0'
            end
                shell.run("wget", KstsUrl, "Audio/fc_temp.dfpwm")
                

                if fs.exists("Audio/fc.dfpwm") then
                    shell.run("rm", "Audio/fc.dfpwm")
                end
                shell.run("mv", "Audio/fc_temp.dfpwm", "Audio/fc.dfpwm")
            end
            currentStep = currentStep + 1
            

            showInstallationProgress(currentStep / totalSteps)
            shell.run("mkdir", "Audio/Station")
            currentStep = currentStep + 1
            

            showInstallationProgress(currentStep / totalSteps)

            showInstallationProgress(currentStep / totalSteps)
            shell.run("mv", "station_broadcast.lua", "startup")
            currentStep = currentStep + 1
            

            showInstallationProgress(1.0)
            sleep(1)
            
            currentPage = 5
            
        elseif currentPage == 5 then
            showInstallationSuccess()
            break
        end
        
        os.sleep(0.1)
    end
end


main()