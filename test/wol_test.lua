local wol = require("client.wol")

-- Test: valid MAC
local function test_valid_mac()
    local mac = "bc:12:d7:f5:c7:ae"
    local success, message = wol.send(mac, {broadcast = "192.168.115.191"})
    assert(success, "Test failed: " .. message)
    print("Passed: valid MAC")
end

-- Test: invalid MAC
local function test_invalid_mac()
    local mac = "01:23:45:67:89:ZZ"
    local success, message = wol.send(mac)
    assert(not success, "Test failed: invalid MAC should be detected")
    print("Passed: invalid MAC")
end

-- Test: MAC without delimiters
local function test_mac_without_delimiters()
    local mac = "0123456789AB"
    local success, message = wol.send(mac)
    assert(success, "Test failed: " .. message)
    print("Passed: MAC without delimiters")
end

-- Test: custom options
local function test_custom_options()
    local mac = "01:23:45:67:89:AB"
    local options = {port = 7, broadcast = "192.168.1.255"}
    local success, message = wol.send(mac, options)
    assert(success, "Test failed: " .. message)
    print("Passed: custom port and broadcast")
end

-- Run all tests
local function run_tests()
    test_valid_mac()
    test_invalid_mac()
    test_mac_without_delimiters()
    test_custom_options()
    print("All tests passed")
end

run_tests()
