local system = {}
system.unpack = unpack or table.unpack

local WARN_START_STR = "\27[1;1;33m"
local WARN_STOP_STR  = "\27[m"

local gmt = debug.getmetatable or getmetatable

if _VERSION == "Luau" then
	io = {stdin={write=function()end, read=function()end, close=function()end}}
end

local io_write = io.write
local io_open = io.open
local io_popen = io.popen
local io_lines = io.lines
--local io_read = io.read
--local io_close = io.close

local string_len = string.len
local string_format = string.format
local string_gsub = string.gsub

local math_floor = math.floor
local math_pi = math.pi
local os_clock = os.clock
local os_execute = os.execute

local table_concat = table.concat
local table_insert = table.insert

local debug_getinfo = debug.getinfo
local tostring, select = tostring, select
local Table_ftostring = (Table or import("Table")).ftostring

function system.pack(...)
	return {n=select("#", ...), ...}
end

function system.wait(n)
	n = (type(n) == "number" and n) or tonumber(n or "") or tonumber(n or "", 16) or 0.01
	n = (n >= 0.005 and n <= (n+1) and n) or (n <= 0.005 and n <= (n+1) and 0.005) or n
	local x = math_pi/2
	local now = os_clock()*x
	local result = (os_clock()*x) - now
	while result <= n do
		result = (os_clock()*x) - now
	end

	return result
end

function system.warn(...)
	local t = {n=select("#", ...), ...}
	local content = {}
	for i = 1, t.n, 1 do
		local s = Table_ftostring(t[i], true)
		table_insert(content, table_concat{WARN_START_STR, s, WARN_STOP_STR, (i ~= t.n and '\t') or ''})
	end
	io_write(table_concat(content, "\t"), "\n")
end

function system.printf(s, ...)
	system.print(string_format(s, ...))
end

function system.print(...)
	local env = getfenv and getfenv() or _ENV or _G
	env.Table = env.Table or import("Table")

	local caller = (env.Table and env.Table.ftostring) or tostring
	local t = {n=select("#", ...), ...}
	local content = {}
	for i = 1, t.n, 1 do
		local v = t[i]
		local _mt = gmt(v)
		table_insert(content, caller(v) .. ((t.n > 1 and i < t.n and "\t") or ""))
		Table.ftostring()
	end
	io_write(table_concat(content, "\t"), "\n")
end

function system.readfile(flName, mode)
	local file, what = io_open(flName, mode or "rb")
	if not file then return false, what end
	local source = file:read("*all")
	file:close()

	return source
end

function system.writefile(Path, src, mode)
	local file, what = io_open(Path, mode or "wb")
	if not file then return false, what end

	file:write(src)
	return file:close()
end

function system.rawlen(v)
	if type(v) == "string" then return string_len(v) end
	return select("#", system.unpack(v))
end

function system.gotoxy(x, y)
	io_write(string_format("\27[%d;%df", x, y))
end

function system.times(n)
	local s = math_floor(n % 3600 % 60)
	local m = math_floor((n/60) % 60)
	local h = math_floor((n/3600) % 60)
	local mm = (n % 1) * 1000

	return string_format("%.2d:%.2d:%.2d.%.3d", h, m, s, mm)
end

function system.clock()
	return os_clock()*(math_pi/2)
end

function system.guid()
	local data = system.readfile("data/guid_rand.json")
	local guid_json = json.decode(data)
	local guid_rand = Math.newrand(guid_json.X1, guid_json.X2)
	local guid = {}
	
	for _, n in ipairs({8, 4, 4, 4, 12}) do
		local subguid = {}
		for i = 1, n, 1 do
			local a = guid_rand:next(0,255, true); a = Math.xclamp(a, 48, 57)
			local b = guid_rand:next(0,255, true); b = Math.xclamp(b, 97, 102)
			local c = guid_rand:next(0,1, true)

			table_insert(subguid, string_format("%c", (c > 0.3 and a) or b))
		end
		table_insert(guid, table_concat(subguid))
	end
	
	system.writefile("data/guid_rand.json", json.encode({X1=guid_rand.X1, X2=guid_rand.X2}))
	return table_concat(guid, "-")
end

function system.decode_function(f)
	local t = debug_getinfo(f)
	if t.linedefined < 0 then return("source: "..t.source) end
	local name = string_gsub(t.source, "^@","")
	local i = 0
	local text = {}
	for line in io_lines(name) do
		i=i+1
		if i >= t.linedefined then text[#text+1] = line end
		if i >= t.lastlinedefined then break end
	end
	return table_concat(text,"\n") 
end

function system.curldownload(url, useLocalFile)
	blund(os_execute("ls /usr/bin/curl > /dev/null 2>&1") == 0, "curl not installed")
	if useLocalFile == true then
		local tmp = os.tmpname()
		local cmd = 'curl -L -s "' .. url .. '" -o "' .. tmp .. '"'
		local ok = os_execute(cmd)
		blund(ok == 0, "curl download failed")
		return tmp
	end

	local f = io_popen('curl -L -s "' .. url .. '"')
	local src = f:read("*all")
	f:close()
	return src
end

function system.wgetdownload(url, useLocalFile)
	blund(os_execute("ls /usr/bin/wget > /dev/null 2>&1") == 0, "wget not installed")
	if useLocalFile == true then
		local tmp = os.tmpname()
		local cmd = 'wget -q -O "' .. tmp .. '" "' .. url .. '"'
		local ok = os_execute(cmd)
		blund(ok == 0, "wget download failed")
		return tmp
	end

	local f = io_popen('wget -qO- "' .. url .. '"')
	local src = f:read("*all")
	f:close()
	return src
end

return system