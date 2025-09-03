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
print("请输入消息发送（输入 'exit' 断开连接）")

-- 长连接：保持连接，持续通信
while true do
    -- 读取用户输入
    io.write("> ")
    io.flush()
    local input = io.read()
    
    if not input then  -- 处理Ctrl+D等输入结束情况
        input = "exit"
    end
    
    -- 发送数据
    tcp:send(input .. "\n")
    
    -- 如果输入exit，则退出循环
    if input == "exit" then
        break
    end
    
    -- 接收服务器回复
    local response, err = tcp:receive()
    if not err then
        print("服务器回复: " .. response)
    else
        print("接收错误: " .. tostring(err))
        break
    end
end

-- 关闭连接
tcp:close()
print("已与服务器断开连接")
    