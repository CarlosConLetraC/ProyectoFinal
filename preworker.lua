import("csvfast", "Table")

-- CONFIG
local schema = {
	id = true,
	log_price = true,
	property_type = true,
	room_type = true,
	amenities = true,

	accommodates = true,
	bathrooms = true,
	bed_type = true,
	cancellation_policy = true,
	cleaning_fee = true,

	city = true,
	description = true,
	first_review = true,
	host_has_profile_pic = true,
	host_identity_verified = true,
	host_response_rate = true,
	host_since = true,
	instant_bookable = true,
	last_review = true,

	latitude = true,
	longitude = true,

	name = true,
	neighbourhood = true,

	number_of_reviews = true,
	review_scores_rating = true,

	thumbnail_url = true,
	zipcode = true,

	bedrooms = true,
	beds = true
}

-- UTILS
local function to_bool(v)
	if v == "t" or v == "true" or v == true then return 1 end
	return 0
end

local function clip(v, a, b)
	if v < a then return a end
	if v > b then return b end
	return v
end

local preworker = {}

function preworker.start(workerId, totalWorkers, base, prefix)

	-- reproducibilidad opcional
	math.randomseed(workerId * 1337)

	---------------------------------------------------
	-- MEAN IMPUTATION GLOBAL
	---------------------------------------------------
	local fields = {"bathrooms","bedrooms","beds","review_scores_rating"}
	local sum, count = {}, {}

	for _, f in ipairs(fields) do
		sum[f], count[f] = 0, 0
	end

	csvfast.each(base, function(r)
		for _, f in ipairs(fields) do
			local v = r[f]
			if v == v then
				sum[f] = sum[f] + v
				count[f] = count[f] + 1
			end
		end
	end, { schema = schema })

	local mean = {}
	for _, f in ipairs(fields) do
		mean[f] = (count[f] > 0) and (sum[f] / count[f]) or 0
	end

	---------------------------------------------------
	-- SHARD SPLIT (solo distribución, NO train/test)
	---------------------------------------------------
	local total = csvfast.count_rows(base)
	local chunk = math.floor(total / totalWorkers)

	local start = (workerId - 1) * chunk
	local limit = chunk

	if workerId == totalWorkers then
		limit = total - start
	end

	print(string.format("[Worker %d] start=%d limit=%d", workerId, start, limit))

	---------------------------------------------------
	-- DATASET LOCAL (SOLO TRAIN)
	---------------------------------------------------
	local train = Table.new()
	local idx = 0

	csvfast.each(base, function(r)

		-- shard filter
		if idx < start or idx >= start + limit then
			idx = idx + 1
			return
		end
		idx = idx + 1

		-- target
		local y = r.log_price
		if y ~= y then return end

		-- features base
		local acc = clip(r.accommodates or 0, 1, 10)

		local bath = r.bathrooms
		local bed  = r.bedrooms
		local beds = r.beds
		local rat  = r.review_scores_rating

		if bath ~= bath then bath = mean.bathrooms end
		if bed  ~= bed  then bed  = mean.bedrooms end
		if beds ~= beds then beds = mean.beds end
		if rat  ~= rat  then rat  = mean.review_scores_rating end

		bath = clip(bath, 0, 5)
		bed  = clip(bed, 0, 5)
		beds = clip(beds, 0, 10)
		rat  = clip(rat, 0, 100)

		---------------------------------------------------
		-- ROW FINAL
		---------------------------------------------------
		local row = {
			log_price = y,
			accommodates = acc,
			bathrooms = bath,
			bedrooms = bed,
			beds = beds,
			reviews = r.number_of_reviews or 0,
			rating = rat,
			lat = r.latitude,
			lon = r.longitude,
			cleaning_fee = to_bool(r.cleaning_fee),
			instant_bookable = to_bool(r.instant_bookable),
			host_verified = to_bool(r.host_identity_verified),
			room_entire = (r.room_type == "Entire home/apt") and 1 or 0,
			room_private = (r.room_type == "Private room") and 1 or 0,
			room_shared = (r.room_type == "Shared room") and 1 or 0,
			is_apartment = (r.property_type == "Apartment") and 1 or 0
		}

		train:iput(row)

	end, {
		schema = schema,
		start = start,
		limit = limit
	})

	print("[Worker "..workerId.."] train:", train:len())

	---------------------------------------------------
	-- EXPORT SOLO TRAIN
	---------------------------------------------------
	local function export(dataset, outprefix)

		local cols = {
			log_price={},accommodates={},bathrooms={},bedrooms={},beds={},
			reviews={},rating={},lat={},lon={},
			cleaning_fee={},instant_bookable={},host_verified={},
			room_entire={},room_private={},room_shared={},is_apartment={}
		}

		for i = 1, dataset:len() do
			local r = dataset[i]
			for k in pairs(cols) do
				cols[k][i] = r[k]
			end
		end

		csvfast.save_columns(cols, outprefix .. "_" .. workerId .. ".csv")
	end

	export(train, "data/dataset_train")

	print("[Worker "..workerId.."] EXPORT OK")
end

return preworker