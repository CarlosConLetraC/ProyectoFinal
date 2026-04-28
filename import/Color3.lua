--[[local HUE = {
	red = {0,60},
	yellow = {60,120},
	green = {120,180},
	cyan = {180,240},
	blue = {240,300},
	magenta = {300,360}
}]]
local Color3 = {}
local methods = {}
local EasingModes = EasingModes or import("EasingModes")
local Enum = Enum or import("Enum")
local Math = Math or import("Math")
local system = system or import("system")
local append = loadfile("import/sublibs/Color3.lua")(Color3, ...)

local Math_clamp = Math.clamp
local Math_round = Math.round
local Math_lerp = Math.lerp
local Math_abs = Math.abs

local string_format = string.format
local string_gsub = string.gsub
local string_sub = string.sub
local string_len = string.len
local string_rep = string.rep

function methods.unpack(self)
	return self.R, self.G, self.B
end

function methods.toHEX(self)
	local R = Math_round(self.R*255)
	local G = Math_round(self.G*255)
	local B = Math_round(self.B*255)

	return string_format("%.2X%.2X%.2X", R, G, B)--:format(R, G, B)
end

function Color3.fromHEX(hex)
	if string_len(hex) % 2 == 1 and string_len(hex) > 1 and string_len(hex) < 6 then
		local c = string_sub(hex, string_len(hex))
		hex = string_sub(hex, 1, string_len(hex)-1) .. "0" .. c
		hex = hex .. string_rep("0", 6-string_len(hex))

	elseif string_len(hex) % 2 == 0 and string_len(hex) > 1 and string_len(hex) < 6 then
		hex = hex .. string_rep("0", 6-string_len(hex))

	elseif string_len(hex) > 6 then
		hex = string_sub(hex, 1, 6)

	elseif string_len(hex) ~= 6 then
		hex = "0" .. hex
		hex = hex .. string_rep("0", 6-string_len(hex))

	end

	local rgb = {}
	string_gsub(hex, "..", function(s)
		rgb[system.rawlen(rgb)+1] = tonumber(s, 16)
	end)

	return Color3.fromRGB(system.unpack(rgb))
end

function methods.lerp(self, c1, t)
	return Color3.new(
		Math_lerp(self.R, c1.R, t),
		Math_lerp(self.G, c1.G, t),
		Math_lerp(self.B, c1.B, t)
	)
end

function methods.interpolate(self, c1, t, style, ease)
	ease = ease or Enum.EaseMode.InOut
	style = style or Enum.StyleMode.Sine

	return methods.lerp(self, c1, EasingModes[style][ease](t))
end

function Color3.new(r, g, b)
	local newColor3 = {
		R = (type(r) == "number" and r) or tonumber(r or "") or tonumber(r or "", 16) or 0,
		G = (type(g) == "number" and g) or tonumber(g or "") or tonumber(g or "", 16) or 0,
		B = (type(b) == "number" and b) or tonumber(b or "") or tonumber(b or "", 16) or 0
	}
	newColor3.R = Math_clamp(newColor3.R, 0, 1)
	newColor3.G = Math_clamp(newColor3.G, 0, 1)
	newColor3.B = Math_clamp(newColor3.B, 0, 1)

	for k, v in pairs(methods) do
		newColor3[k] = v
	end

	return append.create(newColor3)
end

function Color3.fromRGB(r, g, b)
	return Color3.new(r/255, g/255, b/255)
end

local hsv = {
	[0] = function(C, X)
		return Color3.new(C, X, 0)
	end,
	[1] = function(C, X)
		return Color3.new(X, C, 0)
	end,
	[2] = function(C, X)
		return Color3.new(0, C, X)
	end,
	[3] = function(C, X)
		return Color3.new(0, X, C)
	end,
	[4] = function(C, X)
		return Color3.new(X, 0, C)
	end
}
function hsv.default(C, X)
	return Color3.new(C, 0, X)
end

function Color3.fromHSV(h, s, v)
	s = (type(s) == "number" and s) or 1
	v = (type(v) == "number" and v) or 1

	h = Math_clamp(h, 0, 180)/180
	s = Math_clamp(s, 0, 1)
	v = Math_clamp(v, 0, 1)
	
	if s == 0 then
		return Color3.new(v, v, v)
	end

	local k = h*6
	local d = k - (k%1)
	
	local C = v * s
	local X = C * (1 - Math_abs((k%2) - 1))
	local m = v - C
	
	local appender = hsv[d] or hsv.default
	local rgb = appender(C, X)
	rgb.R = rgb.R + m
	rgb.G = rgb.G + m
	rgb.B = rgb.B + m

	return rgb
end

return Color3
