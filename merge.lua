import("csvfast", "Table", "json", "cml", "cstats", "task")

-- DISCOVER SHARDS
local function list_files(prefix)
	local p = io.popen("ls data/" .. prefix .. "_*.csv 2>/dev/null")
	if not p then return {} end

	local files = {}

	for file in p:lines() do
		local n = file:match(prefix .. "_(%d+)%.csv")
		if n then
			table.insert(files, {
				path = file,
				idx = tonumber(n)
			})
		end
	end

	p:close()

	table.sort(files, function(a, b)
		return a.idx < b.idx
	end)

	return files
end

-- SHARDS
local train_shards = list_files("dataset_train")
local test_shards  = list_files("dataset_test")

blund(#train_shards > 0, "no train shards found")
blund(#test_shards > 0, "no test shards found")

print("Train shards:", #train_shards)
print("Test shards :", #test_shards)

-- STORAGE
local train = {}
local test  = {}

-- schema
local schema = {
	log_price = true,
	accommodates = true,
	bathrooms = true,
	bedrooms = true,
	beds = true,
	reviews = true,
	rating = true,
	latitude = true,
	longitude = true,
	lat = true,
	lon = true,
	cleaning_fee = true,
	instant_bookable = true,
	host_verified = true,
	room_entire = true,
	room_private = true,
	room_shared = true,
	is_apartment = true
}

local function get_lat(r)
	return r.lat or r.latitude
end

local function get_lon(r)
	return r.lon or r.longitude
end

-- LOADER
local function loader(shards, target, label)
	return function()
		for _, s in ipairs(shards) do
			print("["..label.."] loading:", s.path)

			csvfast.each(s.path, function(r)

				local lat = get_lat(r)
				local lon = get_lon(r)

				if not lat or not lon then return end
				if r.log_price ~= r.log_price then return end

				target[#target+1] = {
					log_price = r.log_price,
					accommodates = r.accommodates,
					bathrooms = r.bathrooms,
					bedrooms = r.bedrooms,
					beds = r.beds,
					reviews = r.reviews,
					rating = r.rating,
					lat = lat,
					lon = lon,
					cleaning_fee = r.cleaning_fee,
					instant_bookable = r.instant_bookable,
					host_verified = r.host_verified,
					room_entire = r.room_entire,
					room_private = r.room_private,
					room_shared = r.room_shared,
					is_apartment = r.is_apartment
				}

			end, { schema = schema })

			task.wait(0)
		end

		print("["..label.."] DONE")
	end
end

task.spawn(loader(train_shards, train, "TRAIN"))
task.spawn(loader(test_shards, test, "TEST"))

while task.step() do end

print("Train size:", #train)
print("Test size :", #test)

-- FEATURES
local features = {
	"accommodates","bathrooms","bedrooms","beds",
	"reviews","rating","lat","lon",
	"cleaning_fee","instant_bookable","host_verified",
	"room_entire","room_private","room_shared","is_apartment"
}

-- MODEL
local model = cml.LinearRegression({
	features = features,
	target = "log_price"
})

model:fit(train, 0.05, 3000, 0.0)

-- PREDICT ARRAYS
local y_true = {}
local y_pred = {}

for i = 1, #test do
	local r = test[i]
	local p = model:predict(r)

	y_true[i] = r.log_price
	y_pred[i] = p
end

-- METRICS (CSTATS NOW USED PROPERLY)
local mae  = cstats.mae(y_true, y_pred)
local mse  = cstats.mse(y_true, y_pred)
local r2   = cstats.r2(y_true, y_pred)

-- CORRELATION (still useful)
local function col(data, key)
	local t = {}
	for i = 1, #data do
		t[i] = data[i][key]
	end
	return t
end

local corr_rating  = cstats.corr(col(train,"rating"), col(train,"log_price"))
local corr_reviews = cstats.corr(col(train,"reviews"), col(train,"log_price"))

print("===== METRICS =====")
print("MAE:", mae)
print("MSE:", mse)
print("R2 :", r2)
print("Corr rating:", corr_rating)
print("Corr reviews:", corr_reviews)

-- EXPORT
local export = model:export()

if #export.weights == #features + 1 then
	export.bias = table.remove(export.weights, 1)
end

local out = {
	meta = {
		train = #train,
		test = #test
	},
	metrics = {
		mae = mae,
		mse = mse,
		r2 = r2,
		corr_rating = corr_rating,
		corr_reviews = corr_reviews
	},
	model = export
}

local f = assert(io.open("data/model_final.json", "w"))
f:write(json.encode(out))
f:close()

print("MODEL OK -> data/model_final.json")