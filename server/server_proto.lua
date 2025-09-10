-- Binary frame protocol helpers
-- Frame format: [4-byte BE length L][1-byte type T][L-1 bytes payload]

local M = {}

M.TYPE = {
    PING = 1,
    PONG = 2,
    TEXT = 3,
    WOL = 16,
    RESULT = 32,
    AUTH = 48,
    AUTH_REQUIRED = 49,
    AUTH_OK = 50,
    AUTH_FAILED = 51,
    SERVER_SHUTDOWN = 64,
}

local function u32_to_be(n)
    local b1 = math.floor(n / 16777216) % 256
    local b2 = math.floor(n / 65536) % 256
    local b3 = math.floor(n / 256) % 256
    local b4 = n % 256
    return string.char(b1, b2, b3, b4)
end

local function be_to_u32(s)
    local b1, b2, b3, b4 = s:byte(1, 4)
    return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
end

function M.sendFrame(sock, mtype, payload)
    payload = payload or ""
    local len = 1 + #payload
    local frame = u32_to_be(len) .. string.char(mtype) .. payload
    return sock:send(frame)
end

function M.newRx()
    return { state = "header", need = 4, buf = "", frameLen = 0 }
end

-- Read up to maxFrames frames from non-blocking socket. Returns (frames, rx, err)
function M.readSome(sock, rx, maxFrames)
    local frames = {}
    local processed = 0
    rx = rx or M.newRx()

    while processed < (maxFrames or 10) do
        if rx.state == "header" then
            local chunk, err = sock:receive(rx.need)
            if chunk then
                rx.buf = rx.buf .. chunk
                rx.need = 4 - #rx.buf
                if rx.need == 0 then
                    rx.frameLen = be_to_u32(rx.buf)
                    rx.buf = ""
                    rx.need = rx.frameLen
                    rx.state = "frame"
                end
            else
                return frames, rx, err
            end
        elseif rx.state == "frame" then
            if rx.need == 0 then
                rx.state = "header"; rx.need = 4; rx.buf = ""; rx.frameLen = 0
            else
                local chunk, err = sock:receive(rx.need)
                if chunk then
                    rx.buf = rx.buf .. chunk
                    rx.need = rx.frameLen - #rx.buf
                    if rx.need == 0 then
                        local mtype = rx.buf:byte(1)
                        local payload = rx.buf:sub(2)
                        table.insert(frames, { type = mtype, payload = payload })
                        rx.state = "header"; rx.need = 4; rx.buf = ""; rx.frameLen = 0
                        processed = processed + 1
                    end
                else
                    return frames, rx, err
                end
            end
        end
    end

    return frames, rx, nil
end

return M