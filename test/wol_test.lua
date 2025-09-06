local wol = require("wol")

-- 测试用例：有效的MAC地址
local function test_valid_mac()
    local mac = "6c:1f:f7:75:c7:0e"
    local success, message = wol.send(mac, {
        broadcast = "192.168.115.191"
    })
    assert(success, "测试失败: " .. message)
    print("测试通过: 有效的MAC地址")
end

-- 测试用例：无效的MAC地址
local function test_invalid_mac()
    local mac = "01:23:45:67:89:ZZ"
    local success, message = wol.send(mac)
    assert(not success, "测试失败: 应该检测到无效的MAC地址")
    print("测试通过: 无效的MAC地址")
end

-- 测试用例：无分隔符的MAC地址
local function test_mac_without_delimiters()
    local mac = "0123456789AB"
    local success, message = wol.send(mac)
    assert(success, "测试失败: " .. message)
    print("测试通过: 无分隔符的MAC地址")
end

-- 测试用例：自定义端口和广播地址
local function test_custom_options()
    local mac = "01:23:45:67:89:AB"
    local options = { port = 7, broadcast = "192.168.1.255" }
    local success, message = wol.send(mac, options)
    assert(success, "测试失败: " .. message)
    print("测试通过: 自定义端口和广播地址")
end

-- 运行所有测试用例
local function run_tests()
    test_valid_mac()
    test_invalid_mac()
    test_mac_without_delimiters()
    test_custom_options()
    print("所有测试用例已通过")
end

run_tests()
