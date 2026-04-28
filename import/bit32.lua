-- EN CASO QUE `bit` O `bit32` NO ESTEN DEFINIDOS; IMPORTA ESTO. SINO, NO LO SOBREESCRIBAS A MENOS QUE NECESITES ALGO DE ACA.
local bit = bit32 or bit or {}
local ALLONES = 0xFFFFFFFF
local MOD = 0x80000000--2^32

local math_floor = math.floor

local table_concat = table.concat

local string_len = string.len
local string_rep = string.rep
local string_sub = string.sub
local string_gsub = string.gsub
local string_byte = string.byte
local string_format = string.format
local string_reverse = string.reverse

local select, tonumber, type, pairs, unpack = select, tonumber, type, pairs, unpack or table.unpack
--local type, unpack = type, unpack or table.unpack
local pairs, select, rawlen = pairs, select, rawlen or function(v)
	if type(v) == "string" then return string_len(v) end
	return select("#", unpack(v))
end

--[=================================]
--[====[ ::BIT PRE-FUNCTIONS:: ]====]
--[=================================]

--[[local function b_and(x, y)
	local e = 1
	local n = 0
	while x > 0 and y > 0 do
		local a = x % 2
		local b = y % 2
		if a + b > 1 then
			n = n + e
		end
		x, y = (x - a) / 2, (y - b) / 2
		e = e * 2
	end
	return n - (n % 1)		
end]]
local function b_and(x, y)
	local result = 0
	local shift = 0
	while x > 0 or y > 0 do
		if (x % 2) == 1 and (y % 2) == 1 then
			result = result + 2^shift
		end
		x, y = math_floor(x / 2), math_floor(y / 2)
		shift = shift + 1
	end
	return result
end

local function b_or(x, y)
	local result = 0
	local shift = 0
	while x > 0 or y > 0 do
		if (x % 2) == 1 or (y % 2) == 1 then
			result = result + 2^shift
		end
		x, y = math_floor(x / 2), math_floor(y / 2)
		shift = shift + 1
	end
	return result
end
  
local function b_xor(x, y)
	local result = 0
	local shift = 0
	while x > 0 or y > 0 do
		if (x % 2) ~= (y % 2) then
			result = result + 2^shift
		end
		x, y = math_floor(x / 2), math_floor(y / 2)
		shift = shift + 1
	end
	return result
end

--[[local function b_or(num1, num2)
	local p, c = 1, 0
	while num1 + num2 > 0 do
		local ra, rb = num1 % 2, num2 % 2
		if ra + rb > 0 then
			c = c + p
		end
		num1, num2, p = (num1 - ra) / 2, (num2 - rb) / 2, p * 2
	end
	return math_floor(c - (c%1))
end

local function b_xor(num1, num2)
	local p, c = 1, 0
	while num1 > 0 and num2 > 0 do
		local ra,rb = num1%2, num2%2
		if ra~=rb then
			c = c + p
		end
		num1, num2, p = (num1 - ra) / 2, (num2 - rb) / 2, p * 2
	end
	if num1 < num2 then
		num1 = num2
	end
	while num1 > 0 do
		local ra = num1 % 2
		if ra > 0 then
			c = c + p
		end
		num1, p = (num1 - ra) / 2, p * 2
	end
	return math_floor(c - (c%1))
end]]

--[=================================]
--[=======[ ::BIT LIBRARY:: ]=======]
--[=================================]

bit.blshift = bit.blshift or bit.lshift or function(a, b) -- Left Shift (<<)
	local n = a*(2^b)
	return math_floor(n - (n%1))
end

bit.brshift = bit.brshift or bit.rshift or function(a, b) -- Right Shift (>>)
	local n = a/(2^b)
	return math_floor(n - (n%1))
end

bit.lshift = bit.lshift or bit.blshift
bit.rshift = bit.rshift or bit.brshift

bit.arshift = bit.arshift or function(n, shift)
	local sign = bit.band(n, MOD)
	n = bit.brshift(n, shift)
	if sign ~= 0 then
		n = bit.bor(n, bit.bnot(bit.brshift(ALLONES, shift)))
	end
	return bit.band(n, ALLONES)
end

bit.band = bit.band or function(...)
	local r = select(1, ...)
	for i = 2, select("#", ...), 1 do
		r = b_and(r, select(i, ...))
	end
	return r
end

bit.bor = bit.bor or function(...) -- Bitwise OR (|)
	local r = select(1, ...)
	for i = 2, select("#", ...) do
		r = b_or(r, select(i, ...))
	end
	return b_and(r, ALLONES)--r
end

bit.bxor = bit.bxor or function(...) -- Bitwise XOR (n1~n2)
	local r = 0
	for i = 1, select("#", ...) do
		r = b_xor(r, select(i, ...))
	end
	return b_and(r, ALLONES)
end

bit.bnot = bit.bnot or function(n) -- Bitwise NOT (~n)
	return (-1 - n) % MOD
end

bit.lrotate = bit.lrotate or bit.rol or function(u, s)
	local n1 = bit.band(s, 31)
	local n2 = bit.blshift(u, n1)
	local n3 = bit.band(32 - s, 31)
	local n4 = bit.brshift(u, n3)

	return bit.bor(n2, n4)
end

bit.rrotate = bit.rrotate or bit.ror or function(u, s)
	local n1 = bit.band(s, 31)
	local n2 = bit.brshift(u, n1)
	local n3 = bit.band(32 - s, 31)
	local n4 = bit.blshift(u, n3)

	return bit.bor(n2, n4)
end

bit.extract = bit.extract or function(n, f, w)
	w = w or 1
	local m = math_floor(2^w - 1)
	local n1 = bit.brshift(n, f)
	local n2 = bit.band(n1, m)
	
	return bit.band(n2, ALLONES)
end

bit.byteswap = bit.byteswap or function(x)
	local a = bit.band(x, 0xff); x = bit.rshift(x, 8)
	local b = bit.band(x, 0xff); x = bit.rshift(x, 8)
	local c = bit.band(x, 0xff); x = bit.rshift(x, 8)
	local d = bit.band(x, 0xff)
	return bit.blshift(bit.blshift(bit.blshift(a, 8) + b, 8) + c, 8) + d
end

bit.replace = bit.replace or function(n, v, field, width)
	width = width or 1
	local mask = bit.bnot(math_floor(2^(width + field)) - math_floor(2^field))
	return bit.band(bit.bor(bit.band(n, mask), bit.band(bit.blshift(v, field), bit.bnot(mask))), ALLONES)
end

bit.btest = bit.btest or function(...)
	return bit.band(...) ~= 0
end  

bit.countrz = bit.countrz or function(n)
	if n == 0 then return 32 end
	local offset = 0
	while bit.extract(n, offset) == 0 do
		offset = offset + 1
	end
	return offset
end

bit.countlz = bit.countlz or function(n)
	if n == 0 then return 32 end
	local offset = 0
	while bit.extract(n, 31-offset) == 0 do
		offset = offset + 1
	end
	return offset
end

bit.bin = bit.bin or function(s)
	local packed = {}
	for j = 1, string_len(s), 1 do
		packed[j] = string_byte(string_sub(s, j, j))
	end

	local bins = {}
	for i = 1, string_len(s), 1 do
		local n = packed[i]
		local result = {}
		while n > 0 do
			result[rawlen(result) + 1] = (n % 2 == 0 and "0") or "1"
			n = math_floor(n / 2)
		end
		local s = table_concat(result)
		s = s .. string_rep("0", 8-string_len(s))
		bins[rawlen(bins)+1] = string_reverse(s)
	end

	return unpack(bins)
end

bit.unbin = bit.unbin or function(...)
	local packed = {...}
	local strs = {}
	for i = 1, select("#", ...), 1 do
		local s = packed[i]
		s = string_rep("0", 8-string_len(s)) .. s
		local byte = 0
		local pow = 7
		string_gsub(s, ".", function(c)
			c = tonumber(c)
			byte = byte + (c * 2^pow)
			pow = pow - 1
		end)
		strs[rawlen(strs)+1] = string_format("%c", byte)
	end

	return unpack(strs)
end

bit.nbin = bit.nbin or function(...)
	local packed = {...}
	local nbins = {}

	for i, n in pairs(packed) do
		local result = {}
		local j = 0

		while n > 0 do
			j = j + 1
			result[rawlen(result) + 1] = (n % 2 == 0 and "0") or "1"
			n = math_floor(n / 2)

			--if j % 8 == 0 and n > 0 then
			--	result[rawlen(result) + 1] = "\32"
			--end
		end
		local s = table_concat(result)
		s = string_gsub(s .. string_rep("0", 8-string_len(s)), "(%w+)", function(sb)
			return sb .. string_rep("0", 8-string_len(sb))
		end)

		nbins[rawlen(nbins)+1] = string_reverse(s)
	end

	return unpack(nbins)
end

--[[
local a = bit.band(x, 0xff); x = bit.rshift(x, 8)
local b = bit.band(x, 0xff); x = bit.rshift(x, 8)
local c = bit.band(x, 0xff); x = bit.rshift(x, 8)
local d = bit.band(x, 0xff)

local bl1 = bit.blshift(a, 8)
local bl2 = bit.blshift(bl1 + b, 8)
local bl3 = bit.blshift(bl2 + c, 8) + d

local bl1 = (a << 8)
local bl2 = ((bl1 + b) << 8)
local bl3 = ((bl2 + c) << 8) + d

function byteswap(x)
	local a = (x & 0xff); x = (x >> 8);
	local b = (x & 0xff); x = (x >> 8);
	local c = (x & 0xff); x = (x >> 8);
	local d = (x & 0xff)

	local bl1 = (a << 8)
	local bl2 = ((bl1 + b) << 8)
	local bl3 = ((bl2 + c) << 8) + d

	return bl3
end
]]

return bit
