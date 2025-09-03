local socket = require("socket")

-- 监听所有 IP 的 8080 端口
local server = assert(socket.bind("*", 8080))
local ip, port = server:getsockname()

print("Server listening on " .. ip .. ":" .. port .. "...")
print("使用 'exit' 命令可以关闭连接")

while true do
    -- 等待客户端连接（阻塞）
    local client = server:accept()
    client:settimeout(0)  -- 非阻塞模式，便于处理多个客户端
    
    print("新客户端连接")
    
    -- 长连接：保持连接，持续通信
    while true do
        -- 接收数据
        local line, err, partial = client:receive()
        
        -- 处理接收结果
        if not err then
            -- 客户端发送了完整数据
            print("Received from client: " .. line)
            
            -- 如果客户端发送exit命令，则关闭连接
            if line == "exit" then
                client:send("连接即将关闭，再见！\n")
                break
            end
            
            -- 回复消息
            client:send("服务器已收到: " .. line .. "\n")
        elseif err ~= "timeout" then
            -- 发生错误（非超时），关闭连接
            print("连接错误: " .. tostring(err))
            break
        end
        
        -- 短暂休眠，避免CPU占用过高
        socket.sleep(0.1)
    end
    
    -- 关闭客户端连接
    client:close()
    print("客户端连接已关闭")
end
