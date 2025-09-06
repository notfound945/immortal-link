local socket = require("socket")
local wol = require("wol")

-- 定义默认主机和开发环境主机
local defaultHost = "127.0.0.1"
local lsHost = "120.78.82.250"
local devHost = "192.168.115.129"
local port = 65530

-- 解析命令行参数
local host = defaultHost  -- 默认使用本地主机
for i = 1, #arg do
    if arg[i] == "--host" and arg[i+1] then
        if arg[i+1] == "dev" then
            host = devHost
        elseif arg[i+1] == "local" then
            host = defaultHost
        elseif arg[i+1] == "ls" then
            host = lsHost
        else
            -- 支持直接指定IP地址
            host = arg[i+1]
        end
        break  -- 只处理第一个--host参数
    end
end

-- 连接配置
local maxRetries = 10
local retryInterval = 2  -- 秒
local tcp = nil

-- 连接到服务器的函数
local function connectToServer()
    local newTcp = socket.tcp()
    newTcp:settimeout(5)  -- 连接超时时间
    
    local success, err = newTcp:connect(host, port)
    if success then
        print("已连接到服务器 " .. host .. ":" .. port)
        newTcp:settimeout(1)  -- 1秒超时
        return newTcp
    else
        newTcp:close()
        return nil, err
    end
end

-- 自动重连函数
local function autoReconnect()
    local retryCount = 0
    
    while retryCount < maxRetries do
        print("尝试重连到服务器... (第 " .. (retryCount + 1) .. "/" .. maxRetries .. " 次)")
        
        local newTcp, err = connectToServer()
        if newTcp then
            print("重连成功！")
            return newTcp
        else
            print("重连失败: " .. tostring(err))
            retryCount = retryCount + 1
            
            if retryCount < maxRetries then
                print("等待 " .. retryInterval .. " 秒后重试...")
                socket.sleep(retryInterval)
            end
        end
    end
    
    print("重连失败，已达到最大重试次数 (" .. maxRetries .. ")，程序退出")
    return nil
end

-- 初始连接
tcp, err = connectToServer()
if not tcp then
    print("初始连接失败: " .. tostring(err))
    tcp = autoReconnect()
    if not tcp then
        os.exit(1)
    end
end

print("等待服务器消息...")

-- 执行系统命令的函数
local function executeCommand(cmd)
    -- 使用 io.popen 执行命令并获取输出
    local handle = io.popen(cmd)
    if not handle then
        return "错误: 无法执行命令"
    end
    
    local result = handle:read("*a")  -- 读取所有输出
    handle:close()
    
    -- 去除结尾的换行符
    result = result:match("^(.-)%s*$") or result
    
    if result == "" then
        return "命令执行完成，无输出"
    end
    
    return result
end

-- 使用 wol.lua 提供的实现发送 WOL 包
local function sendWolPacket(mac)
    local ok, msg = wol.send(mac, { broadcast = "192.168.115.191", port = 9 })
    return ok, msg
end

-- 主循环：接收服务器消息并执行命令，支持自动重连
while true do
    -- 接收服务器消息
    local response, err = tcp:receive()
    if response then
        print("[服务器消息] " .. response)
        
        -- 如果服务器发送断开消息，则退出
        if response:match("再见") or response:match("断开") then
            break
        end
        
        -- 检查是否是命令执行请求
        local cmd = response:match("^CMD:(.+)$")
        if cmd then
            print("[执行命令] " .. cmd)
            local result = executeCommand(cmd)
            print("[命令结果] " .. result)
            
            -- 将结果发送回服务器
            local success, sendErr = tcp:send("RESULT:" .. result .. "\n")
            if not success then
                print("发送结果失败: " .. tostring(sendErr))
                print("连接可能已断开，尝试重连...")
                
                -- 关闭当前连接
                tcp:close()
                
                -- 尝试重连
                tcp = autoReconnect()
                if not tcp then
                    print("重连失败，程序退出")
                    os.exit(1)
                end
            else
                print("[已发送结果到服务器]")
            end
        end
        
        -- 检查是否是WOL命令请求
        local macAddress = response:match("^WOL:(.+)$")
        if macAddress then
            print("[执行WOL] MAC地址: " .. macAddress)
            local success, result = sendWolPacket(macAddress)
            
            local statusMsg = success and "[WOL成功] " or "[WOL失败] "
            print(statusMsg .. result)
            
            -- 将结果发送回服务器
            local sendSuccess, sendErr = tcp:send("RESULT:" .. result .. "\n")
            if not sendSuccess then
                print("发送WOL结果失败: " .. tostring(sendErr))
                print("连接可能已断开，尝试重连...")
                
                -- 关闭当前连接
                tcp:close()
                
                -- 尝试重连
                tcp = autoReconnect()
                if not tcp then
                    print("重连失败，程序退出")
                    os.exit(1)
                end
            else
                print("[已发送WOL结果到服务器]")
            end
        end
        
    elseif err and err ~= "timeout" then
        print("连接错误: " .. tostring(err))
        print("连接断开，尝试重连...")
        
        -- 关闭当前连接
        tcp:close()
        
        -- 尝试重连
        tcp = autoReconnect()
        if not tcp then
            print("重连失败，程序退出")
            os.exit(1)
        end
    else
        -- 超时，继续等待
        -- print("等待服务器消息...")
    end
    
    -- 短暂休眠
    socket.sleep(0.1)
end

-- 关闭连接
tcp:close()
print("已与服务器断开连接")