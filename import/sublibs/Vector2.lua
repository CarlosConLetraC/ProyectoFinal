local Vector2 = ({...})[1]
--local effil = effil or import("effil")
local Table = Table or import("Table")
local Math = Math or import("Math")
--local typeof = typeof --or effil.G.typeof
local typeof--[[, loadstring]], rawequal, error = typeof--[[, loadstring]], rawequal, error
local gmt, smt = debug.getmetatable or getmetatable, debug.setmetatable or setmetatable
local append = {}
local mt = {__metatable = "locked"--[[, __value = 0]], __subindex = {}, __type = "Vector2"}
local arithCallers = {}
--local arithSrcCaller = "return VALUEX, VALUEY"

local operators = {XX={}, XY={}, YX={}}
operators.XX["+"] = function(a, b) return a.X+b.X, a.Y+b.Y end
operators.XX["-"] = function(a, b) return a.X-b.X, a.Y-b.Y end
operators.XX["/"] = function(a, b) return a.X/b.X, a.Y/b.Y end
operators.XX["*"] = function(a, b) return a.X*b.X, a.Y*b.Y end
operators.XX["^"] = function(a, b) return a.X^b.X, a.Y^b.Y end
operators.XX["%"] = function(a, b) return a.X%b.X, a.Y%b.Y end

operators.XY["+"] = function(a, b) return a.X+b, a.Y+b end
operators.XY["-"] = function(a, b) return a.X-b, a.Y-b end
operators.XY["/"] = function(a, b) return a.X/b, a.Y/b end
operators.XY["*"] = function(a, b) return a.X*b, a.Y*b end
operators.XY["^"] = function(a, b) return a.X^b, a.Y^b end
operators.XY["%"] = function(a, b) return a.X%b, a.Y%b end

operators.YX["+"] = function(a, b) return a+b.X, a+b.Y end
operators.YX["-"] = function(a, b) return a-b.X, a-b.Y end
operators.YX["/"] = function(a, b) return a/b.X, a/b.Y end
operators.YX["*"] = function(a, b) return a*b.X, a*b.Y end
operators.YX["^"] = function(a, b) return a^b.X, a^b.Y end
operators.YX["%"] = function(a, b) return a%b.X, a%b.Y end


arithCallers.modes = {
	-- vec2, vec2
	XX = function(operator, a, b)
		--local fsrc = arithSrcCaller:gsub("%w+", {VALUEX = "a.X"..operator.."b.X", VALUEY = "a.Y"..operator.."b.Y"})
		--local fn = loadstring(fsrc)
		--setfenv(fn, {a=a, b=b})
		--return fn()
		return operators.XX[operator](a, b)
	end,

	-- vec2, num
	XY = function(operator, a, b)
		--local fsrc = arithSrcCaller:gsub("%w+", {VALUEX = "a.X"..operator.."b", VALUEY = "a.Y"..operator.."b"})
		--local fn = loadstring(fsrc)
		--setfenv(fn, {a=a, b=b})
		--return fn()
		return operators.XY[operator](a, b)
	end,

	-- num, vec2
	YX = function(operator, a, b)
		--local fsrc = arithSrcCaller:gsub("%w+", {VALUEX = "a"..operator.."b.X", VALUEY = "a"..operator.."b.Y"})
		--local fn = loadstring(fsrc)
		--setfenv(fn, {a=a, b=b})
		--return fn()
		return operators.YX[operator](a, b)
	end
}

local function CHECK(statusValue, msg, ...)
	if not rawequal(statusValue, false) and not rawequal(statusValue, nil) then
		return statusValue
	end

	error(msg:format(...), 4)
end

local function DoMode(xV2, yV2)
	local xIsV2     = (typeof(xV2) == "Vector2" and "X")
	local xIsNumber = (typeof(xV2) == "number"  and "Y")
	
	local yIsV2     = (typeof(yV2) == "Vector2" and "X")
	local yIsNumber = (typeof(yV2) == "number"  and "Y")
	
	CHECK(xIsV2 or xIsNumber, "Cannot convert typeof '%s' to number/LuaNumber/Vector2.", typeof(statusValue))
	CHECK(yIsV2 or yIsNumber, "Cannot convert typeof '%s' to number/LuaNumber/Vector2.", typeof(statusValue))
	
	return (xIsV2 or xIsNumber) .. (yIsV2 or yIsNumber)
end


function mt.__tostring(self)
	return ("%s(%.12g, %.12g)"):format(typeof(self), self.X, self.Y)
end

function mt.__index(self, idx)
	local selfMT = gmt(self)
	return CHECK(selfMT and selfMT.__subindex[idx], "unknown attribute '%s'", idx)
end


function mt.__add(xV2, yV2)
	local fMode = DoMode(xV2, yV2)
	return Vector2.new(arithCallers.modes[fMode]("+", xV2, yV2))
end

function mt.__sub(xV2, yV2)
	local fMode = DoMode(xV2, yV2)
	return Vector2.new(arithCallers.modes[fMode]("-", xV2, yV2))
end

function mt.__mul(xV2, yV2)
	local fMode = DoMode(xV2, yV2)
	return Vector2.new(arithCallers.modes[fMode]("*", xV2, yV2))
end

function mt.__div(xV2, yV2)
	local fMode = DoMode(xV2, yV2)
	return Vector2.new(arithCallers.modes[fMode]("/", xV2, yV2))
end

function mt.__pow(xV2, yV2)
	local fMode = DoMode(xV2, yV2)
	return Vector2.new(arithCallers.modes[fMode]("^", xV2, yV2))
end

function mt.__unm(xV2)
	return Vector2.new(-xV2.X, -xV2.Y)
end

function mt.__eq(xV2, yV2)
	return xV2.X == yV2.X and xV2.Y == yV2.Y
end


function mt.__subindex.round(self)
	self.X, self.Y = Math.round(self.X), Math.round(self.Y)
	return self
end

function mt.__subindex.floor(self)
	self.X, self.Y = Math.floor(self.X), Math.floor(self.Y)
	return self
end

function mt.__subindex.ceil(self)
	self.X, self.Y = Math.ceil(self.X), Math.ceil(self.Y)
	return self
end


function append.create(self)
	local newMT = Table.clone(mt, true)
	smt(self, newMT)
	
	return self
end

return append
