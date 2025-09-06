local socket = require("socket")

local host = "127.0.0.1"
local port = 65531

-- Usage: lua cli.lua [--port <p>] <command...>
for i = 1, #arg do
    if arg[i] == "--port" and arg[i+1] then
        local p = tonumber(arg[i+1])
        if p then port = p end
    end
end

-- Join remaining args as the command string
local parts = {}
for i = 1, #arg do
    if arg[i] ~= "--port" and tonumber(arg[i]) ~= port then
        table.insert(parts, arg[i])
    end
end

if #parts == 0 then
    print("Usage: lua cli.lua [--port <p>] <command>")
    os.exit(1)
end

local command = table.concat(parts, " ")

local tcp = assert(socket.tcp())
tcp:settimeout(2)
assert(tcp:connect(host, port))

assert(tcp:send(command .. "\n"))

tcp:settimeout(1)
local chunks = {}
while true do
    local data, err = tcp:receive()
    if data then
        table.insert(chunks, data)
    elseif err == "timeout" then
        break
    else
        break
    end
end

tcp:close()

if #chunks > 0 then
    print(table.concat(chunks, "\n"))
end


