local socket = require("socket")

-- Simple argument parsing: supports --daemon and --admin-port <port>
local daemonMode = false
local adminPort = 65531
for i = 1, #arg do
    if arg[i] == "--daemon" then
        daemonMode = true
    elseif arg[i] == "--admin-port" and arg[i+1] then
        local p = tonumber(arg[i+1])
        if p then adminPort = p end
    end
end

-- Heartbeat configuration (seconds)
local heartbeatInterval = 10
local heartbeatTimeout = 30

-- Listen on port 65530 on all interfaces
local server = assert(socket.bind("*", 65530))
local ip, port = server:getsockname()

print("=== Immortal Link Server ===")
print("Listening: " .. ip .. ":" .. port)
print("Admin port: 127.0.0.1:" .. adminPort .. (daemonMode and " (daemon)" or ""))
print("Commands:")
print("  send <message>     - send message to all clients")
print("  broadcast <message> - broadcast message")
-- exec command removed
print("  wol <MAC>   - send WOL wake command")
print("  clients     - list connected clients")
print("  quit        - shutdown server")
print("Enter commands (Ctrl+D for EOF), or use cli to send via admin port")
print("==============================")

-- Connected clients
local clients = {}
local clientCounter = 0
-- Commands sent to clients for logging context
local pendingCommands = {}

-- Admin port: listen on loopback
local adminServer = assert(socket.bind("127.0.0.1", adminPort))
adminServer:settimeout(0)
local adminClients = {}
local adminClientCounter = 0

-- Current responder for admin sessions (optional)
local currentResponder = nil
local function printBoth(msg)
    print(msg)
    if currentResponder then
        -- Ensure newline termination
        currentResponder(msg .. "\n")
    end
end

-- Set server non-blocking
server:settimeout(0)

-- Handle network events
local function processNetwork()
    -- Accept new client
    local client = server:accept()
    if client then
        clientCounter = clientCounter + 1
        local clientId = "client-" .. clientCounter
        clients[clientId] = {
            socket = client,
            id = clientId,
            connected = true,
            lastSeen = socket.gettime(),
            lastPing = 0
        }
        client:settimeout(0)  -- set client non-blocking
        print("New client connected: " .. clientId)
        
        -- Send welcome message
        client:send("Welcome! Your ID is: " .. clientId .. "\n")
    end
    
    -- Handle existing clients
    for clientId, clientInfo in pairs(clients) do
        if clientInfo.connected then
            local client = clientInfo.socket
            local line, err = client:receive()
            if line then
                -- Update last seen on any message
                clientInfo.lastSeen = socket.gettime()

                -- Heartbeat handling
                if line == "PING" then
                    client:send("PONG\n")
                elseif line == "PONG" then
                    -- nothing else to do; lastSeen already updated
                else
                -- Check if it is a command result
                local result = line:match("^RESULT:(.*)$")
                if result then
                    -- Print to stdout (and echo to admin connection if present)
                    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
                    local fullCommand = pendingCommands[clientId] or "unknown"
                    pendingCommands[clientId] = nil

                    printBoth("Received command result from " .. clientId)
                    printBoth("Executed command: " .. fullCommand)
                    printBoth("Received at: " .. timestamp)
                    printBoth("=" .. string.rep("=", 50))
                    printBoth(result)
                else
                    print("Received message from " .. clientId .. ": " .. line)
                end
                end
            elseif err and err ~= "timeout" then
                print("Client " .. clientId .. " disconnected")
                client:close()
                clients[clientId] = nil
            end

            -- Heartbeat: send periodic PING
            if clients[clientId] then
                local now = socket.gettime()
                if now - (clientInfo.lastPing or 0) >= heartbeatInterval then
                    local ok, sendErr = client:send("PING\n")
                    if ok then
                        clientInfo.lastPing = now
                    else
                        print("Heartbeat send failed for " .. clientId .. ": " .. tostring(sendErr))
                        client:close()
                        clients[clientId] = nil
                    end
                end
                -- Heartbeat: disconnect if timeout
                if clients[clientId] and (now - (clientInfo.lastSeen or now) > heartbeatTimeout) then
                    print("Client " .. clientId .. " timed out (no heartbeat)")
                    client:close()
                    clients[clientId] = nil
                end
            end
        end
    end
end

-- Process a single command
local function processCommand(input)
    local cmd, message = input:match("^(%S+)%s*(.*)$")
    cmd = cmd or input
    message = message or ""
    
    if cmd == "send" and message ~= "" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                local success = clientInfo.socket:send(message .. "\n")
                if success then
                    count = count + 1
                end
            end
        end
        printBoth("Message sent to " .. count .. " clients")
        
    elseif cmd == "broadcast" and message ~= "" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                local success = clientInfo.socket:send("[Broadcast] " .. message .. "\n")
                if success then
                    count = count + 1
                end
            end
        end
        printBoth("Broadcast sent to " .. count .. " clients")
        
    -- exec removed
    elseif cmd == "wol" and message ~= "" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                local success = clientInfo.socket:send("WOL:" .. message .. "\n")
                if success then
                    count = count + 1
                    -- record context
                    pendingCommands[clientId] = "wol " .. message
                end
            end
        end
        printBoth("WOL command (MAC: " .. message .. ") sent to " .. count .. " clients")
        
    elseif cmd == "clients" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                printBoth("  " .. clientId)
                count = count + 1
            end
        end
        printBoth("Total " .. count .. " clients online")
        
    elseif cmd == "quit" then
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                clientInfo.socket:send("Server is shutting down. Bye!\n")
                clientInfo.socket:close()
            end
        end
        return false  -- 退出
        
    elseif cmd == "send" and message == "" then
        printBoth("Usage: send <message>")
        
    elseif cmd == "broadcast" and message == "" then
        printBoth("Usage: broadcast <message>")
        
    -- exec usage removed
    elseif cmd == "wol" and message == "" then
        printBoth("Usage: wol <MAC>")
        printBoth("Example: wol 00:11:22:33:44:55")
        printBoth("Example: wol 00-11-22-33-44-55")
        
    else
        printBoth("Unknown command: " .. input)
        printBoth("Available commands: send <message>, broadcast <message>, wol <MAC>, clients, quit")
    end
    
    return true  -- continue
end

-- Main loop: read commands
if daemonMode then
    -- Daemon mode: handle network and admin port only; no stdin
    while true do
        processNetwork()
        -- Admin port: accept and process commands
        local adminClient = adminServer:accept()
        if adminClient then
            adminClientCounter = adminClientCounter + 1
            local aid = "admin-" .. adminClientCounter
            adminClients[aid] = { socket = adminClient, id = aid }
            adminClient:settimeout(0)
            print("Admin client connected: " .. aid)
        end
        for aid, ainfo in pairs(adminClients) do
            local line, err = ainfo.socket:receive()
            if line then
                -- Handle admin command and echo back
                currentResponder = function(msg)
                    ainfo.socket:send(msg)
                end
                local keepRunning = processCommand(line)
                currentResponder = nil
                if not keepRunning then
                    -- Close resources and exit
                    for _, c in pairs(clients) do
                        if c.connected then c.socket:close() end
                    end
                    ainfo.socket:send("Server closed\n")
                    ainfo.socket:close()
                    adminClients[aid] = nil
                    server:close()
                    return
                end
            elseif err and err ~= "timeout" then
                print("Admin client disconnected: " .. aid)
                ainfo.socket:close()
                adminClients[aid] = nil
            end
        end
        socket.sleep(0.1)
    end
else
    while true do
        -- Continuously process network events
        processNetwork()
        
        print("\nEnter commands (Ctrl+D to execute):")
        io.write("server> ")
        io.flush()
        
        -- Read all input until EOF
        local commands = {}
        while true do
            local line = io.read()
            if not line then  -- EOF
                break
            end
            -- Trim leading/trailing whitespace (Lua 5.1 compatible)
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                table.insert(commands, line)
            end
        end
        
        -- Process all commands
        local shouldContinue = true
        for _, cmd in ipairs(commands) do
            print("Executing: " .. cmd)
            shouldContinue = processCommand(cmd)
            if not shouldContinue then
                break
            end
        end
        
        if not shouldContinue then
            break
        end
    end
end

-- Close server
server:close()
print("Server closed")
