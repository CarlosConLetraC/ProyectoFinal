local _, gmt = debug.setmetatable or setmetatable, debug.getmetatable or getmetatable
local os_clock = os.clock

local string_format = string.format
local string_gsub = string.gsub
local string_char = string.char

local table_insert = table.insert
local table_concat = table.concat

local tostring, tonumber, rawequal, rawset, type, typeof, unpack, pairs, ipairs =
	  tostring, tonumber, rawequal, rawset, type, typeof or type, unpack or table.unpack, pairs, ipairs

typeof, type = type, typeof
local rawlen                = rawlen or function(v) return select("#", unpack(v)) end

local import = import
local Math = {nan=-(math.huge/math.huge)}
local Table = Table or import("Table")

local Table_create = Table.create
local Table_new = Table.new

local _ENV = _ENV or _G
local bit32 = _ENV.bit32 or _ENV.bit or import("bit32")
local kPerlinHash = {
	[0] = 0x97, 0xA0, 0x89, 0x5B, 0x5A, 0x0F, 0x83, 0x0D, 0xC9, 0x5F,
	0x60, 0x35, 0xC2, 0xE9, 0x07, 0xE1, 0x8C, 0x24, 0x67, 0x1E, 0x45,
	0x8E, 0x08, 0x63, 0x25, 0xF0, 0x15, 0x0A, 0x17, 0xBE, 0x06, 0x94,
	0xF7, 0x78, 0xEA, 0x4B, 0x00, 0x1A, 0xC5, 0x3E, 0x5E, 0xFC, 0xDB,
	0xCB, 0x75, 0x23, 0x0B, 0x20, 0x39, 0xB1, 0x21, 0x58, 0xED, 0x95,
	0x38, 0x57, 0xAE, 0x14, 0x7D, 0x88, 0xAB, 0xA8, 0x44, 0xAF, 0x4A,
	0xA5, 0x47, 0x86, 0x8B, 0x30, 0x1B, 0xA6, 0x4D, 0x92, 0x9E, 0xE7,
	0x53, 0x6F, 0xE5, 0x7A, 0x3C, 0xD3, 0x85, 0xE6, 0xDC, 0x69, 0x5C,
	0x29, 0x37, 0x2E, 0xF5, 0x28, 0xF4, 0x66, 0x8F, 0x36, 0x41, 0x19,
	0x3F, 0xA1, 0x01, 0xD8, 0x50, 0x49, 0xD1, 0x4C, 0x84, 0xBB, 0xD0,
	0x59, 0x12, 0xA9, 0xC8, 0xC4, 0x87, 0x82, 0x74, 0xBC, 0x9F, 0x56,
	0xA4, 0x64, 0x6D, 0xC6, 0xAD, 0xBA, 0x03, 0x40, 0x34, 0xD9, 0xE2,
	0xFA, 0x7C, 0x7B, 0x05, 0xCA, 0x26, 0x93, 0x76, 0x7E, 0xFF, 0x52,
	0x55, 0xD4, 0xCF, 0xCE, 0x3B, 0xE3, 0x2F, 0x10, 0x3A, 0x11, 0xB6,
	0xBD, 0x1C, 0x2A, 0xDF, 0xB7, 0xAA, 0xD5, 0x77, 0xF8, 0x98, 0x02,
	0x2C, 0x9A, 0xA3, 0x46, 0xDD, 0x99, 0x65, 0x9B, 0xA7, 0x2B, 0xAC,
	0x09, 0x81, 0x16, 0x27, 0xFD, 0x13, 0x62, 0x6C, 0x6E, 0x4F, 0x71,
	0xE0, 0xE8, 0xB2, 0xB9, 0x70, 0x68, 0xDA, 0xF6, 0x61, 0xE4, 0xFB,
	0x22, 0xF2, 0xC1, 0xEE, 0xD2, 0x90, 0x0C, 0xBF, 0xB3, 0xA2, 0xF1,
	0x51, 0x33, 0x91, 0xEB, 0xF9, 0x0E, 0xEF, 0x6B, 0x31, 0xC0, 0xD6,
	0x1F, 0xB5, 0xC7, 0x6A, 0x9D, 0xB8, 0x54, 0xCC, 0xB0, 0x73, 0x79,
	0x32, 0x2D, 0x7F, 0x04, 0x96, 0xFE, 0x8A, 0xEC, 0xCD, 0x5D, 0xDE,
	0x72, 0x43, 0x1D, 0x18, 0x48, 0xF3, 0x8D, 0x80, 0xC3, 0x4E, 0x42,
	0xD7, 0x3D, 0x9C, 0xB4, 0x97
}
--("{[0]=%s}"):format(kph:tconcat(function(i, n) local s = (i < kph:len() and ("0x%.2X, "):format(n)) or ("0x%.2X"):format(n); return s .. (((i+1)%12 == 0 and '\n') or "") end))
local kPerlinGrad = {
	[0] = { [0] = 1, 1, 0 },
	{ [0] = -1, 1,  0 },
	{ [0] = 1,  -1, 0 },
	{ [0] = -1, -1, 0 },
	{ [0] = 1,  0,  1 },
	{ [0] = -1, 0,  1 },
	{ [0] = 1,  0,  -1 },
	{ [0] = -1, 0,  -1 },
	{ [0] = 0,  1,  1 },
	{ [0] = 0,  -1, 1 },
	{ [0] = 0,  1,  -1 },
	{ [0] = 0,  -1, -1 },
	{ [0] = 1,  1,  0 },
	{ [0] = 0,  -1, 1 },
	{ [0] = -1, 1,  0 },
	{ [0] = 0,  -1, -1 }
}

local function perlin_grad(hash, x, y, z)
	local g = kPerlinGrad[bit32.band(hash, 15)]
	return g[0] * x + g[1] * y + g[2] * z
end

local function perlin_fade(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

function Math.dsin(n)
	return Math.sin(n / (180 / Math.pi))
end

function Math.dcos(n)
	return Math.cos(n / (180 / Math.pi))
end

function Math.dtan(n)
	return Math.tan(n / (180 / Math.pi))
end

function Math.dasin(n)
	return Math.asin(n) * (180 / Math.pi)
end

function Math.dacos(n)
	return Math.acos(n) * (180 / Math.pi)
end

function Math.datan(n)
	return Math.atan(n) * (180 / Math.pi)
end

function Math.perlin(x, y, z)
	local xflr = Math.floor(x)
	local yflr = Math.floor(y)
	local zflr = Math.floor(z)

	local xi = bit32.band(xflr, 255)
	local yi = bit32.band(yflr, 255)
	local zi = bit32.band(zflr, 255)

	local xf = x - xflr
	local yf = y - yflr
	local zf = z - zflr

	local u = perlin_fade(xf)
	local v = perlin_fade(yf)
	local w = perlin_fade(zf)

	local a = bit32.band((kPerlinHash[xi] + yi), 255)
	local aa = bit32.band((kPerlinHash[a] + zi), 255)
	local ab = bit32.band((kPerlinHash[a + 1] + zi), 255)

	local b = bit32.band((kPerlinHash[xi + 1] + yi), 255)
	local ba = bit32.band((kPerlinHash[b] + zi), 255)
	local bb = bit32.band((kPerlinHash[b + 1] + zi), 255)

	local la = Math.lerp(perlin_grad(kPerlinHash[aa], xf, yf, zf), perlin_grad(kPerlinHash[ba], xf - 1, yf, zf), u)
	local lb = Math.lerp(perlin_grad(kPerlinHash[ab], xf, yf - 1, zf), perlin_grad(kPerlinHash[bb], xf - 1, yf - 1, zf), u)
	local la1 = Math.lerp(perlin_grad(kPerlinHash[aa + 1], xf, yf, zf - 1),
		perlin_grad(kPerlinHash[ba + 1], xf - 1, yf, zf - 1), u)
	local lb1 = Math.lerp(perlin_grad(kPerlinHash[ab + 1], xf, yf - 1, zf - 1),
		perlin_grad(kPerlinHash[bb + 1], xf - 1, yf - 1, zf - 1), u)

	return Math.lerp(Math.lerp(la, lb, v), Math.lerp(la1, lb1, v), w)
end

function Math.add(...)
	local nums = { ... }
	local n = 0
	for i = 1, select("#", ...), 1 do
		n = n + nums[i]
	end
	return n
end

function Math.sub(...)
	local nums = { ... }
	local n = select(1, ...)
	for i = 2, select("#", ...), 1 do
		n = n - nums[i]
	end
	return n
end

function Math.factorial(n)
	local x = 1
	for i = n, 1, -1 do
		x = x * i
	end
	return x
end

function Math.perm(n, r)
	local N = 1

	for i = n, n-r+1, -1 do
		N = N * i
	end

	return N
end

function Math.comb(n, r)
	return Math.perm(n, n-r) / Math.factorial(n-r)
end

function Math.clamp(n, x, y)
	return
		(n >= x and n <= y and n) or
		(n <= x and n <= y and x) or
		(n >= x and n >= y and y) or
		(x + y) / 2
end

function Math.xclamp(x, min, max)
	local range = max - min + 1
	local relative = (x - min) % range
	relative = (relative ~= relative and (x - min) % (range + 1)) or relative
	relative = (relative < 0 and relative + range) or relative
	return min + relative
end

function Math.lerp(a, b, t)
	return a + (b - a) * t
end

function Math.invlerp(a, b, v)
	return (v - a) / (b - a)
end

function Math.eucl(a, b)
	local q = a % b
	local r = (a - q) / b

	return r, b, q
end

function Math.fnoise(x, seed)
	seed = (type(seed) == "number" and seed) or tonumber(seed) or os_clock()
	local floorX = math.floor(x)
	local a, b = Math.intnoise(floorX, seed), Math.intnoise(floorX + 1, seed)
	local t = x - floorX
	return Math.lerp(a, b, t)
end

function Math.intnoise(x, seed)
	seed = (type(seed) == "number" and seed) or tonumber(seed) or 1
	x = math.abs(x)
	x = bit32.bxor(bit32.rshift(x, 13), x)
	local y = bit32.band((x * (x * x * 0xEC4D + 0x131071F) + 0x5208DD0D), 0x7FFFFFFF)
	return (1 - (y / 0x40000000)) * seed
end

function Math.noise(x, y, z)
	x = assert((type(x) == "number" and x) or tonumber(x),
		string_format("invalid argument #1, number expected (got %s)", type(x)))
	y = (type(y) == "number" and y) or tonumber(y) or 0
	z = (type(z) == "number" and z) or tonumber(z) or 0

	return Math.perlin(x, y, z)
end

function Math.round(n)
	local x = (n % 1) * 10
	return (x >= 5 and math.ceil(n)) or math.floor(n)
end

function Math.root(n, b)
	return Math.pow(n, 1 / b)
end

function Math.truncate(n)
	return math.floor(math.abs((n >= 0 and n) or -n))
end

function Math.hypot(x, y)
	return (x * x + y * y) ^ 0.5
end

--function Math.euler(x)
--	return (1 + (1 / x)) ^ x
--end

function Math.fg(a, b, c)
	local x = b * b - (4 * a * c)

	if x >= 0 then
		return x * (-1)
	end

	local x1 = (-b + math.sqrt(x)) / (2 * a)
	local x2 = (-b - math.sqrt(x)) / (2 * a)

	return x1, x2
end

function Math.quadbezier(t, x, y, z)
	local q0 = Math.lerp(x, y, t)
	local q1 = Math.lerp(y, z, t)
	local q2 = Math.lerp(q0, q1, t)

	return q2
end

function Math.bezier(t, p0, p1, p2)
	return (1 - t) ^ 2 * p0 + 2 * (1 - t) * t * p1 + (t * t) * p2
end

-- class interval (tabla de intervalos)
function Math.cinterval(rango, frecuencia_R)
	local ti = Table.apply({
		-- intervalo
		rango = rango,

		-- datos
		x1 = Table_new(),

		-- frecuencia relativa
		fr = frecuencia_R,
		fr_total = 0,

		-- frecuencia acumulada
		fa = Table_new(),

		-- media
		x2 = Table_new(),
		x2_total = 0,

		-- mediana
		me = Table_new(),
		me_total = 0,

		-- moda
		mo = Table_new(),
		mo_total = 0,

		-- porcentaje (100)
		ps = Table_new(),
		ps_total = 0,

		-- grados (360)
		gr = Table_new(),
		gr_total = 0
	})

	ti.rango:foreach(function(i, v)
		local x1_val = (v[1] + v[2]) / 2
		ti.x1:iput(x1_val)
		ti.fr_total = ti.fr_total + ti.fr[i]
		ti.fa[i] = ti.fr_total
		ti.x2:iput(ti.x1[i] * ti.fr[i])
	end)
	ti.x2_total = Math.add(ti.x2:unpack()) / ti.fr_total

	ti.me_total = ti.fa:foreach(function(idx, val)
		if ti.fr_total / 2 <= val then
			ti.me:append(ti.fr:len(), ti.fr[idx])
			return ti.x1[idx]
		end
	end)

	local __mo_total = ti.fr:clone()
	__mo_total:foreach(function(i, v)
		__mo_total[i] = Table.apply({
			val = v,
			dato = ti.x1[i]
		})
	end)
	__mo_total:sort(function(v1, v2)
		return v1.val > v2.val
	end)
	ti.mo:append(ti.fr:len(), __mo_total[1].val)
	ti.mo_total = __mo_total[1].dato

	ti.fr:foreach(function(i, v)
		ti.ps:iput((v * 100) / ti.fr_total)
		ti.ps_total = ti.ps_total + ti.ps[i]

		ti.gr:iput((v * 360) / ti.fr_total)
		ti.gr_total = ti.gr_total + ti.gr[i]
	end)

	-- desviacion cuadratica
	ti.xx   = Table_new()
	
	-- desviacion cuadratica ponderada
	ti.xxfr = Table_new()

	ti.x1:foreach(function(i, x)
		--print((x - ti.x2_total) ^ 2)
		--print((x - ti.x2_total)*(x - ti.x2_total))
		--print(x*x - x*ti.x2_total - x*ti.x2_total + ti.x2_total*ti.x2_total)
		--print()
		ti.xx:put(i, (x - ti.x2_total) ^ 2)
		ti.xxfr:put(i, (x - ti.x2_total) ^ 2 * ti.fr[i])
	end)

	-- desviacion cuadratica ponderada total
	ti.xxfr_total = Math.add(ti.xxfr:unpack())
	ti.varianza = ti.xxfr_total / ti.fr_total
	ti.desviacion = Math.sqrt(ti.varianza)

	return ti
end

-- MEDidas de tENdencia CENtral
function Math.medencen(x, intervalos)
	local tm = Table_new()
	local n = x:len()
	local x2 = Table_create(n, function(i) return x[i]^2 end, "tailcall")

	local media_aritmetica = Math.add(x:unpack()) / n
	local mediana, moda

	if n%2 == 0 then
		local nx = math.floor(n/2)
		mediana = (x[nx] + x[nx+1])/2
	else
		local nx = math.ceil(n/2)
		mediana = x[nx]
	end

	local aux = Table_new()
	local aux_x = x:clone()
	local aux_n = 0

	aux_x:sort()
	x:foreach(function(_, v)
		local k = string_format("%.23g", v)
		aux[k] = aux[k] or {value = v, count = 0}
		aux[k].count = aux[k].count + 1
	end)

	aux:foreach(function(i, v)
		if type(i) == "string" then
			aux_n = aux_n + 1
			aux[aux_n] = v
			aux[i] = nil
		end
	end)
	aux:sort(function(t0, t1) return t0.count > t1.count end)

	moda = aux[1].value
	local varianza = (Math.add(x2:unpack()) - (Math.add(x:unpack())^2/n))/(n-1)
	local desviacion_estandar = varianza^(1/2)
	local cv = (varianza/media_aritmetica)*100

	tm.x_total = Math.add(x:unpack())
	tm.media_aritmetica = media_aritmetica
	tm.mediana = mediana
	tm.moda = moda
	tm.varianza = varianza
	tm.desviacion_estandar = desviacion_estandar
	tm.cv = cv
	tm.x = x
	tm.x2 = x2

	local k, min, max, R, A
	min = aux_x[1]
	max = aux_x[n]
	R = max - min
	k = 1 + math.log(10, 2)*math.log(n, 10)
	A = R/k

	tm.min = min
	tm.max = max
	tm.R = R
	tm.k = k
	tm.A = A

	local N = math.ceil(k)
	local current = min
	local frec = Table.apply({
		intervalos = intervalos or Table_create(N, function(i)
			local t = {current, current+A}
			current = current + A
			return t
		end, "tailcall"),
		fi = Table_new(),
		Fi = Table_new(),
		hi = Table_new(),
		Hi = Table_new()
	})

	x:foreach(function(_, v)
		local k = string_format("%.23g", v)
		frec.fi[k] = frec.fi[k] or {
			value = v,
			count = 0
		}
		frec.fi[k].count = frec.fi[k].count + 1
	end)

	frec.fi:foreach(function(k, v)
		if type(k) ~= "string" then return end
		table_insert(frec.fi, v)
		frec.fi[k] = nil
	end)
	frec.fi:sort(function(t0, t1)
		return t0.value < t1.value
	end)

	local real_fi = Table_new()
	frec.intervalos:foreach(function(i, v)
		x:foreach(function(j, t)
			real_fi[i] = real_fi[i] or {Li = v[1], Ls = v[2], count = 0}
			if t >= real_fi[i].Li and (t < real_fi[i].Ls or (x[j+1] == nil and t <= real_fi[i].Ls)) then
				real_fi[i].count = real_fi[i].count + 1
			end
		end)
	end)
	frec.fi = real_fi

	frec.fi:foreach(function(i, v)
		frec.Fi[i] = frec.Fi[i] or 0
		frec.Fi[i] = frec.Fi[i] + v.count
		if frec.fi[i+1] == nil then return end
		frec.Fi[i+1] = frec.Fi[i]
	end)

	local Hi_i = 0
	frec.fi:foreach(function(i, v)
		frec.hi[i] = 100 * (v.count / frec.Fi[N])
		Hi_i = Hi_i + frec.hi[i]
		frec.Hi[i] = Hi_i
	end)

	tm.frec = frec
	return tm
end

local function normal_cdf(x)
	local t = 1 / (1 + 0.2316419 * math.abs(x))

	local a1 = 0.31938153
	local a2 = -0.356563782
	local a3 = 1.781477937
	local a4 = -1.821255978
	local a5 = 1.330274429

	local poly = a1 * t + a2 * t^2 + a3 * t^3 + a4 * t^4 + a5 * t^5
	local exp_factor = math.exp(-x^2 / 2)
	local cdf = 1 - (1 / math.sqrt(2 * math.pi)) * exp_factor * poly

	return cdf
end

local function find_x_for_cdf(target_cdf)
	local lower = -10
	local upper = 10
	local mid

	while --[[upper - lower > 1e-14]]true do
		if mid == (lower + upper) / 2 then break end
		mid = (lower + upper) / 2
		local cdf_at_mid = normal_cdf(mid)

		if cdf_at_mid > target_cdf then
			upper = mid  -- Si la CDF es mayor, el valor de x esta a la izquierda
		else
			lower = mid  -- Si la CDF es menor, el valor de x esta a la derecha
		end
	end

	return (lower + upper) / 2---, lower, upper, mid
end

function Math.cdf(x)
	local cdf = (x+100)/200
	local z0 = find_x_for_cdf(cdf)
	local z1 = z0 * 10
	z1 = (z1-z1%1)/10
	z0 = z0 - z1
	
	local z2 = z0 + z1
	--z0 = tonumber(string_format("%.2f", z0))
	--z1 = tonumber(string_format("%.2f", z1))
	z2 = tonumber(string_format("%.2f", z2))
	return z2
end

function Math.muestra(x, N, e, p, q)
	q = q or tonumber(q) or tonumber(q or "", 16) or 100 - (p or 0)
	if not p then
		return (x^2 * N)/(4 * (e^2)/10000 * (N - 1) + x^2)
	end
	--q = q or tonumber(q) or tonumber(q or "", 16) or 100 - p
	if N >= 500000 then
		return (x^2*((p*q)/10000))/((e^2)/10000)
	end
	return (x^2 * N * ((p*q)/10000))/((e^2)/10000 * (N-1) + x^2 * ((p*q)/10000))
end

-- position measurement (medidas de posicion)
function Math.posm(ti, q, d, p)
	ti.medidas = ti.medidas or Table.apply({
		Cuartiles = Table.apply({["mp"] = Table_new(), ["n"] = 4}),--Table_new():put("mp", Table_new()):put("n", 4),    -- Qn (i/4)
		Deciles = Table.apply({["mp"] = Table_new(), ["n"] = 10}),--Table_new():put("mp", Table_new()):put("n", 10),     -- Dn (i/10)
		Percentiles = Table.apply({["mp"] = Table_new(), ["n"] = 100})--Table_new():put("mp", Table_new()):put("n", 100) -- Pn (i/100)
	})

	ti.medidas.Cuartiles.mp:iput(q)
	ti.medidas.Deciles.mp:iput(d)
	ti.medidas.Percentiles.mp:iput(p)

	ti.medidas:foreach(function(what, md)
		md.mp:foreach(function(_, mp)
			local Kn = mp.K * ti.fr_total / md.n
			local Li, Fi = ti.fa:foreach(function(i, x)
				if x >= Kn then
					return ti.rango[i], Table_new(ti.fa[i - 1] or 0, x)
				end
			end)

			local A = Li[2] - Li[1]
			mp.final = Li[1] + A * ((Kn - Fi[1]) / (Fi[2] - Fi[1]))
			mp.operaciones = Table_new(
				string_format("%.0f + %.0f*((%.8g - %.8g) / (%.8g - %.8g))", Li[1], A, Kn, Fi[1], Fi[2], Fi[1]),
				string_format("%.0f + %.0f*(%.8g/%.8g)", Li[1], A, Kn - Fi[1], Fi[2] - Fi[1]),
				string_format("%.0f + %.8g", Li[1], A * ((Kn - Fi[1]) / (Fi[2] - Fi[1])))
			)
			mp.conversion = string_format("%.8g * %.8g / %.8g = %.8g", mp.K, ti.fr_total, md.n, Kn)
		end)
	end)

	return ti
end

local posms = {}
function posms.q(ti, v) return Math.posm(ti, v, nil, nil) end
function posms.d(ti, v) return Math.posm(ti, nil, v, nil) end
function posms.p(ti, v) return Math.posm(ti, nil, nil, v) end

function Math.gposm(ti, mps)
	mps:foreach(function(ps, t)
		t:foreach(function(_, v)
			blund(posms[ps], string_format("Invalid gposm mode '%s'.", ps))(ti, v)
		end)
	end)

	return ti
end

-- regresion lineal simple y multiple.
-- TODO: hacer que el modelo ya tenga datos estandarizados (std deviation). . .
function Math.regresion_lineal(data, config)
	local newRM = {}
	newRM.data = data
	newRM.features = config.features
	newRM.target = config.target

	--newRM.x_mean = {}
	newRM.y_mean = 0

	function newRM:normalizar()
		local n = #self.data
		local k = #self.features

		self.x_mean = {}
		self.y_mean = 0

		-- init
		for j = 1, k do
			self.x_mean[j] = 0
		end

		-- sum
		for i = 1, n do
			local row = self.data[i]

			for j = 1, k do
				local v = row[self.features[j]]
				assert(v ~= nil, "Missing feature: " .. self.features[j])
				self.x_mean[j] = self.x_mean[j] + v
			end

			self.y_mean = self.y_mean + row[self.target]
		end

		-- mean.
		for j = 1, k, 1 do
			self.x_mean[j] = self.x_mean[j] / n
		end

		self.y_mean = self.y_mean / n

		-- normalize dataset.
		self.norm = {}

		for i = 1, n, 1 do
			local row = self.data[i]
			self.norm[i] = {}

			for j = 1, k do
				local v = row[self.features[j]]
				self.norm[i][j] = v - self.x_mean[j]
			end

			self.norm[i][k + 1] = row[self.target] - self.y_mean
		end

		return self.norm
	end

	function newRM:entrenar(lr, epochs)
		local n = #self.norm
		local k = #self.features

		local b = {}
		for i = 1, k + 1, 1 do b[i] = 0 end

		for e = 1, epochs, 1 do
			local grad = {}

			for i = 1, k + 1, 1 do
				grad[i] = 0
			end

			for i = 1, n, 1 do
				local row = self.norm[i]
				local y = row[k + 1] -- 'y' esta en ultima posicion, pero ahora es seguro porque lo definimos asi en 'normalizar()'.
				local y_pred = b[1]

				for j = 1, k, 1 do
					y_pred = y_pred + b[j + 1] * row[j]
				end

				local err = y_pred - y
				grad[1] = grad[1] + err

				for j = 1, k, 1 do
					grad[j + 1] = grad[j + 1] + err * row[j]
				end
			end

			for j = 1, k + 1, 1 do
				b[j] = b[j] - lr * (grad[j] / n)
			end
		end

		self.b = b
		return b
	end

	function newRM:predecir(row)
		local k = #self.features
		local x = {}

		for i = 1, k, 1 do
			local v = row[self.features[i]]
			assert(v ~= nil, "feature no encontrado: " .. self.features[i])
			x[i] = v - self.x_mean[i]
		end
		local y = self.b[1]
		for i = 1, k, 1 do
			y = y + self.b[i + 1] * x[i]
		end

		return y + self.y_mean
	end

	-- coeficiente de correlacion lineal de Pearson.
	function newRM:pearson(ix, iy)
		assert(self.norm, "regresion no normalizada.")

		local n = #self.norm
		local sum_x, sum_y = 0, 0
		local sum_x2, sum_y2 = 0, 0
		local sum_xy = 0

		for i = 1, n, 1 do
			local x = self.norm[i][ix]
			local y = self.norm[i][iy]
			sum_x = sum_x + x
			sum_y = sum_y + y
			sum_x2 = sum_x2 + x * x
			sum_y2 = sum_y2 + y * y
			sum_xy = sum_xy + x * y
		end

		local num = n * sum_xy - sum_x * sum_y
		local den = math.sqrt((n * sum_x2 - sum_x*sum_x) * (n * sum_y2 - sum_y*sum_y))

		if den == 0 then return 0 end
		return num / den
	end

	-- coeficiente de determinacion.
	function newRM:determinacion()
		local ss_res = 0
		local ss_tot = 0
		local n = #self.data

		for i = 1, n, 1 do
			local row = self.data[i]
			local y = row[self.target]
			local y_pred = self:predecir(row)
			ss_res = ss_res + (y - y_pred)^2
			ss_tot = ss_tot + (y - self.y_mean)^2
		end

		return 1 - (ss_res / ss_tot)
	end

	function newRM:mse()
		local n = #self.data
		local err_sum = 0

		for i = 1, n, 1 do
			local row = self.data[i]
			local y_true = row[self.target]
			local y_pred = self:predecir(row)
			local err = y_true - y_pred
			err_sum = err_sum + err * err
		end

		return err_sum / n
	end
	function newRM:rmse() return math.sqrt(self:mse()) end

	return newRM
end

function Math.regresion_logistica(data, config)
	local newRL = Math.regresion_lineal(data, config)

	-- detectar pesos.
	newRL.w = newRL.w or newRL.weights or newRL.theta or {}

	-- bias.
	newRL.bias = newRL.bias or 0

	-- inicializar pesos si vacios.
	for i = 1, #newRL.features, 1 do
		newRL.w[i] = newRL.w[i] or 0
	end

	local function sigmoid(x)
		if x < -50 then return 0 end
		if x > 50 then return 1 end
		return 1 / (1 + math.exp(-x))
	end

	function newRL:probabilidad(row)
		local z = self.bias

		for i, f in ipairs(self.features) do
			z = z + self.w[i] * row[f]
		end

		return sigmoid(z)
	end

	function newRL:predecir(row)
		return self:probabilidad(row) >= 0.5 and 1 or 0
	end

	function newRL:entrenar(lr, epochs)
		lr = lr or 0.01
		epochs = epochs or 1000

		for ep = 1, epochs, 1 do
			local grad = {}

			for i = 1, #self.features, 1 do
				grad[i] = 0
			end

			local grad_b = 0

			for _, row in ipairs(self.data) do
				local y = row[self.target]
				local p = self:probabilidad(row)
				local error = p - y

				for i, f in ipairs(self.features) do
					grad[i] = grad[i] + error * row[f]
				end

				grad_b = grad_b + error
			end

			local n = #self.data

			for i = 1, #self.features, 1 do
				self.w[i] = self.w[i] - lr * grad[i] / n
			end

			self.bias = self.bias - lr * grad_b / n
		end
	end

	function newRL:accuracy(data)
		local ok = 0

		for _, row in ipairs(data) do
			if self:predecir(row) == row[self.target] then
				ok = ok + 1
			end
		end

		return ok / #data
	end

	return newRL
end

local json = json or import("json")
local system = system or import("system")
local A1, A2 = 727595, 798405           -- 5^17=D20*A1+A2
local D20, D40 = 1048576, 1099511627776 -- 2^20, 2^40
local data = system.readfile("./data/rand_config.json")
local rand_config = json.decode(data)
while not rand_config do
	data = system.readfile("./data/rand_config.json")
	rand_config, msg = json.decode(data)
end

local X1, X2 = rand_config.X1, rand_config.X2

system.writefile("./data/rand_config.json", json.encode(rand_config))
function Math.rand(x, y, noRound)
	x = (type(x) == "number" and x) or (type(x) == "table" and type(x.value) == "number" and x.value) or
		tonumber(x or "") or tonumber(x or "", 16) or 0
	y = (type(y) == "number" and y) or (type(y) == "table" and type(y.value) == "number" and y.value) or
		tonumber(y or "") or tonumber(y or "", 16) or 1

	local U = X2 * A2
	local V = (X1 * A2 + X2 * A1) % D20
	V = (V * D20 + U) % D40
	X1 = math.floor(V / D20)
	X2 = V - X1 * D20

	rand_config.X1, rand_config.X2 = X1, X2
	system.writefile("data/rand_config.json", json.encode(rand_config))

	local n = V / D40
	if x < 0 or y < 0 then
		local _x, _y = math.abs(x), math.abs(y)
		n = Math.xclamp(n, x, y)
	else
		n = Math.xclamp(n * y, x, y)
	end

	return (not noRound and n) or Math.round(n)
end

function Math.newrand(x1, x2)
	local _A1, _A2 = 727595, 798405           -- 5^17=D20*A1+A2
	local _D20, _D40 = 1048576, 1099511627776 -- 2^20, 2^40
	local newRand = {}
	newRand.X1 = (type(x1) == "number" and x1) or tonumber(x1 or "") or tonumber(x1 or "", 16) or 0
	newRand.X2 = (type(x2) == "number" and x2) or tonumber(x2 or "") or tonumber(x2 or "", 16) or 1

	function newRand:next(x, y, noRound)
		local U = self.X2 * _A2
		local V = (self.X1 * _A2 + self.X2 * _A1) % _D20
		V = (V * _D20 + U) % _D40
		self.X1 = math.floor(V / _D20)
		self.X2 = V - self.X1 * _D20

		local n = V / _D40
		n = Math.xclamp(n * y, x, y)
		
		return not noRound and n or Math.round(n)
	end

	return newRand
end

--Progresion, Series, Sucesiones, Combinaciones, Permutaciones
--PROgresion;SErioes;suceSIOnes
function Math.prosesio(terminos)
	local function DoMT()
		local mt = {}
		
		function mt.__tostring(self)
			return Table.tconcat(self, function(_, subT)
				return (math.abs(subT.x) > 1 and subT.x or "")..subT.literal
			end, " + ")
		end
		
		function mt.__sub(self, term)
			local newTerm = Table_new()
			local _mt = {
				__sub = function(self, what)
					return self.x - what.x
				end,
				__tostring = function(self)
					return string_format("%.0f", self.x)..self.literal
				end
			}
			for i = 1, self.n-1, 1 do
				if self[i].x - term[i].x ~= 0 then
					local t = {
						["x"] = self[i].x - term[i].x,
						["literal"] = string_char(97+rawlen(newTerm))
					}
					setmetatable(t, _mt)
					table_insert(newTerm, t)
				end
			end

			mt.__index = {n = self.n - 1}
			Table.setmetatable(newTerm, mt)
			return newTerm
		end

		return mt
	end

	local obj = Table_new()
	obj.terminos = terminos
	local count = rawlen(terminos)
	local current = 1
	obj.enesimos = Table_new(Table.clone(terminos))
	
	for i = count, 2, -1 do
		local subEn = obj.enesimos[current]
		local newEn = Table_create(i-1, function(j)
			return subEn[j+1] - subEn[j]
		end, "tailcall")

		local fromReturn0 = 0
		newEn:foreach(function(j, v)
			fromReturn0 = (v == newEn[1] and fromReturn0+1) or fromReturn0
		end)

		if fromReturn0 == rawlen(newEn) then
			table_insert(obj.enesimos, newEn)
			current = current + 1
			break
		end

		table_insert(obj.enesimos, newEn)
		current = current + 1
	end

	function obj.f(x)
		local t = Table_new()
		local n = 1
		
		for i = rawlen(obj.enesimos)-1, 0, -1 do
			local newT = Table.apply({
				["x"] = x^i,
				["literal"] = string_char(96+n)
			})
			local newMT = {}
			function newMT.__sub(self, what)
				local t = Table.apply({
					["x"] = self.x - what.x,
					["literal"] = self.literal
				})
				Table.setmetatable(t, {
					__sub = newMT.__sub,
					__tostring = function(self)
						return (math.abs(self.x) > 1 and self.x or "")..self.literal
					end
				})
				return t
			end
			Table.setmetatable(newT, newMT)
			table_insert(t, newT)
			n = n + 1
		end

		local mt = DoMT()
		mt.__index = {n = n}
		Table.setmetatable(t, mt)
		return t
	end

	obj.subenesimos = Table_create(current, function(i)
		return obj.f(i)
	end, "tailcall")
	
	obj.subseries = Table_new(
		Table_create(current, function(i)
			return obj.f(i)
		end, "tailcall")
	)
	
	local starter = current
	local page = 1

	while starter > 1 do
		local subenesimos = (starter == current and obj.subenesimos) or obj.subseries[page]
		local serie = Table_new()
		table_insert(obj.subseries, serie)

		for i = 2, starter, 1 do
			local result = subenesimos[i] - subenesimos[i-1]
			table_insert(serie, result)
		end
		
		starter = starter - 1
		page = page + 1
	end

	obj.sucesiones = Table_new()
	local definidos = Table_new()
	local anteserie

	for i = current, 1, -1 do
		local subserie = obj.subseries[i][1]
		local sucesion = Table.apply({
			["literal"] = string_char(97+rawlen(obj.sucesiones))
		})
		Table.setmetatable(sucesion, {
			__tostring = function(self)
				return (self.x ~= 1 and self.x or "") .. self.literal
			end
		})
		if i == current and obj.enesimos[i] then
			sucesion.x = obj.enesimos[i][1] / subserie[1].x
			anteserie = subserie
			definidos[sucesion.literal] = sucesion.x
			table_insert(obj.sucesiones, sucesion)
		elseif obj.enesimos[i] then
			anteserie = obj.subseries[i+1][1]
			local nuevaSucesion = Table_new()
			subserie:foreach(function(j, t)
				if t.literal == sucesion.literal then
					definidos[t.literal] = (obj.enesimos[i][1] - Math.add(unpack(nuevaSucesion))) / t.x
					sucesion.x = definidos[t.literal]
					return nil
				end
				table_insert(nuevaSucesion, t.x * definidos[t.literal])
			end)
			table_insert(obj.sucesiones, sucesion)
		end
	end

	obj.g = Table_new()
	local gMT = {}
	gMT.__series = {}
	local enesimosLEN = rawlen(obj.enesimos)
	
	for i = 1, enesimosLEN, 1 do
		local c = string_char(96+i)
		if math.abs(definidos[c]) > 0 then
			table_insert(gMT.__series, Table.apply({["literal"] = c, ["x"] = definidos[c], ["exponente"] = enesimosLEN-i}))
		end
	end

	function gMT.__tostring(self)
		local st = {}
		local mt = gmt(self)
		mt = mt and mt.__mt

		local _len = rawlen(mt.__series)
		for i = 1, _len, 1 do
			local _sr = mt.__series[i]
			local next_sr = mt.__series[i+1] or mt.__series[i]
			if math.abs(_sr.x) > 1 then
				table_insert(st, string_format("%s*(x^%s)", math.abs(_sr.x), _sr.exponente))
			elseif _sr.x * -1 > 0 then
				table_insert(st, string_format("-x^%s", _sr.exponente))
			else
				table_insert(st, string_format("x^%s", _sr.exponente))
			end
			
			local stateA = ((next_sr.x > 0 and " + ") or (next_sr.x < 0 and " - ") or " ? ")
			table_insert(st, i ~= _len and stateA or "")
		end
		
		return table_concat(st)
	end

	function gMT.__call(self, x)
		local valores = {}
		local n = rawlen(obj.enesimos)
		local y = 0

		for i = n-1, 0, -1 do
			local c = string_char(97+y)
			y = y + 1
			--system.print(definidos[c])
			table_insert(valores, definidos[c]*(x^i))
		end
		
		return Math.add(unpack(valores))
	end

	Table.setmetatable(obj.g, gMT)
	return obj
end

function Math.gauss1(n) return (n*n + n)/2 end
function Math.gauss2(n) return (2*n*n*n + 3*n*n + n)/6 end

for k, v in pairs(math) do
	Math[k] = Math[k] or v
end

return Math
