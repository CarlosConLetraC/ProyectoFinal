local g = getfenv and getfenv() or _ENV or _G
g._PROMPT = ">>> "
g._PROMPT2 = "... "

if jit and jit.os ~= "Windows" or os.getenv("HOME") then
	g.os_version = "Linux"
	package.path = package.path .. ";./import/?.lua"
	package.cpath = package.cpath .. ";./import/Linux/?.so"
	
	package.path = package.path .. ";/usr/share/lua/".. string.sub(_VERSION, 5) .."/?.lua"
	package.path = package.path .. ";/usr/local/share/lua/".. string.sub(_VERSION, 5) .."/?.lua"	
elseif not os.getenv("HOME") then
	g.os_version = "Windows"
	package.path = package.path .. ";.\\import\\?.lua"
	package.cpath = package.cpath .. ";.\\import\\Windows\\?.dll"
end

local gmt = debug.getmetatable or getmetatable
local assert, rawget, rawequal, require, type, select, unpack, module, print, package, string, math, os, io, debug, load, loadstring, pairs, ipairs, next, _G, collectgarbage, pcall, xpcall, getfenv, setfenv =
	  assert, rawget, rawequal, require, type, select, unpack or table.unpack, module, print, package, string, math, os, io, debug, load, loadstring, pairs, ipairs, next, _G, collectgarbage, pcall, xpcall, getfenv, setfenv

local string_sub = string.sub
local string_len = string.len
local string_format = string.format
local package_loaded = (package and package.loaded) or {}
local io_write = io.write or print

local coroutine_wrap = coroutine.wrap
local coroutine_yield = coroutine.yield

clear = _VERSION ~= "Luau" and function() os.execute("clear") end or function() io_write("\27[3J\27c\27[0;0f") end
import = function(...)
	local t = {n = select("#", ...), ...}
	local loaded = {}

	for i = 1, t.n, 1 do
		local what = t[i]
		assert(what ~= "init", "reserved file for lua-env.")
		
		if package_loaded[what] then
			loaded[i] = package_loaded[what]
		else
			local preload = require(what)
			loaded[i] = preload
			package_loaded[what] = preload
			g[what] = preload
		end
	end

	return unpack(loaded, 1, t.n)
end
import_as=function(moduleName, nameAs)
	g[nameAs] = package_loaded[moduleName] or require(moduleName)
end

typeof = function(self)
	local mt = gmt(self)
	
	if not rawequal(mt, nil) then
		local tp = rawget(mt, "__type") or rawget(mt, "type")
		return (type(tp) == "string" and tp) or (type(tp) == "function" and tp(self)) or type(self)
	end

	return type(self)
end

local function ln(self)
	local mt = gmt(self)
	if not mt then return #self end
	
	local aux = mt.__len
	mt.__len = nil
	local n = #self
	mt.__len = aux

	return n
end

rawlen = rawlen or function(v)
	return (type(v) == "string" and string_len(v)) or type(v) == "table" and ln(v)--select("#", unpack(v))
end

local BLUND_ERROR_COLOR_FORMAT = "\27[1;1;31m%s\27[m"
local blundTypes = {}
local mtINDEX = {}

blundTypes[true] = function(value, _, _)
	return value
end
blundTypes[false] = function(value, msg, errorCode)
	local s = string_format("[asserted by %s value]: %s", tostring(value), msg)
	return error(string_format(BLUND_ERROR_COLOR_FORMAT, s), errorCode)
end

mtINDEX["number"] = blundTypes[true]
mtINDEX["string"] = blundTypes[true]
mtINDEX["function"] = blundTypes[true]
mtINDEX["table"] = blundTypes[true]
mtINDEX["userdata"] = blundTypes[true]
mtINDEX["thread"] = blundTypes[true]
mtINDEX["nil"] = blundTypes[false]

setmetatable(blundTypes, {
	__index = setmetatable(mtINDEX, mtINDEX)
})
blund = function(value, msg, errorCode)
	return (blundTypes[type(value)] or blundTypes[value])(value, msg, errorCode or 2)
end

span = function(stop, increment, start)
	stop = blund((type(stop) == "number" and stop) or tonumber(stop) or tonumber(stop or "", 16), string_format("invalid argument #1 for 'fori' (number expected, got %s)", type(stop)))
	increment = blund((type(increment) == "number" and increment) or tonumber(increment) or tonumber(increment or "", 16) or (increment == nil and 1), string_format("invalid argument #2 for 'fori' (number expected, got %s)", type(increment)))
	start = blund((type(start) == "number" and start) or tonumber(start) or tonumber(start or "", 16) or (start == nil and 1), string_format("invalid argument #3 for 'fori' (number expected, got %s)", type(start)))

	return coroutine_wrap(function()
		for j = start, stop, increment do
			coroutine_yield(j)
		end
	end)
end

local validReplace = {
	["print"] = function()
		g._print, g.print = g._print or print, (system or import("system")).print
	end
}
replace = function(...)
	for _, v in pairs({...}) do
		blund(validReplace[v], "cannot modify "..tostring(v).." (not defined or protected).")()
	end
end
local arg = arg or {[0]=..., ...}
local interactive = arg[0] == "--exec" and arg[1]

if interactive then
	local f = import("File").new("--exec", "w")
	f:clear()
	f:write(interactive)
	f:save()
end

return import
--import("Math", "Table", "system")
--g.print, g._print = system.print, print
--[[
OK: (a*c)/(b*d)
NO: (a/b)*(c/d)

pero... matematicamente son lo mismo.
]]
