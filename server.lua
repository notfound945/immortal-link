local socket = require("socket")

-- 监听所有 IP 的 8080 端口
local server = assert(socket.bind("*", 8080))
local ip, port = server:getsockname()

print("Server listening on " .. ip .. ":" .. port .. "...")

while true do
    -- 等待客户端连接（阻塞）
    local client = server:accept()
    client:settimeout(10)

    -- 接收数据
    local line, err = client:receive()
    if not err then
        print("Received from client: " .. line)
        -- 回复消息
        client:send("Hello from server! You said: " .. line .. "\n")
    else
        print("Receive error: " .. tostring(err))
    end

    client:close()
end