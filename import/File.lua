import("system")
--local string_find = string.find
local Table = Table or import("Table")
local Table_clone = Table.clone
local table_insert = table.insert
local os_remove = os.remove
local os_rename = os.rename

local getmetatable, setmetatable = getmetatable, setmetatable

local cache = {}
local File = {}
local fileMT = {__type = "file", __index = {}}
local idxMT = {
	__index=function(self, idx)
		error(tostring(idx).." is not a valid member of file.")
	end
}

local modes = {}
--[[
	tag "modes.source" types:
		0: unknow (private?)
		1: read only
		2: modify only
		3: read and modify
]]

modes.source = {["r"] = 1, ["rb"] = 1, ["w"] = 2, ["wb"] = 2, ["rw"] = 3, ["wr"] = 3}
-- aliases for "read and write binary-mode":
modes.source["rwb"] = 3
modes.source["brw"] = 3
modes.source["wbr"] = 3
modes.source["wrb"] = 3
modes.source["bwr"] = 3
modes.source["rbw"] = 3
setmetatable(modes.source, {__index = function(self, idx) error("unknown mode '"..tostring(idx).."' for \"modes.source\".", 3) end})

function fileMT.__tostring(self)
	return Table.ftostring("<file: "..self.name..">")
end

function fileMT.__newindex(self, what, value)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	local mt = getmetatable(self)
	local allone = assert(modes[what] and modes[what][mt.__allow[what]], tostring(what) .. " is not a valid member of file.")
	assert(allone > 1, "Cannot modify a read-only file.")
	mt.__index[what] = value
	return self
end

function fileMT.__index.destroy(self)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	assert(os_remove(self.name))
	local mt = getmetatable(self)
	local tidx = mt.__index
	rawset(tidx, "destroyed", true)
	return self.destroyed
end

function fileMT.__index.write(self, src, ignoreNewLine)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	local mt = getmetatable(self)
	local tsrc = mt.__allow
	local nsrc = modes.source[tsrc.source]
	
	if nsrc > 1 then
		self.source = self.source .. tostring(src) .. (ignoreNewLine and "" or "\n")
		if self.autosave then return self:save() and self.source end
		return self.source
	end

	error("Cannot write-file on " .. tsrc.source .. " mode.", 2)
end

function fileMT.__index.clear(self)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	local mt = getmetatable(self)
	local tsrc = mt.__allow
	local nsrc = modes.source[tsrc.source]
	
	if nsrc > 1 then
		self.source = ""
		if self.autosave then return self:save() end
		return true
	end

	return false, "read-only file"
end

function fileMT.__index.read(self)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	local mt = getmetatable(self)
	local tsrc = mt.__allow
	local nsrc = modes.source[tsrc.source]
	
	if nsrc == 1 or nsrc == 3 then
		if self.autosave then self:save() end
		return self.source
	end

	error("Cannot read-file on " .. tsrc.source .. " mode.", 2)
end

function fileMT.__index.save(self)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	local mt = getmetatable(self)
	local tsrc = mt.__allow
	local nsrc = modes.source[tsrc.source]

	local ok, err = blund(system.writefile(self.name, self.source, "wb+"))
	return true
end

function fileMT.__index.rename(self, newPath)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	assert(type(newPath) == "string", "File:rename() expects a string path.")
	local ok, err = os_rename(self.name, newPath)
	if not ok then error("Rename failed: " .. tostring(err), 2) end
	getmetatable(self).__index.name = newPath
	return self
end

function fileMT.__index.appendLine(self, line)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")

	local f = io_open(self.name, "a")
	blund(f, "Cannot open file.")

	f:write(line .. "\n")
	return f:close()
end

function fileMT.__index.appendLineSafe(self, line)
	assert(typeof(self) == "file", "Instance self-invoke must inherit from type 'file'.")
	local mt = getmetatable(self)

	while mt.__lock do task.wait(0) end
	mt.__lock = true

	local f = io.open(self.name, "a")
	assert(f, "Cannot open file.")

	f:write(line .. "\n")
	local a = f:close()

	mt.__lock = false
	return a
end

function File.new(pathName, mode, autosave)
	local newFile = {}
	local newMT = Table_clone(fileMT, true)
	mode = mode or "r"

	newMT.__allow = {
		["source"] = blund(modes.source[mode] and mode, "File: invalid mode")
	}
	newMT.__index = setmetatable({
		autosave = autosave == true,
		source = system.readfile(pathName) or system.writefile(pathName, "") and "",
		name = pathName,
		status = "appended",
		destroyed = false,
		__lock = false
	}, idxMT)

	for k, v in pairs(fileMT.__index) do
		rawset(newMT.__index, k, v)
	end

	setmetatable(newFile, newMT)
	table_insert(cache, newFile)
	return newFile
end

return File
