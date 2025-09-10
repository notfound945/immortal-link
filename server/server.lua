local socket = require("socket")
local proto = require("server_proto")
local ClientPool = require("client_pool")

-- Binary frame protocol
-- Frame: [4-byte BE length L][1-byte type T][L-1 bytes payload]
local TYPE = proto.TYPE
local sendFrame = proto.sendFrame

-- Simple argument parsing: supports --daemon and --admin-port <port>
local daemonMode = false
local adminPort = 65531
local authToken = os.getenv("IMMORTAL_AUTH_TOKEN")
for i = 1, #arg do
    if arg[i] == "--daemon" then
        daemonMode = true
    elseif arg[i] == "--admin-port" and arg[i + 1] then
        local p = tonumber(arg[i + 1])
        if p then adminPort = p end
    elseif arg[i] == "--auth-token" and arg[i + 1] then
        authToken = arg[i + 1]
    end
end

local authRequired = (authToken ~= nil and authToken ~= "")

-- Admin CLI command "enum"
local Command = {
    SEND = "send",
    BROADCAST = "broadcast",
    WOL = "wol",
    CLIENTS = "clients",
    QUIT = "quit",
}

-- Heartbeat configuration (seconds)
local heartbeatInterval = 10
local heartbeatTimeout = 30
-- Authentication handshake timeout for pending connections (seconds)
local authHandshakeTimeout = 5

-- Listen on port 65530 on all interfaces
local server = assert(socket.bind("*", 65530))
local ip, port = server:getsockname()

print("=== Immortal Link Server ===")
print("Listening: " .. ip .. ":" .. port)
print("Admin port: 127.0.0.1:" .. adminPort ..
          (daemonMode and " (daemon)" or ""))
print("Auth: " .. (authRequired and "enabled" or "disabled"))
print("Commands:")
print("  send <clientId[,clientId2,...]> <message> - send to specific clients")
print("  broadcast <message> - broadcast message")
print("  wol <clientId[,clientId2,...]> <MAC> - send WOL to clients")
print("  clients     - list connected clients")
print("  quit        - shutdown server")
print("Enter commands (Ctrl+D for EOF), or use cli to send via admin port")
print("==============================")

-- Connected/pending managed by pool
local pool = ClientPool.new()
local clients = pool.clients
local pending = pool.pending
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

-- Helper: print online clients list
local function printOnlineClientsList()
    printBoth("Online clients:")
    local count = 0
    for cid, cinfo in pairs(clients) do
        if cinfo.connected then
            printBoth("  " .. cid)
            count = count + 1
        end
    end
    printBoth("Total " .. count .. " clients online")
end

-- Helper: send one binary frame to target client IDs, with optional onSent callback
-- use shared helper from proto
local function sendFrameToTargets(targets, mtype, payload, onSent)
    local sent = 0
    local missing = {}
    for _, id in ipairs(targets) do
        local cinfo = clients[id]
        if cinfo and cinfo.connected then
            local ok = proto.sendFrame(cinfo.socket, mtype, payload)
            if ok then
                sent = sent + 1
                if onSent then onSent(id) end
            end
        else
            table.insert(missing, id)
        end
    end
    return sent, missing
end

-- Set server non-blocking
server:settimeout(0)

-- Handle network events
local function processNetwork()
    -- Accept new client
    local client = server:accept()
    if client then
        client:settimeout(0) -- set client non-blocking
        if authRequired then
            -- Do not assign clientId before AUTH_OK
            pool:addPending(client)
            print("New connection pending auth")
            sendFrame(client, TYPE.AUTH_REQUIRED, "")
        else
            -- Auth not required: assign id immediately
            local clientId = select(1, pool:addClientNoAuth(client))
            print("New client connected: " .. clientId)
            sendFrame(client, TYPE.TEXT, "Welcome! Your ID is: " .. clientId)
        end
    end

    -- Handle pending clients (auth handshake)
    for key, pinfo in pairs(pending) do
        if pinfo.connected then
            local frames, rx, err = proto.readSome(pinfo.socket, pinfo.rx, 10)
            pinfo.rx = rx
            for _, f in ipairs(frames) do
                pinfo.lastSeen = socket.gettime()
                if f.type == TYPE.AUTH then
                    local provided = f.payload
                    if provided == authToken then
                        -- Promote to authenticated clients and assign clientId
                        local clientId = select(1, pool:promotePending(pinfo.socket))
                        sendFrame(pinfo.socket, TYPE.AUTH_OK, "")
                        sendFrame(pinfo.socket, TYPE.TEXT,
                                  "Welcome! Your ID is: " .. clientId)
                        print("New client authenticated: " .. clientId)
                    else
                        -- Wrong token: notify and close
                        sendFrame(pinfo.socket, TYPE.AUTH_FAILED, "")
                        pinfo.socket:close()
                        pool:removePending(pinfo.socket)
                    end
                else
                    -- Any non-AUTH frame before authentication is a failure
                    sendFrame(pinfo.socket, TYPE.AUTH_FAILED, "")
                    pinfo.socket:close()
                    pool:removePending(pinfo.socket)
                end
            end
            if err and err ~= "timeout" then
                print("Pending client disconnected during auth")
                pinfo.socket:close()
                pool:removePending(pinfo.socket)
            else
                -- Check handshake timeout
                local now = socket.gettime()
                if (pinfo.connectedAt or now) and
                    (now - (pinfo.connectedAt or now) > authHandshakeTimeout) then
                    sendFrame(pinfo.socket, TYPE.AUTH_FAILED, "")
                    pinfo.socket:close()
                    pool:removePending(pinfo.socket)
                end
            end
        end
    end

    -- Handle existing clients
    for clientId, clientInfo in pairs(clients) do
        if clientInfo.connected then
            local client = clientInfo.socket
            local frames, rx, err = proto.readSome(client, clientInfo.rx, 10)
            clientInfo.rx = rx
            for _, f in ipairs(frames) do
                clientInfo.lastSeen = socket.gettime()
                if clients[clientId] and clientInfo.authenticated then
                    if f.type == TYPE.PING then
                        sendFrame(client, TYPE.PONG, "")
                    elseif f.type == TYPE.PONG then
                        -- no-op
                    elseif f.type == TYPE.RESULT then
                        local result = f.payload
                        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
                        local fullCommand = pendingCommands[clientId] or "unknown"
                        pendingCommands[clientId] = nil
                        printBoth("Received command result from " .. clientId)
                        printBoth("Executed command: " .. fullCommand)
                        printBoth("Received at: " .. timestamp)
                        printBoth("=" .. string.rep("=", 50))
                        printBoth(result)
                    elseif f.type == TYPE.TEXT then
                        print("Received message from " .. clientId .. ": " .. f.payload)
                    else
                        -- ignore unknown types
                    end
                end
            end
            if err and err ~= "timeout" then
                print("Client " .. clientId .. " disconnected")
                client:close()
                pendingCommands[clientId] = nil
                pool:markDisconnected(clientId)
            end

            -- Heartbeat: send periodic PING
            if clients[clientId] and clientInfo.authenticated then
                local now = socket.gettime()
                if now - (clientInfo.lastPing or 0) >= heartbeatInterval then
                    local ok, sendErr = sendFrame(client, TYPE.PING, "")
                    if ok then
                        clientInfo.lastPing = now
                    else
                        print(
                            "Heartbeat send failed for " .. clientId .. ": " ..
                                tostring(sendErr))
                        client:close()
                        pendingCommands[clientId] = nil
                        pool:markDisconnected(clientId)
                    end
                end
                -- Heartbeat: disconnect if timeout
                if clients[clientId] and
                    (now - (clientInfo.lastSeen or now) > heartbeatTimeout) then
                    print("Client " .. clientId .. " timed out (no heartbeat)")
                    client:close()
                    pendingCommands[clientId] = nil
                    pool:markDisconnected(clientId)
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

    if cmd == Command.SEND then
        -- Expect: send <clientId[,clientId2,...]> <message>
        local targetsStr, payload = message:match("^(%S+)%s+(.+)$")
        if not targetsStr or not payload or targetsStr == "" or payload == "" then
            printBoth("Usage: send <clientId[,clientId2,...]> <message>")
            printOnlineClientsList()
            return true
        end

        local targets = {}
        for id in targetsStr:gmatch("[^,]+") do
            -- trim spaces
            id = id:gsub("^%s+", ""):gsub("%s+$", "")
            if id ~= "" then table.insert(targets, id) end
        end

        local sent, missing = sendFrameToTargets(targets, TYPE.TEXT, payload, nil)
        printBoth("Message sent to " .. sent .. " clients")
        if #missing > 0 then
            printBoth("Not found/offline: " .. table.concat(missing, ", "))
        end

    elseif cmd == Command.BROADCAST and message ~= "" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                local success = sendFrame(clientInfo.socket, TYPE.TEXT,
                                          "[Broadcast] " .. message)
                if success then count = count + 1 end
            end
        end
        printBoth("Broadcast sent to " .. count .. " clients")

        -- exec removed
    elseif cmd == Command.WOL then
        -- Expect: wol <clientId[,clientId2,...]> <MAC>
        local targetsStr, mac = message:match("^(%S+)%s+(.+)$")
        if not targetsStr or not mac or targetsStr == "" or mac == "" then
            printBoth("Usage: wol <clientId[,clientId2,...]> <MAC>")
            printOnlineClientsList()
            return true
        end

        local targets = {}
        for id in targetsStr:gmatch("[^,]+") do
            id = id:gsub("^%s+", ""):gsub("%s+$", "")
            if id ~= "" then table.insert(targets, id) end
        end

        local onSent = function(id) pendingCommands[id] = Command.WOL .. " " .. mac end
        local sent, missing = sendFrameToTargets(targets, TYPE.WOL, mac, onSent)
        printBoth("WOL command (MAC: " .. mac .. ") sent to " .. sent ..
                      " clients")
        if #missing > 0 then
            printBoth("Not found/offline: " .. table.concat(missing, ", "))
        end

    elseif cmd == Command.CLIENTS then
        printOnlineClientsList()

    elseif cmd == Command.QUIT then
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                sendFrame(clientInfo.socket, TYPE.SERVER_SHUTDOWN, "")
                clientInfo.socket:close()
            end
            pendingCommands[clientId] = nil
            pool:markDisconnected(clientId)
        end
        -- Close any pending unauthenticated connections (with explicit logs)
        for _, pinfo in pairs(pending) do
            if pinfo.connected then
                local pip, pport = pinfo.socket:getpeername()
                if pip and pport then
                    printBoth("Closing pending unauth connection from " .. pip .. ":" .. pport)
                else
                    printBoth("Closing pending unauth connection")
                end
                pinfo.socket:close()
            end
            pool:removePending(pinfo.socket)
        end
        return false -- 退出

    elseif cmd == Command.BROADCAST and message == "" then
        printBoth("Usage: broadcast <message>")

        -- exec usage removed
    elseif cmd == Command.WOL and message == "" then
        printBoth("Usage: wol <clientId[,clientId2,...]> <MAC>")
        printBoth("Example: wol client-1 00:11:22:33:44:55")
        printBoth("Example: wol client-1,client-2 00-11-22-33-44-55")

    else
        printBoth("Unknown command: " .. input)
        printBoth(
            "Available commands: send <clientId[,clientId2,...]> <message>, broadcast <message>, wol <clientId[,clientId2,...]> <MAC>, clients, quit")
    end

    return true -- continue
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
            adminClients[aid] = {socket = adminClient, id = aid}
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
                        if c.connected then
                            c.socket:close()
                        end
                    end
                    ainfo.socket:send(Message.SERVER_SHUTDOWN .. "\n")
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
            if not line then -- EOF
                break
            end
            -- Trim leading/trailing whitespace (Lua 5.1 compatible)
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then table.insert(commands, line) end
        end

        -- Process all commands
        local shouldContinue = true
        for _, cmd in ipairs(commands) do
            print("Executing: " .. cmd)
            shouldContinue = processCommand(cmd)
            if not shouldContinue then break end
        end

        if not shouldContinue then break end
    end
end

-- Close server
server:close()
print("Server closed")
