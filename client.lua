local socket = require("socket")

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

-- MAC地址验证函数
local function validateMacAddress(mac)
    if not mac or type(mac) ~= "string" then
        return false, "MAC地址不能为空"
    end
    
    -- 移除所有分隔符并转换为大写
    local cleanMac = mac:upper():gsub("[:%-%s]", "")
    
    -- 检查长度是否为12个字符
    if #cleanMac ~= 12 then
        return false, "MAC地址长度错误，应为12个十六进制字符"
    end
    
    -- 检查是否都是十六进制字符
    if not cleanMac:match("^[0-9A-F]+$") then
        return false, "MAC地址包含非十六进制字符"
    end
    
    return true, cleanMac
end

-- 构造WOL魔术包的函数
local function createWolPacket(mac)
    local isValid, cleanMac = validateMacAddress(mac)
    if not isValid then
        return nil, cleanMac  -- cleanMac这里是错误信息
    end
    
    -- 将MAC地址转换为字节数组
    local macBytes = {}
    for i = 1, 12, 2 do
        local byte = tonumber(cleanMac:sub(i, i+1), 16)
        table.insert(macBytes, string.char(byte))
    end
    
    local macString = table.concat(macBytes)
    
    -- 构造魔术包: 6个0xFF + 16次重复MAC地址
    local packet = string.rep(string.char(0xFF), 6)  -- 6个0xFF
    packet = packet .. string.rep(macString, 16)     -- 16次重复MAC地址
    
    return packet, cleanMac
end

-- 发送WOL包的函数（纯UDP原始方式）
local function sendWolPacket(mac)
    local packet, cleanMacOrError = createWolPacket(mac)
    if not packet then
        return false, "MAC地址验证失败: " .. cleanMacOrError
    end
    
    -- 直接使用指定的网络广播地址
    local attempts = {
        -- 优先使用当前网络的广播地址 (192.168.115.191/26)
        {"192.168.115.191", 9, "当前网段广播(/26)"},
        -- 标准全局广播地址（需要root权限）
        {"255.255.255.255", 9, "全局广播"},
        -- 多端口尝试
        {"192.168.115.191", 7, "当前网段广播(端口7)"},
        {"255.255.255.255", 7, "全局广播(端口7)"}
    }
    
    local lastError = "未知错误"
    local successCount = 0
    
    print("开始发送WOL包，MAC地址: " .. cleanMacOrError)
    print("包长度: " .. #packet .. " 字节")
    print("目标网络: 192.168.115.0/26")
    
    for i, attempt in ipairs(attempts) do
        local targetIp, targetPort, description = attempt[1], attempt[2], attempt[3]
        local attemptSuccess = false
        
        -- 创建新的UDP socket
        local udp = socket.udp()
        if udp then
            -- 先绑定到 IPv4，再设置广播（macOS 需要）
            local bindOk, bindErr = udp:setsockname("0.0.0.0", 0)
            if not bindOk then
                lastError = "无法绑定本地地址: " .. tostring(bindErr)
                print("尝试 " .. i .. " (" .. description .. "): 失败 - " .. lastError)
                udp:close()
                goto continue_attempt
            end

            -- 设置socket选项
            local broadcastSet = udp:setoption("broadcast", true)
            local reuseSet = udp:setoption("reuseaddr", true)
            
            -- 如果是广播地址，检查是否设置成功
            if not targetIp:match("255$") or broadcastSet then
                -- 尝试发送
                local success, err = udp:sendto(packet, targetIp, targetPort)
                
                if success then
                    successCount = successCount + 1
                    print("尝试 " .. i .. " (" .. description .. "): 成功发送到 " .. targetIp .. ":" .. targetPort)
                    attemptSuccess = true
                else
                    lastError = tostring(err)
                    print("尝试 " .. i .. " (" .. description .. "): 失败 - " .. lastError)
                end
            else
                print("尝试 " .. i .. " (" .. description .. "): 设置广播选项失败")
            end
            
            udp:close()
            ::continue_attempt::
        else
            lastError = "无法创建UDP socket"
            print("尝试 " .. i .. " 失败: " .. lastError)
        end
    end
    
    if successCount > 0 then
        return true, "WOL包发送完成! 成功发送 " .. successCount .. " 次，MAC地址: " .. cleanMacOrError .. 
                    "\n注意: 如果目标设备未唤醒，可能需要:\n" ..
                    "1. 确保目标设备的WOL功能已启用\n" ..
                    "2. 检查网络设备(路由器/交换机)是否支持WOL转发\n" ..
                    "3. 确保客户端与目标设备在同一网段"
    else
        return false, "所有WOL发送尝试都失败，最后错误: " .. lastError .. 
                     "\n解决方案:\n" ..
                     "1. 使用root权限运行: sudo lua client.lua\n" ..
                     "2. 检查防火墙是否阻止UDP端口9的出站连接\n" ..
                     "3. 确认网络接口配置正确"
    end
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