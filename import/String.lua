local String = {}
local string_gsub = string.gsub

local function returntail(...) return ... end

function String.split(s0, s1)
	local tba = (Table and Table.apply) or returntail
	local t = {}
	local ct = ""
	local n = 0

	string_gsub(s0, ".", function(c)
		if c == s1 then
			n = n + 1
			t[n] = ct
			ct = ""
		elseif rawequal(s1, nil) then
			n = n + 1
			t[n] = ct .. c
		else
			ct = ct .. c
		end
	end)

	return tba(t)
end

function String.gsplit(s0, s1, upv, x)
	x = (type(x) == "number" and x) or tonumber(x or "") or tonumber(x or "", 16) or s0:len()
	x = math.floor(x)
	local tba = (Table and Table.apply) or returntail
	local t = {}
	local n = 0

	if type(upv) == "string" then
		string_gsub(s0, s1, function(...)
			local s2 = table.concat({...})
			n = n + 1
			t[n] = string_gsub(s2, s1, upv)
		end, x)
	end

	if type(upv) == "function" then
		string_gsub(s0, s1, function(s2)
			n = n + 1
			t[n] = upv(s2) or s2
		end, x)
	end

	if type(upv) == "table" then
		string_gsub(s0, s1, function(...)
			local s2 = table.concat({...})
			local lastN = n
			for gs, s3 in pairs(upv) do
				string_gsub(s2, gs, function(_)
					n = n + 1
					t[n] = assert(type(s3) == "string" and s3, ("invalid replacement value (a %s)"):format(type(s3)))
				end)
			end
			if lastN == n then
				n = n + 1
				t[n] = s2
			end
		end, x)
	end
	
	return tba(t)
end

local ffi = require("ffi")
ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen,
	      const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen,
	       const uint8_t *source, unsigned long sourceLen);
]]
local zlib = ffi.load((ffi.os == "Windows" and "zlib1") or "z")

function String.compress(txt)
	local n = zlib.compressBound(txt:len())
	local buf = ffi.new("uint8_t[?]", n)
	local buflen = ffi.new("unsigned long[1]", n)
	local res = zlib.compress2(buf, buflen, txt, txt:len(), 9)
	assert(res == 0)
	return ffi.string(buf, buflen[0])
end

function String.uncompress(comp, n)
	local buf = ffi.new("uint8_t[?]", n)
	local buflen = ffi.new("unsigned long[1]", n)
	local res = zlib.uncompress(buf, buflen, comp, comp:len())
	assert(res == 0)
	return ffi.string(buf, buflen[0])
end

return String
