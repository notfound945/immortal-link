local socket = require("socket")

-- 监听所有 IP 的 65530 端口
local server = assert(socket.bind("*", 65530))
local ip, port = server:getsockname()

print("=== Immortal Link 服务器 ===")
print("监听地址: " .. ip .. ":" .. port)
print("输入命令:")
print("  send <消息>     - 向所有客户端发送消息")
print("  broadcast <消息> - 广播消息")
print("  exec <命令>     - 让所有客户端执行系统命令")
print("  clients         - 显示连接的客户端")
print("  quit           - 退出服务器")
print("输入多行命令后按 Ctrl+D (EOF) 执行")
print("==============================")

-- 存储连接的客户端
local clients = {}
local clientCounter = 0
-- 存储发送给客户端的命令，用于生成有意义的文件名
local pendingCommands = {}

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
                    -- 生成文件名：客户端ID + 命令名 + 时间
                    local timestamp = os.date("%Y%m%d_%H%M%S")
                    local cmdName = "unknown"
                    local fullCommand = "未知命令"
                    
                    -- 尝试获取对应的命令名
                    if pendingCommands[clientId] then
                        fullCommand = pendingCommands[clientId]
                        cmdName = fullCommand:match("^(%S+)") or "unknown"
                        cmdName = cmdName:gsub("[^%w%-_]", "_")  -- 替换特殊字符
                        pendingCommands[clientId] = nil  -- 清除已处理的命令
                    end
                    
                    -- 确保 outputs 目录存在
                    local outputDir = "outputs"
                    os.execute("mkdir -p " .. outputDir)  -- 创建目录（如果不存在）
                    
                    local filename = outputDir .. "/" .. clientId .. "_" .. cmdName .. "_" .. timestamp .. ".txt"
                    
                    local file = io.open(filename, "w")
                    if file then
                        file:write("客户端ID: " .. clientId .. "\n")
                        file:write("执行命令: " .. fullCommand .. "\n")
                        file:write("接收时间: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
                        file:write("=" .. string.rep("=", 50) .. "\n")
                        file:write(result)
                        file:close()
                        print("收到来自 " .. clientId .. " 的命令执行结果，已保存到文件: " .. filename)
                    else
                        print("收到来自 " .. clientId .. " 的命令执行结果，但无法写入文件: " .. filename)
                    end
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
        print("消息已发送给 " .. count .. " 个客户端")
        
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
        print("广播消息已发送给 " .. count .. " 个客户端")
        
    elseif cmd == "exec" and message ~= "" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                local success = clientInfo.socket:send("CMD:" .. message .. "\n")
                if success then
                    count = count + 1
                    -- 记录发送给该客户端的命令，用于后续文件命名
                    pendingCommands[clientId] = message
                end
            end
        end
        print("命令 '" .. message .. "' 已发送给 " .. count .. " 个客户端执行")
        
    elseif cmd == "clients" then
        local count = 0
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                print("  " .. clientId)
                count = count + 1
            end
        end
        print("总共 " .. count .. " 个客户端在线")
        
    elseif cmd == "quit" then
        for clientId, clientInfo in pairs(clients) do
            if clientInfo.connected then
                clientInfo.socket:send("服务器即将关闭，再见！\n")
                clientInfo.socket:close()
            end
        end
        return false  -- 退出
        
    elseif cmd == "send" and message == "" then
        print("用法: send <消息>")
        
    elseif cmd == "broadcast" and message == "" then
        print("用法: broadcast <消息>")
        
    elseif cmd == "exec" and message == "" then
        print("用法: exec <命令>")
        print("示例: exec pwd")
        
    else
        print("未知命令: " .. input)
        print("可用命令: send <消息>, broadcast <消息>, exec <命令>, clients, quit")
    end
    
    return true  -- 继续运行
end

-- 主循环：等待完整输入
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

-- 关闭服务器
server:close()
print("服务器已关闭")
