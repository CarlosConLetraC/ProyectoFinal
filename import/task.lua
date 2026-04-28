local task = {}
local tasks = {}
local sleeping = {}
local line_counts = {}
local quota_exceeded = {}

local coroutine_running = coroutine.running
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_yield = coroutine.yield
local table_insert = table.insert
local ipairs, assert, error, unpack = ipairs, assert, error, unpack or table.unpack
local system_clock = (os_version == "Linux/UNIX" and system.clock) or os.clock

local ADJUST = (os_version == "Linux/UNIX" and math.exp(1)/4.7623) or 0
local LINE_QUOTA = 5000  -- number of lines before auto-yield

-- spawn a coroutine
function task.spawn(fn, ...)
	local co = coroutine_create(fn, ...)
	local lua_thr = {}
	lua_thr.co = co
	lua_thr.args = {...}
	lua_thr.sleeping = -1
	lua_thr.running = true

	table_insert(tasks, lua_thr)
	line_counts[lua_thr] = 0
	sleeping[co] = lua_thr

	return lua_thr
end

-- yield current coroutine for a number of seconds
function task.wait(seconds)
	local thr = coroutine_running()
	local co = assert(sleeping[thr] and thr, "task.wait() must be called inside a task.spawn coroutine.")
	sleeping[co].sleeping = (system_clock() + (seconds or 0)) + (ADJUST*(seconds or 0))
	return coroutine_yield()
end

--[[ mark quota exceeded safely (called by debug hook)
local function quota_hook()
	local co = coroutine_running()
	if co and line_counts[co] then
		line_counts[co] = line_counts[co] + 1
		if line_counts[co] >= LINE_QUOTA then
			quota_exceeded[co] = true
		end
	end
end]]
debug.sethook(function(...)
	local co = coroutine_running()
	if co and line_counts[co] then
		line_counts[co] = line_counts[co] + 1
		if line_counts[co] >= LINE_QUOTA then
			quota_exceeded[co] = true
		end
	end
end, "crl")

-- scheduler tick
function task.step()
	local alive = {}
	local hasQueues = false
	for _, lua_thr in ipairs(tasks) do
		lua_thr.running = coroutine_status(lua_thr.co) ~= "dead"
		hasQueues = true
		local wakeTime = sleeping[lua_thr.co].sleeping

		-- skip sleeping coroutines
		if wakeTime and system_clock() < wakeTime then
			table_insert(alive, lua_thr)
		else
			sleeping[lua_thr] = nil
			if coroutine_status(lua_thr.co) ~= "dead" then
				assert(coroutine_resume(lua_thr.co, unpack(lua_thr.args)))

				if quota_exceeded[lua_thr] then
					quota_exceeded[lua_thr] = nil
					line_counts[lua_thr] = 0
				end

				table_insert(alive, (lua_thr.running and lua_thr) or nil)
				--table_insert(alive, (coroutine_status(lua_thr.co) ~= "dead" and lua_thr) or nil)
			end
		end
	end
	tasks = alive
	return hasQueues
end

return task
