local socket = require("socket")
local udp = socket.udp()
-- 设置广播模式
local ok_bind, err_bind = udp:setsockname("0.0.0.0", 0)
if not ok_bind then
    print("bind 失败:", err_bind)
else
    print("bind 成功")
    local ok, err = udp:setoption("broadcast", true)
    if not ok then
        print("setoption 失败:", err)
    else
        print("setoption 成功")
        -- 发送空包
        local ok, err = udp:sendto("", "192.168.115.191", 9)
        print("发送结果:", ok, err)
    end
end
udp:close()