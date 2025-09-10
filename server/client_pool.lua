-- Client connection pool management
-- Manages: clients table, pending table, ID allocation/reuse

local socket = require("socket")

local M = {}

function M.new()
    local pool = {
        clients = {},
        pending = {},
        clientCounter = 0,
        freeIds = {},
    }

    -- Allocate an ID, prefer reuse
    function pool:allocateId()
        local id = table.remove(self.freeIds) -- LIFO reuse
        if id then return id end
        self.clientCounter = self.clientCounter + 1
        return "client-" .. self.clientCounter
    end

    -- Recycle an ID back into pool
    function pool:recycleId(id)
        if id and id ~= "" then table.insert(self.freeIds, id) end
    end

    -- Add a socket to pending (pre-auth)
    function pool:addPending(sock)
        self.pending[sock] = {
            socket = sock,
            connected = true,
            lastSeen = socket.gettime(),
            lastPing = 0,
            connectedAt = socket.gettime(),
            rx = { state = "header", need = 4, buf = "", frameLen = 0 },
        }
        return self.pending[sock]
    end

    -- Remove from pending (without promoting)
    function pool:removePending(sock)
        self.pending[sock] = nil
    end

    -- Promote a pending socket to authenticated client and assign ID
    function pool:promotePending(sock)
        local pinfo = self.pending[sock]
        if not pinfo then return nil end
        local id = self:allocateId()
        self.clients[id] = {
            socket = pinfo.socket,
            id = id,
            connected = true,
            lastSeen = socket.gettime(),
            lastPing = 0,
            authenticated = true,
            rx = { state = "header", need = 4, buf = "", frameLen = 0 },
        }
        self.pending[sock] = nil
        return id, self.clients[id]
    end

    -- Add a client directly (no auth required path)
    function pool:addClientNoAuth(sock)
        local id = self:allocateId()
        self.clients[id] = {
            socket = sock,
            id = id,
            connected = true,
            lastSeen = socket.gettime(),
            lastPing = 0,
            authenticated = true,
            rx = { state = "header", need = 4, buf = "", frameLen = 0 },
        }
        return id, self.clients[id]
    end

    -- Mark a client disconnected and recycle ID
    function pool:markDisconnected(clientId)
        local c = self.clients[clientId]
        if c then
            self:recycleId(clientId)
            self.clients[clientId] = nil
        end
    end

    return pool
end

return M


