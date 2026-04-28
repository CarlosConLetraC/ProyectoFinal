local Vector3 = ({...})[1]
local Table = Table or import("Table")
local Math = Math or import("Math")

local Math_round = Math.round
local Math_floor = Math.floor
local Math_ceil  = Math.ceil

local Table_clone = Table.clone

local typeof--[[, loadstring]], rawequal, error = typeof--[[, loadstring]], rawequal, error
local gmt, smt = debug.getmetatable or getmetatable, debug.setmetatable or setmetatable
local append = {}
local mt = {__metatable = "locked"--[[, __value = 0]], __subindex = {}, __type = "Vector3"}
local arithCallers = {}
--local arithSrcCaller = "return VALUEX, VALUEY, VALUEZ"

local string_gsub = string.gsub
local string_format = string.format

local operators = {XX={}, XY={}, YX={}}
operators.XX["+"] = function(a, b) return a.X+b.X, a.Y+b.Y, a.Z+b.Z end
operators.XX["-"] = function(a, b) return a.X-b.X, a.Y-b.Y, a.Z-b.Z end
operators.XX["/"] = function(a, b) return a.X/b.X, a.Y/b.Y, a.Z/b.Z end
operators.XX["*"] = function(a, b) return a.X*b.X, a.Y*b.Y, a.Z*b.Z end
operators.XX["^"] = function(a, b) return a.X^b.X, a.Y^b.Y, a.Z^b.Z end
operators.XX["%"] = function(a, b) return a.X%b.X, a.Y%b.Y, a.Z%b.Z end

operators.XY["+"] = function(a, b) return a.X+b, a.Y+b, a.Z+b end
operators.XY["-"] = function(a, b) return a.X-b, a.Y-b, a.Z-b end
operators.XY["/"] = function(a, b) return a.X/b, a.Y/b, a.Z/b end
operators.XY["*"] = function(a, b) return a.X*b, a.Y*b, a.Z*b end
operators.XY["^"] = function(a, b) return a.X^b, a.Y^b, a.Z^b end
operators.XY["%"] = function(a, b) return a.X%b, a.Y%b, a.Z%b end

operators.YX["+"] = function(a, b) return a+b.X, a+b.Y, a+b.Z end
operators.YX["-"] = function(a, b) return a-b.X, a-b.Y, a-b.Z end
operators.YX["/"] = function(a, b) return a/b.X, a/b.Y, a/b.Z end
operators.YX["*"] = function(a, b) return a*b.X, a*b.Y, a*b.Z end
operators.YX["^"] = function(a, b) return a^b.X, a^b.Y, a^b.Z end
operators.YX["%"] = function(a, b) return a%b.X, a%b.Y, a%b.Z end

arithCallers.modes = {
	-- vec3, vec3
	XX = function(operator, a, b)
		return operators.XX[operator](a, b)
	end,

	-- vec3, num
	XY = function(operator, a, b)
		return operators.XY[operator](a, b)
	end,

	-- num, vec3
	YX = function(operator, a, b)
		return operators.YX[operator](a, b)
	end
}

local function CHECK(statusValue, msg, ...)
	if not rawequal(statusValue, false) and not rawequal(statusValue, nil) then
		return statusValue
	end

	error(string_format(msg, ...), 4)
end

local function DoMode(xV3, yV3)
	local xIsV3     = (typeof(xV3) == "Vector3" and "X")
	local xIsNumber = (typeof(xV3) == "number"  and "Y")
	
	local yIsV3     = (typeof(yV3) == "Vector3" and "X")
	local yIsNumber = (typeof(yV3) == "number"  and "Y")
	
	CHECK(xIsV3 or xIsNumber, "Cannot convert typeof '%s' to Vector3.", typeof(xV3))
	CHECK(yIsV3 or yIsNumber, "Cannot convert typeof '%s' to Vector3.", typeof(yV3))
	
	return (xIsV3 or xIsNumber) .. (yIsV3 or yIsNumber)
end

function mt.__tostring(self)
	return string_format("%s(%.12g, %.12g, %.12g)", typeof(self), self.X, self.Y, self.Z)
end

function mt.__index(self, idx)
	local selfMT = gmt(self)
	return CHECK(selfMT and selfMT.__subindex[idx], "unknown attribute '%s'", idx)
end


function mt.__add(xV3, yV3)
	local fMode = DoMode(xV3, yV3)
	return Vector3.new(arithCallers.modes[fMode]("+", xV3, yV3))
end

function mt.__sub(xV3, yV3)
	local fMode = DoMode(xV3, yV3)
	return Vector3.new(arithCallers.modes[fMode]("-", xV3, yV3))
end

function mt.__mul(xV3, yV3)
	local fMode = DoMode(xV3, yV3)
	return Vector3.new(arithCallers.modes[fMode]("*", xV3, yV3))
end

function mt.__div(xV3, yV3)
	local fMode = DoMode(xV3, yV3)
	return Vector3.new(arithCallers.modes[fMode]("/", xV3, yV3))
end

function mt.__pow(xV3, yV3)
	local fMode = DoMode(xV3, yV3)
	return Vector3.new(arithCallers.modes[fMode]("^", xV3, yV3))
end

function mt.__unm(xV3)
	return Vector3.new(-xV3.X, -xV3.Y, -xV3.Z)
end

function mt.__mod(xV3, yV3)
	local fMode = DoMode(xV3, yV3)
	return Vector3.new(arithCallers.modes[fMode]("%", xV3, yV3))
end

function mt.__eq(xV3, yV3)
	return xV3.X == yV3.X and xV3.Y == yV3.Y and xV3.Z == yV3.Z
end

function mt.__subindex.round(self)
	self.X, self.Y, self.Z = Math_round(self.X), Math_round(self.Y), Math_round(self.Z)
	return self
end

function mt.__subindex.floor(self)
	self.X, self.Y, self.Z = Math_floor(self.X), Math_floor(self.Y), Math_floor(self.Z)
	return self
end

function mt.__subindex.ceil(self)
	self.X, self.Y, self.Z = Math_ceil(self.X), Math_ceil(self.Y), Math_ceil(self.Z)
	return self
end


function append.create(self)
	local newMT = Table_clone(mt, true)
	smt(self, newMT)
	
	return self
end

return append