local socket = require("socket")
local wol = require("wol")

-- Default hosts and environments
local defaultHost = "127.0.0.1"
local lsHost = "120.78.82.250"
local devHost = "192.168.115.129"
local port = 65530

-- Parse command line arguments
local host = defaultHost  -- Default to local host
for i = 1, #arg do
    if arg[i] == "--host" and arg[i+1] then
        if arg[i+1] == "dev" then
            host = devHost
        elseif arg[i+1] == "local" then
            host = defaultHost
        elseif arg[i+1] == "ls" then
            host = lsHost
        else
            -- Support direct IP address specification
            host = arg[i+1]
        end
        break  -- Only process the first --host argument
    end
end

-- Connection configuration
local maxRetries = 10
local retryInterval = 2  -- seconds
local tcp = nil

-- Function to connect to the server
local function connectToServer()
    local newTcp = socket.tcp()
    newTcp:settimeout(5)  -- Connection timeout
    
    local success, err = newTcp:connect(host, port)
    if success then
        print("Connected to server " .. host .. ":" .. port)
        newTcp:settimeout(1)  -- 1 second timeout
        return newTcp
    else
        newTcp:close()
        return nil, err
    end
end

-- Auto-reconnect function
local function autoReconnect()
    local retryCount = 0
    
    while retryCount < maxRetries do
        print("Attempting to reconnect to server... (Attempt " .. (retryCount + 1) .. "/" .. maxRetries .. ")")
        
        local newTcp, err = connectToServer()
        if newTcp then
            print("Reconnected successfully!")
            return newTcp
        else
            print("Reconnection failed: " .. tostring(err))
            retryCount = retryCount + 1
            
            if retryCount < maxRetries then
                print("Waiting " .. retryInterval .. " seconds before retrying...")
                socket.sleep(retryInterval)
            end
        end
    end
    
    print("Reconnection failed, maximum retries reached (" .. maxRetries .. "), exiting program")
    return nil
end

-- Initial connection
tcp, err = connectToServer()
if not tcp then
    print("Initial connection failed: " .. tostring(err))
    tcp = autoReconnect()
    if not tcp then
        os.exit(1)
    end
end

print("Waiting for server messages...")

-- Use the implementation provided by wol.lua to send WOL packets
local function sendWolPacket(mac)
    local ok, msg = wol.send(mac, { broadcast = "192.168.115.191", port = 9 })
    return ok, msg
end

-- Main loop: receive server messages and execute commands, with auto-reconnect
while true do
    -- Receive server message
    local response, err = tcp:receive()
    if response then
        print("[Server Message] " .. response)
        
        -- If server sends disconnect message, exit
        if response:match("再见") or response:match("断开") then
            break
        end
        
        -- CMD execution request handling removed
        
        -- Check if it's a WOL command request
        local macAddress = response:match("^WOL:(.+)$")
        if macAddress then
            print("[Executing WOL] MAC address: " .. macAddress)
            local success, result = sendWolPacket(macAddress)
            
            local statusMsg = success and "[WOL Successful] " or "[WOL Failed] "
            print(statusMsg .. result)
            
            -- Send result back to server
            local sendSuccess, sendErr = tcp:send("RESULT:" .. result .. "\n")
            if not sendSuccess then
                print("Failed to send WOL result: " .. tostring(sendErr))
                print("Connection may be broken, attempting to reconnect...")
                
                -- Close current connection
                tcp:close()
                
                -- Attempt to reconnect
                tcp = autoReconnect()
                if not tcp then
                    print("Reconnection failed, exiting program")
                    os.exit(1)
                end
            else
                print("[WOL result sent to server]")
            end
        end
        
    elseif err and err ~= "timeout" then
        print("Connection error: " .. tostring(err))
        print("Connection broken, attempting to reconnect...")
        
        -- Close current connection
        tcp:close()
        
        -- Attempt to reconnect
        tcp = autoReconnect()
        if not tcp then
            print("Reconnection failed, exiting program")
            os.exit(1)
        end
    else
        -- Timeout, continue waiting
        -- print("Waiting for server messages...")
    end
    
    -- Short sleep
    socket.sleep(0.1)
end

-- Close connection
tcp:close()
print("Disconnected from server")