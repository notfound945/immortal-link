local socket = require("socket")
local wol = require("wol")

-- Simple file append logger for commands and execution status
local function appendLog(message)
    local f = io.open("client_commands.log", "a")
    if f then
        local ts = os.date("%Y-%m-%d %H:%M:%S")
        f:write("[" .. ts .. "] " .. tostring(message) .. "\n")
        f:close()
    end
end

-- Protocol message "enum"
local Message = {
    PING = "PING",
    PONG = "PONG",
    AUTH_REQUIRED = "AUTH REQUIRED",
    AUTH_OK = "AUTH OK",
    AUTH_FAILED = "AUTH FAILED",
    AUTH_DISABLED = "AUTH DISABLED",
    SERVER_SHUTDOWN = "SERVER CLOSED",
}

-- Default hosts and environments
local defaultHost = os.getenv("DEFAULT_HOST") or "127.0.0.1"
local port = 65530
local authToken = os.getenv("IMMORTAL_AUTH_TOKEN")

-- Parse command line arguments
local host = defaultHost -- Default to local host
for i = 1, #arg do
    if arg[i] == "--host" and arg[i + 1] then
        host = arg[i + 1]
        break -- Only process the first --host argument
    end
end

-- Parse optional auth token from args
for i = 1, #arg do
    if arg[i] == "--auth-token" and arg[i + 1] then
        authToken = arg[i + 1]
        break
    end
end

-- Connection configuration
local tcp = nil

-- Heartbeat configuration (seconds)
local heartbeatInterval = 10
local heartbeatTimeout = 30
local lastSeen = nil
local lastPing = 0

-- Exponential backoff configuration
-- retry exponent N => waits: 2^1, 2^2, ..., 2^N seconds
local maxExponent = 10 -- default to 10 (2..1024 seconds)

-- Parse retry exponent from arguments
for i = 1, #arg do
    if arg[i] == "--retry-exp" and arg[i + 1] then
        local n = tonumber(arg[i + 1])
        if n then
            if n < 1 then n = 1 end
            maxExponent = n
        end
        break
    end
end

-- Function to connect to the server
local function connectToServer()
    local newTcp = socket.tcp()
    newTcp:settimeout(5) -- Connection timeout

    local success, err = newTcp:connect(host, port)
    if success then
        print("Connected to server " .. host .. ":" .. port)
        newTcp:settimeout(1) -- 1 second timeout
        -- Perform optional AUTH handshake if token provided
        if authToken and authToken ~= "" then
            -- small sleep to allow greeting
            socket.sleep(0.05)
            newTcp:send("AUTH " .. authToken .. "\n")
        end
        lastSeen = socket.gettime()
        lastPing = 0
        return newTcp
    else
        newTcp:close()
        return nil, err
    end
end

-- Auto-reconnect function
local function autoReconnect()
    local exponent = 1
    while exponent <= maxExponent do
        print("Attempting to reconnect to server... (try " .. exponent .. "/" ..
                  maxExponent .. ")")

        local newTcp, err = connectToServer()
        if newTcp then
            print("Reconnected successfully!")
            return newTcp
        else
            print("Reconnection failed: " .. tostring(err))
            -- wait 2^exponent seconds
            local waitSeconds = 2 ^ exponent
            print("Waiting " .. waitSeconds .. " seconds before retrying...")
            socket.sleep(waitSeconds)
            exponent = exponent + 1
        end
    end

    print("Reconnection failed, waited up to 2^" .. maxExponent ..
              " seconds, exiting program")
    return nil
end

-- Initial connection
tcp, err = connectToServer()
if not tcp then
    print("Initial connection failed: " .. tostring(err))
    tcp = autoReconnect()
    if not tcp then os.exit(1) end
end

print("Waiting for server messages...")

-- Use the implementation provided by wol.lua to send WOL packets
local function sendWolPacket(mac)
    local ok, msg = wol.send(mac, {broadcast = "192.168.115.191", port = 9})
    return ok, msg
end

-- Main loop: receive server messages and execute commands, with auto-reconnect
while true do
    -- Receive server message
    local response, err = tcp:receive()
    if response then
        lastSeen = socket.gettime()
        if response ~= Message.PING and response ~= Message.PONG then
            print("[Server Message] " .. response)
        end

        -- Heartbeat handling
        if response == Message.PING then
            tcp:send(Message.PONG .. "\n")
        elseif response == Message.PONG then
            -- no-op
        else
            -- Handle AUTH negotiation messages
            if response == Message.AUTH_REQUIRED then
                if authToken and authToken ~= "" then
                    tcp:send("AUTH " .. authToken .. "\n")
                else
                    print(
                        "Server requires authentication but no token provided. Exiting.")
                    os.exit(1)
                end
            elseif response == Message.AUTH_OK then
                -- authenticated; continue
            elseif response == Message.AUTH_FAILED then
                print("Authentication failed. Exiting.")
                os.exit(1)
            elseif response == Message.AUTH_DISABLED then
                -- proceed
            else
                -- If server sends disconnect message, exit
                if response == Message.SERVER_SHUTDOWN then
                    appendLog("RECV CLOSE " .. response)
                    break
                end

                -- CMD execution request handling removed

                -- Check if it's a WOL command request
                local macAddress = response:match("^WOL:(.+)$")
                if macAddress then
                    print("[Executing WOL] MAC address: " .. macAddress)
                    appendLog("RECV WOL " .. macAddress)
                    local success, result = sendWolPacket(macAddress)

                    local statusMsg = success and "[WOL Successful] " or
                                          "[WOL Failed] "
                    print(statusMsg .. result)
                    appendLog("EXEC WOL " .. macAddress .. " -> " ..
                                  (success and "OK" or "FAIL") .. ": " ..
                                  tostring(result))

                    -- Send result back to server
                    local sendSuccess, sendErr = tcp:send(
                                                     "RESULT:" .. result .. "\n")
                    if not sendSuccess then
                        print("Failed to send WOL result: " .. tostring(sendErr))
                        appendLog("SEND RESULT FAIL - " .. tostring(sendErr))
                        print(
                            "Connection may be broken, attempting to reconnect...")

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
                        appendLog("SEND RESULT OK")
                    end
                end
                if not macAddress then
                    appendLog("RECV MSG " .. response)
                end
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

    -- Heartbeat: client proactively sends PING and checks timeout
    do
        local now = socket.gettime()
        if now - (lastPing or 0) >= heartbeatInterval then
            local ok, sendErr = tcp:send(Message.PING .. "\n")
            if ok then
                lastPing = now
            else
                -- keep silent for regular operations; optional minimal log
                -- print("Heartbeat send failed: " .. tostring(sendErr))
            end
        end
        if now - (lastSeen or now) > heartbeatTimeout then
            print("Heartbeat timeout, attempting to reconnect...")
            tcp:close()
            tcp = autoReconnect()
            if not tcp then
                print("Reconnection failed, exiting program")
                os.exit(1)
            end
        end
    end

    -- Short sleep
    socket.sleep(0.1)
end

-- Close connection
tcp:close()
print("Disconnected from server")
