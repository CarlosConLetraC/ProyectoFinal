local Vector3 = {}
local methods = {}
local Table = Table or import("Table")
local append = loadfile("import/sublibs/Vector3.lua")(Vector3, ...)

function methods.dot(vecx, vecy)
	local X, Y, Z = (vecx.X + vecy.X) / 2, (vecx.Y + vecy.Y) / 2, (vecx.Z + vecy.Z) / 2
	return Vector3.new(-X, -Y, -Z)
end

function methods.len(vec)
	return (vec.X*vec.X + vec.Y*vec.Y + vec.Z*vec.Z)^0.5
end

function methods.squarelen(vec)
	return vec.X*vec.X + vec.Y*vec.Y + vec.Z*vec.Z
end

function methods.cross(vecx, vecy)
	return vecx.X*vecy.Y - vecx.Y*vecy.X - vecx.Z*vecy.Z
end

--function methods.lerp(vecx, vecy, t)
--	local dot = -vecx:dot(vecy)
--	t = t*2
--	return Vector3.new(dot.X * t, dot.Y * t, dot.Z * t)
--end
function methods.lerp(vecx, vecy, t)
	local x = vecx.X + (vecy.X - vecx.X) * t
	local y = vecx.Y + (vecy.Y - vecx.Y) * t
	local z = vecx.Z + (vecy.Z - vecx.Z) * t
	return Vector3.new(x, y, z)
end

function methods.magnitude(vecx, vecy)
	return math.sqrt(math.pow((vecy.X - vecx.X), 2) + math.pow((vecy.Y - vecx.Y), 2) + math.pow((vecy.Z - vecx.Z), 2))
end

function methods.unpack(self)
	return self.X, self.Y, self.Z
end

function Vector3.new(x, y, z)
	local newVector3 = {
		X = (type(x) == "number" and x) or tonumber(x or "") or tonumber(x or "", 16) or 0,
		Y = (type(y) == "number" and y) or tonumber(y or "") or tonumber(y or "", 16) or 0,
		Z = (type(z) == "number" and z) or tonumber(z or "") or tonumber(z or "", 16) or 0
	}

	for k, v in pairs(methods) do
		newVector3[k] = v
	end

	return append.create(newVector3)
end

--[[
none:     Vector3.new(0, 0,0)
up:       Vector3.new(0, 1,0)
down:     Vector3.new(0,-1,0)
right:    Vector3.new(1, 0,0)
left:     Vector3.new(-1,0,0)
back:     Vector3.new(0,0, 1)
front:    Vector3.new(0,0, -1)

-- EN TOTAL: 3 OPCIONES CON 3 COMBINACIONES (-1,0,1)
-- (implica que) => e^x
-- DONDE: e=3  x=3 -> 3^3 = 27 OPCIONES EN TOTAL.
]]

setmetatable(Vector3, {
	__metatable = "locked",
	__index = {
		methods = Table.clone(methods, true),
		zero = Vector3.new(0,0,0),
		one = Vector3.new(1,1,1),
		xAxis = Vector3.new(1,0,0),
		yAxis = Vector3.new(0,1,0),
		zAxis = Vector3.new(0,0,1),
		Top = Vector3.new(0,1,0),
		Bottom = Vector3.new(0,-1,0),
		Back = Vector3.new(0,0,1),
		Front = Vector3.new(0,0,-1),
		Right = Vector3.new(1,0,0),
		Left = Vector3.new(-1,0,0)
	},
	__newindex = function(_, _, _)
		error("Cannot modify frozen table.", 2)
	end,
	--__index = function(self, idx)
	--	if idx == "methods" then
	--		return Table.clone(methods)
	--	end
	--end
})

return Vector3