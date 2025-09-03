local socket = require("socket")

local host = "192.168.115.129"  -- 如果在不同设备上测试，这里改成服务端 IP
local port = 8080

-- 创建 TCP 连接
local tcp = assert(socket.tcp())
tcp:settimeout(5)

assert(tcp:connect(host, port))

-- 发送数据
tcp:send("Hello Server!\n")

-- 接收数据
local response, err = tcp:receive()
if not err then
    print("Received from server: " .. response)
else
    print("Receive error: " .. tostring(err))
end

tcp:close()