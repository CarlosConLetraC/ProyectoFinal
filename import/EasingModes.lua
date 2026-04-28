local EasingModes = {}

local Enum = Enum or import("Enum")
local EasingModes = {}

local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi

EasingModes[Enum.StyleMode.Bounce] = {
	[Enum.EaseMode.Out] = function(t)
		local n1, d1 = 121/16, 11/4
		if t < 1 / d1 then
			return n1 * t * t
		elseif t < 2 / d1 then
			t = t + (-3/2) / d1
			return n1 * t * t + 3/4
		elseif t < (5/2) / d1 then
			t = t + (-9/4) / d1
			return n1 * t * t + 15/16
		else
			t = t + (-21/8) / d1
			return n1 * t * t + 63/64
		end
	end,

	[Enum.EaseMode.In] = function(t)
		local out = EasingModes[Enum.StyleMode.Bounce][Enum.EaseMode.Out]
		return 1 - out(1 - t)
	end,

	[Enum.EaseMode.InOut] = function(t)
		local out = EasingModes[Enum.StyleMode.Bounce][Enum.EaseMode.Out]
		local inv = EasingModes[Enum.StyleMode.Bounce][Enum.EaseMode.In]
		return t < 0.5 and inv(t * 2) * 0.5 or out(t * 2 - 1) * 0.5 + 0.5
		--if t < 0.5 then
		--	return inv(t * 2) * 0.5
		--else
		--	return out(t * 2 - 1) * 0.5 + 0.5
		--end
	end,
}

EasingModes[Enum.StyleMode.Cubic] = {
	[Enum.EaseMode.In] = function(t)
		return t*t*t
	end,
	[Enum.EaseMode.Out] = function(t)
		local d = t - 1
		return d*d*d + 1
		--return (t - 1)^3 + 1
	end,
	[Enum.EaseMode.InOut] = function(t)
		local nt = 2 * t - 2
		return t < 0.5 and 4 * t*t*t or 0.5 * nt*nt*nt + 1
		--if t < 0.5 then
		--	return 4 * t^3
		--else
		--	local nt = 2 * t - 2
		--	return 0.5 * nt^3 + 1
		--end
	end,
}

EasingModes[Enum.StyleMode.Exponential] = {
	[Enum.EaseMode.In] = function(t)
		return (t == 0) and 0 or 2^(10 * (t - 1))
	end,
	[Enum.EaseMode.Out] = function(t)
		return (t == 1) and 1 or 1 - 2^(-10 * t)
	end,
	[Enum.EaseMode.InOut] = function(t)
		if t == 0 then return 0 end
		if t == 1 then return 1 end
		if t < 0.5 then
			return 2^(20 * t - 10) / 2
		else
			return (2 - 2^(-20 * t + 10)) / 2
		end
	end,
}

EasingModes[Enum.StyleMode.Quad] = {
	[Enum.EaseMode.In] = function(t)
		return t * t
	end,
	[Enum.EaseMode.Out] = function(t)
		return t * (2 - t)
	end,
	[Enum.EaseMode.InOut] = function(t)
		return t < 1/2 and 2 * t * t or -1 + (4 - 2 * t) * t
	end
}

EasingModes[Enum.StyleMode.Sine] = {
	[Enum.EaseMode.In] = function(t)
		return 1 - math_cos((t * math_pi) / 2)
	end,
	[Enum.EaseMode.Out] = function(t)
		return math_sin((t * math_pi) / 2)
	end,
	[Enum.EaseMode.InOut] = function(t)
		return -(math_cos(math_pi * t) - 1) / 2
	end,
}

return EasingModes