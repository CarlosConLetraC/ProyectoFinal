local Vector2 = {}
local methods = {}
local Table = Table or import("Table")
local append = loadfile("import/sublibs/Vector2.lua")(Vector2, ...)

function methods.dot(vecx, vecy)
	local X, Y = (vecx.X + vecy.X) / 2, (vecx.Y + vecy.Y) / 2
	return Vector2.new(-X, -Y)
end

function methods.len(vec)
	return (vec.X*vec.X + vec.Y*vec.Y)^0.5
end

function methods.squarelen(vec)
	return vec.X*vec.X + vec.Y*vec.Y
end

function methods.cross(vecx, vecy)
	return vecx.X*vecy.Y - vecx.Y*vecy.X
end

--function methods.lerp(vecx, vecy, t)
--	local dot = -methods.dot(vecx, vecy)
--	t = t*2
--	return Vector2.new(dot.X * t, dot.Y * t)
--end

function methods.lerp(vecx, vecy, t)
	local x = vecx.X + (vecy.X - vecx.X) * t--lerp(vecx.X, vecy.X, t)
	local y = vecx.Y + (vecy.Y - vecx.Y) * t--lerp(vecx.Y, vecy.Y, t)
	return Vector2.new(x, y)
end

function methods.magnitude(vecx, vecy)
	return math.sqrt(math.pow((vecy.X - vecx.X), 2) + math.pow((vecy.Y - vecx.Y), 2))
end

function methods.unpack(self)
	return self.X, self.Y
end

-- pendiente de una recta(x,y)
function methods.slope(vecx, vecy)
	return (vecy.Y - vecx.Y) / (vecy.X - vecx.X)
end

function Vector2.new(x, y)
	local newVector2 = {
		X = (type(x) == "number" and x) or tonumber(x or "") or tonumber(x or "", 16) or 0,
		Y = (type(y) == "number" and y) or tonumber(y or "") or tonumber(y or "", 16) or 0
	}

	for k, v in pairs(methods) do
		newVector2[k] = v
	end

	return append.create(newVector2)
end

setmetatable(Vector2, {
	__metatable = "locked",
	__index = {
		methods = Table.clone(methods, true),
		zero = Vector2.new(0,0),
		one = Vector2.new(1,1),
		xAxis = Vector2.new(1,0),
		yAxis = Vector2.new(0,1)
	},
	__newindex = function(self, idx, what)
		error(("Attempt to modify read-only table (%s=%s?)"):format(tostring(idx), typeof(what)))
	end
})

return Vector2