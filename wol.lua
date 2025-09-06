local socket = require("socket")

local wol = {}

-- 检查MAC地址有效性
local function is_valid_mac(mac)
    local pattern1 = "^%x%x[:-]%x%x[:-]%x%x[:-]%x%x[:-]%x%x[:-]%x%x$"
    local pattern2 = "^%x%x%x%x%x%x%x%x%x%x%x%x$"
    return mac:match(pattern1) or mac:match(pattern2)
end

-- MAC地址转二进制
local function mac_to_binary(mac)
    local clean_mac = mac:gsub("[:-]", "")
    local binary = ""
    for i = 1, 12, 2 do
        local byte = clean_mac:sub(i, i+1)
        binary = binary .. string.char(tonumber(byte, 16))
    end
    return binary
end

-- 构建魔术包
local function build_magic_packet(mac_binary)
    local header = string.rep(string.char(0xFF), 6)
    local body = string.rep(mac_binary, 16)
    return header .. body
end

-- 发送WOL包（修复参数类型）
function wol.send(mac, options)
    if not is_valid_mac(mac) then
        return false, "无效的MAC地址格式"
    end
    
    options = options or {}
    local port = options.port or 9
    local broadcast = options.broadcast or "255.255.255.255"
    
    local mac_binary = mac_to_binary(mac)
    local magic_packet = build_magic_packet(mac_binary)
    
    -- 创建UDP套接字
    local udp = socket.udp()
    if not udp then
        return false, "无法创建UDP套接字"
    end
    
    -- 先绑定到 IPv4，再设置广播（macOS 需要）
    local ok_bind, err_bind = udp:setsockname("0.0.0.0", 0)
    if not ok_bind then
        udp:close()
        return false, "无法绑定本地地址: " .. (err_bind or "")
    end

    local ok, err = udp:setoption("broadcast", true)
    if not ok then
        udp:close()
        return false, "无法设置广播选项: " .. (err or "")
    end
    
    -- 发送魔术包
    local bytes_sent, err = udp:sendto(magic_packet, broadcast, port)
    udp:close()
    
    if not bytes_sent then
        return false, "发送失败: " .. (err or "")
    end
    
    return true, string.format("成功发送魔术包到 %s (端口 %d)", mac, port)
end

return wol