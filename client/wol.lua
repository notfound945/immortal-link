local socket = require("socket")

local wol = {}

-- Validate MAC address format
local function is_valid_mac(mac)
    local pattern1 = "^%x%x[:-]%x%x[:-]%x%x[:-]%x%x[:-]%x%x[:-]%x%x$"
    local pattern2 = "^%x%x%x%x%x%x%x%x%x%x%x%x$"
    return mac:match(pattern1) or mac:match(pattern2)
end

-- Convert MAC address to binary
local function mac_to_binary(mac)
    local clean_mac = mac:gsub("[:-]", "")
    local binary = ""
    for i = 1, 12, 2 do
        local byte = clean_mac:sub(i, i+1)
        binary = binary .. string.char(tonumber(byte, 16))
    end
    return binary
end

-- Build magic packet
local function build_magic_packet(mac_binary)
    local header = string.rep(string.char(0xFF), 6)
    local body = string.rep(mac_binary, 16)
    return header .. body
end

-- Send WOL packet
function wol.send(mac, options)
    if not is_valid_mac(mac) then
        return false, "Invalid MAC address format"
    end
    
    options = options or {}
    local port = options.port or 9
    local broadcast = options.broadcast or "255.255.255.255"
    
    local mac_binary = mac_to_binary(mac)
    local magic_packet = build_magic_packet(mac_binary)
    
    -- Create UDP socket
    local udp = socket.udp()
    if not udp then
        return false, "Failed to create UDP socket"
    end
    
    -- Bind to IPv4 before enabling broadcast (required on macOS)
    local ok_bind, err_bind = udp:setsockname("0.0.0.0", 0)
    if not ok_bind then
        udp:close()
        return false, "Failed to bind local address: " .. (err_bind or "")
    end

    local ok, err = udp:setoption("broadcast", true)
    if not ok then
        udp:close()
        return false, "Failed to set broadcast option: " .. (err or "")
    end
    
    -- Send magic packet
    local bytes_sent, err = udp:sendto(magic_packet, broadcast, port)
    udp:close()
    
    if not bytes_sent then
        return false, "Send failed: " .. (err or "")
    end
    
    return true, string.format("Magic packet sent to %s (port %d)", mac, port)
end

return wol