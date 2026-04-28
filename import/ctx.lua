local Table = Table or import("Table")
local Table_clone = Table.clone

local ctx = {}
local ctxMT = {__index = {}}

function ctxMT.__index:connect()
end

function ctx.new()
    local newCTX = {}
    local newCTXMT = Table_clone(ctxMT)
    newCTXMT.__index = Table_clone(newCTXMT.__index)

    return setmetatable(newCTX, newCTXMT)
end


return ctx