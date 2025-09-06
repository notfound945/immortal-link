local socket = require("socket")

-- 简单参数解析：支持 --daemon 与 --admin-port <port>
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

-- 监听所有 IP 的 65530 端口
local server = assert(socket.bind("*", 65530))
local ip, port = server:getsockname()

print("=== Immortal Link 服务器 ===")
print("监听地址: " .. ip .. ":" .. port)
print("管理端口: 127.0.0.1:" .. adminPort .. (daemonMode and " (daemon)" or ""))
print("输入命令:")
print("  send <消息>     - 向所有客户端发送消息")
print("  broadcast <消息> - 广播消息")
-- 已移除 exec 指令
print("  wol <MAC地址>   - 发送 WOL 唤醒指令")
print("  clients         - 显示连接的客户端")
print("  quit           - 退出服务器")
print("输入多行命令后按 Ctrl+D (EOF) 执行；或通过 cli 连接管理端口发送命令")
print("==============================")

-- 存储连接的客户端
local clients = {}
local clientCounter = 0
-- 存储发送给客户端的命令，用于生成有意义的文件名
local pendingCommands = {}

-- 管理端口：本地回环监听
local adminServer = assert(socket.bind("127.0.0.1", adminPort))
adminServer:settimeout(0)
local adminClients = {}
local adminClientCounter = 0

-- 当前命令的应答器（仅用于管理端口会话）
local currentResponder = nil
local function printBoth(msg)
    print(msg)
    if currentResponder then
        -- 确保以换行结尾
        currentResponder(msg .. "\n")
    end
end

-- 设置服务器为非阻塞模式
server:settimeout(0)

-- 创建协程来处理网络事件
local function processNetwork()
    -- 尝试接受新的客户端连接
    local client = server:accept()
    if client then
        clientCounter = clientCounter + 1
        local clientId = "client-" .. clientCounter
        clients[clientId] = {
            socket = client,
            id = clientId,
            connected = true
        }
        client:settimeout(0)  -- 设置客户端为非阻塞模式
        print("新客户端连接: " .. clientId)
        
        -- 发送欢迎消息
        client:send("欢迎连接到服务器！你的ID是: " .. clientId .. "\n")
    end
    
    -- 处理现有客户端
    for clientId, clientInfo in pairs(clients) do
        if clientInfo.connected then
            local client = clientInfo.socket
            local line, err = client:receive()
            if line then
                -- 检查是否是命令执行结果
                local result = line:match("^RESULT:(.*)$")
                if result then
                    -- 直接输出到标准输出（同时回写到管理连接，如果存在）
                    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
                    local fullCommand = pendingCommands[clientId] or "未知命令"
                    pendingCommands[clientId] = nil

                    printBoth("收到来自 " .. clientId .. " 的命令执行结果")
                    printBoth("执行命令: " .. fullCommand)
                    printBoth("接收时间: " .. timestamp)
                    printBoth("=" .. string.rep("=", 50))
                    printBoth(result)
                else
                    print("收到来自 " .. clientId .. " 的消息: " .. line)
                end
            elseif err and err ~= "timeout" then
                print("客户端 " .. clientId .. " 断开连接")
                client:close()
                clients[clientId] = nil
            end
        end
    end
end

-- 处理命令的函数
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
        printBoth("消息已发送给 " .. count .. " 个客户端")
        
    elseif cmd == "broadcast" and message ~= "" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                local success = clientInfo.socket:send("[广播] " .. message .. "\n")
                if success then
                    count = count + 1
                end
            end
        end
        printBoth("广播消息已发送给 " .. count .. " 个客户端")
        
    -- exec 指令已移除
    elseif cmd == "wol" and message ~= "" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                local success = clientInfo.socket:send("WOL:" .. message .. "\n")
                if success then
                    count = count + 1
                    -- 记录发送给该客户端的命令，用于后续文件命名
                    pendingCommands[clientId] = "wol " .. message
                end
            end
        end
        printBoth("WOL命令 (MAC: " .. message .. ") 已发送给 " .. count .. " 个客户端")
        
    elseif cmd == "clients" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                printBoth("  " .. clientId)
                count = count + 1
            end
        end
        printBoth("总共 " .. count .. " 个客户端在线")
        
    elseif cmd == "quit" then
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                clientInfo.socket:send("服务器即将关闭，再见！\n")
                clientInfo.socket:close()
            end
        end
        return false  -- 退出
        
    elseif cmd == "send" and message == "" then
        printBoth("用法: send <消息>")
        
    elseif cmd == "broadcast" and message == "" then
        printBoth("用法: broadcast <消息>")
        
    -- exec 用法说明已移除
    elseif cmd == "wol" and message == "" then
        printBoth("用法: wol <MAC地址>")
        printBoth("示例: wol 00:11:22:33:44:55")
        printBoth("示例: wol 00-11-22-33-44-55")
        
    else
        printBoth("未知命令: " .. input)
        printBoth("可用命令: send <消息>, broadcast <消息>, wol <MAC地址>, clients, quit")
    end
    
    return true  -- 继续运行
end

-- 主循环：等待完整输入
if daemonMode then
    -- 守护模式：仅处理网络与管理端口，不读取stdin
    while true do
        processNetwork()
        -- 管理端口：接受并处理命令
        local adminClient = adminServer:accept()
        if adminClient then
            adminClientCounter = adminClientCounter + 1
            local aid = "admin-" .. adminClientCounter
            adminClients[aid] = { socket = adminClient, id = aid }
            adminClient:settimeout(0)
            print("管理客户端连接: " .. aid)
        end
        for aid, ainfo in pairs(adminClients) do
            local line, err = ainfo.socket:receive()
            if line then
                -- 处理管理命令并回显
                currentResponder = function(msg)
                    ainfo.socket:send(msg)
                end
                local keepRunning = processCommand(line)
                currentResponder = nil
                if not keepRunning then
                    -- 关闭资源并退出
                    for _, c in pairs(clients) do
                        if c.connected then c.socket:close() end
                    end
                    ainfo.socket:send("服务器已关闭\n")
                    ainfo.socket:close()
                    adminClients[aid] = nil
                    server:close()
                    return
                end
            elseif err and err ~= "timeout" then
                print("管理客户端断开: " .. aid)
                ainfo.socket:close()
                adminClients[aid] = nil
            end
        end
        socket.sleep(0.1)
    end
else
    while true do
        -- 持续处理网络事件
        processNetwork()
        
        print("\n请输入命令 (多行输入后按 Ctrl+D 执行):")
        io.write("server> ")
        io.flush()
        
        -- 读取所有输入直到EOF
        local commands = {}
        while true do
            local line = io.read()
            if not line then  -- EOF
                break
            end
            -- 简单的去除首尾空白字符（Lua 5.1兼容）
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                table.insert(commands, line)
            end
        end
        
        -- 处理所有命令
        local shouldContinue = true
        for _, cmd in ipairs(commands) do
            print("执行命令: " .. cmd)
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

-- 关闭服务器
server:close()
print("服务器已关闭")
