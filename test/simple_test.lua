local socket = require("socket")
local udp = socket.udp()
-- Enable broadcast mode
local ok_bind, err_bind = udp:setsockname("0.0.0.0", 0)
if not ok_bind then
    print("bind failed:", err_bind)
else
    print("bind ok")
    local ok, err = udp:setoption("broadcast", true)
    if not ok then
        print("setoption failed:", err)
    else
        print("setoption ok")
        -- send empty packet
        local ok, err = udp:sendto("", "192.168.115.191", 9)
        print("send result:", ok, err)
    end
end
udp:close()