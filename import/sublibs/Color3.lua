local Color3 = ({...})[1]
local effil = effil or import("effil")
local Table = Table or import("Table")
local typeof = typeof or effil.G.typeof
local gmt, smt = debug.getmetatable or getmetatable, debug.setmetatable or setmetatable
local append = {}
local mt = {__metatable = "locked", __value = 0, __subindex = {}, __type = "Color3"}
local arithCallers = {}
--local arithSrcCaller = "return VALUEX, VALUEY, VALUEZ"

function mt.__tostring(self)
	return ("%s(%.12g, %.12g, %.12g)"):format(typeof(self), self.R, self.G, self.B)
end

function mt.__eq(self, color)
	return typeof(self) == typeof(color) and (self.R == color.R and self.G == color.G and self.B == color.B)
end

function append.create(self)
	local newMT = Table.clone(mt, true)
	smt(self, newMT)
	
	return self
end

return append