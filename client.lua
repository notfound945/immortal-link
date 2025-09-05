local socket = require("socket")

-- 定义默认主机和开发环境主机
local defaultHost = "127.0.0.1"
local devHost = "192.168.115.129"
local port = 8080

-- 解析命令行参数
local host = defaultHost  -- 默认使用本地主机
for i = 1, #arg do
    if arg[i] == "--host" and arg[i+1] then
        if arg[i+1] == "dev" then
            host = devHost
        elseif arg[i+1] == "local" then
            host = defaultHost
        else
            -- 支持直接指定IP地址
            host = arg[i+1]
        end
        break  -- 只处理第一个--host参数
    end
end

-- 创建 TCP 连接
local tcp = assert(socket.tcp())
tcp:settimeout(5)  -- 连接超时时间

-- 连接到服务端
local success, err = tcp:connect(host, port)
if not success then
    print("连接失败: " .. tostring(err))
    os.exit(1)
end

print("已连接到服务器 " .. host .. ":" .. port)
print("等待服务器消息...")

-- 设置非阻塞模式，持续接收服务器消息
tcp:settimeout(1)  -- 1秒超时

-- 长连接：只接收服务器消息
while true do
    -- 接收服务器消息
    local response, err = tcp:receive()
    if response then
        print("[服务器消息] " .. response)
        
        -- 如果服务器发送断开消息，则退出
        if response:match("再见") or response:match("断开") then
            break
        end
    elseif err and err ~= "timeout" then
        print("连接错误: " .. tostring(err))
        break
    else
        -- 超时，继续等待（可以在这里添加心跳检测）
        -- print("等待服务器消息...")
    end
    
    -- 短暂休眠
    socket.sleep(0.1)
end

-- 关闭连接
tcp:close()
print("已与服务器断开连接")
    