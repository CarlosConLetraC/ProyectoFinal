local CodigoFuenteWorker = [[import("preworker")

preworker.start(
    INT_WORKER_ID,
    INT_TOTAL_WORKERS,
    BASE_DE_DATOS,
    PREFIX_SALIDA_REGRESION
)]]

local INT_TOTAL_WORKERS = 10
local PATH_OUTPUT = "daemons"

os.execute("mkdir -p " .. PATH_OUTPUT)
os.execute("rm -rf " .. PATH_OUTPUT .. "/*")
os.execute("rm -rf data/train_*.csv")
os.execute("rm -rf data/test_*.csv")
os.execute("rm -rf data/model_final.json")

local base_src = CodigoFuenteWorker
base_src = base_src:gsub("BASE_DE_DATOS", "\"data/train.csv\"")
base_src = base_src:gsub("PREFIX_SALIDA_REGRESION", "\"data/dataset_train\"")
base_src = base_src:gsub("INT_TOTAL_WORKERS", tostring(INT_TOTAL_WORKERS))

for i = 1, INT_TOTAL_WORKERS, 1 do
    local worker_src = base_src:gsub("INT_WORKER_ID", tostring(i))
    local f = assert(io.open(PATH_OUTPUT .. "/program.worker" .. i .. ".lua", "w"))
    f:write(worker_src)
    f:close()
end




--[===[import("csvfast", "Table")

-- CONFIG
local SPLIT_RATIO = 0.8
--local RANDOM_SEED = 42
--math.randomseed(RANDOM_SEED)

-- SCHEMA
local schema = {
	id = false,
	log_price = true,
	property_type = false,
	room_type = false,
	amenities = false,

	accommodates = true,
	bathrooms = true,
	bed_type = false,
	cancellation_policy = false,
	cleaning_fee = false,

	city = false,
	description = false,
	first_review = false,
	host_has_profile_pic = false,
	host_identity_verified = false,
	host_response_rate = false,
	host_since = false,
	instant_bookable = false,
	last_review = false,

	latitude = true,
	longitude = true,

	name = false,
	neighbourhood = false,

	number_of_reviews = true,
	review_scores_rating = true,

	thumbnail_url = false,
	zipcode = false,

	bedrooms = true,
	beds = true
}

-- UTILS
local function to_bool(v)
	if v == "t" or v == "true" or v == true then return 1 end
	return 0
end

local function clip(v, minv, maxv)
	if v < minv then return minv end
	if v > maxv then return maxv end
	return v
end

-- 1. IMPUTACIÓN
local sums, counts = {}, {}
local numeric_fields = {"bathrooms","bedrooms","beds","review_scores_rating"}

for _, f in ipairs(numeric_fields) do
	sums[f], counts[f] = 0, 0
end

csvfast.each("data/train.csv", function(row)
	for _, f in ipairs(numeric_fields) do
		local v = row[f]
		if v == v then
			sums[f] = sums[f] + v
			counts[f] = counts[f] + 1
		end
	end
end, {schema = schema})

local mean = {}
for _, f in ipairs(numeric_fields) do
	mean[f] = (counts[f] > 0) and (sums[f]/counts[f]) or 0
end

-- 2. BUILD DATASET (ROW FORMAT)
local dataset = Table.new()

csvfast.each("data/train.csv", function(row)
	local y = row.log_price
	if y ~= y then return end

	local acc  = clip(row.accommodates or 0, 1, 10)

	local bath = row.bathrooms
	local bedd = row.bedrooms
	local beds = row.beds
	local rating = row.review_scores_rating

	if bath ~= bath then bath = mean.bathrooms end
	if bedd ~= bedd then bedd = mean.bedrooms end
	if beds ~= beds then beds = mean.beds end
	if rating ~= rating then rating = mean.review_scores_rating end

	bath   = clip(bath, 0, 5)
	bedd   = clip(bedd, 0, 5)
	beds   = clip(beds, 0, 10)
	rating = clip(rating, 0, 100)

	local lat, lon = row.latitude, row.longitude
	if not (lat == lat and lon == lon) then return end

	local features = {
		y,
		acc,
		bath,
		bedd,
		beds,
		row.number_of_reviews or 0,
		rating,
		lat,
		lon,
		to_bool(row.cleaning_fee),
		to_bool(row.instant_bookable),
		to_bool(row.host_identity_verified),
		(row.room_type == "Entire home/apt") and 1 or 0,
		(row.room_type == "Private room") and 1 or 0,
		(row.room_type == "Shared room") and 1 or 0,
		(row.property_type == "Apartment") and 1 or 0
	}

	dataset:iput(features)
end, {schema = schema})

print("Filas cargadas:", dataset:len())

-- 3. SHUFFLE
dataset:shuffle()

-- 4. SPLIT
local n = dataset:len()
local split_idx = math.floor(n * SPLIT_RATIO)

local train = Table.new()
local test  = Table.new()

for i = 1, n do
	if i <= split_idx then
		train:iput(dataset[i])
	else
		test:iput(dataset[i])
	end
end

-- 5. CONVERT TO COLUMN FORMAT
local function to_columns(data)
	local cols = {
		log_price = {},
		accommodates = {},
		bathrooms = {},
		bedrooms = {},
		beds = {},
		reviews = {},
		rating = {},
		lat = {},
		lon = {},
		cleaning_fee = {},
		instant_bookable = {},
		host_verified = {},
		room_entire = {},
		room_private = {},
		room_shared = {},
		is_apartment = {}
	}

	for _, row in ipairs(data) do
		table.insert(cols.log_price, row[1])
		table.insert(cols.accommodates, row[2])
		table.insert(cols.bathrooms, row[3])
		table.insert(cols.bedrooms, row[4])
		table.insert(cols.beds, row[5])
		table.insert(cols.reviews, row[6])
		table.insert(cols.rating, row[7])
		table.insert(cols.lat, row[8])
		table.insert(cols.lon, row[9])
		table.insert(cols.cleaning_fee, row[10])
		table.insert(cols.instant_bookable, row[11])
		table.insert(cols.host_verified, row[12])
		table.insert(cols.room_entire, row[13])
		table.insert(cols.room_private, row[14])
		table.insert(cols.room_shared, row[15])
		table.insert(cols.is_apartment, row[16])
	end

	return cols
end

local train_cols = to_columns(train)
local test_cols  = to_columns(test)

-- 6. SAVE USING CSVFAST
csvfast.save_columns(train_cols, "data/train_final.csv")
csvfast.save_columns(test_cols,  "data/test_final.csv")

-- DONE
print("=================================")
print("Dataset procesado")
print("Train:", train:len())
print("Test :", test:len())
print("Archivos:")
print(" - data/train_final.csv")
print(" - data/test_final.csv")
print("=================================")]===]