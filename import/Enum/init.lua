local string_format = string.format
local string_gsub = string.gsub
local string_sub = string.sub
local string_len = string.len
local setmetatable, tostring = setmetatable, tostring

local Enum = {}
local EnumItems = {}
local EnumLibraryMT = {__type = "EnumLibrary"}
local EnumClassMT = {__type = "EnumClass"}
local EnumValueMT = {__type = "EnumValue"}

local ERROR_NOT_VALID_MEMBER = "'%s' is not a valid member of %s"
function EnumClassMT.__tostring(self)
	return "Enum."..self.Name
end
function EnumValueMT.__tostring(self)
	return "Enum."..self.EnumShared.."."..self.Name
end
function EnumClassMT.__index(self, index)
	return blund(self.EnumObject[index], string_format(ERROR_NOT_VALID_MEMBER, index, tostring(self)))
end
function EnumValueMT.__index(self, index)
	return blund(self.EnumObject[index], string_format(ERROR_NOT_VALID_MEMBER, index, tostring(self)))
end

--local fcmd = ((jit and jit.os == "Linux" or os.getenv("HOME")) and io.popen("ls -A ./daemons/Enum")) or ((jit and jit.os == "Windows") or not os.getenv("HOME")) and io.popen("dir /B .\\daemons\\Enum\\")
local fcmd = (os_version == "Windows" and io.popen("dir /B .\\import\\Enum\\")) or io.popen("ls -A ./import/Enum/")
local scmd = fcmd:read("*all")
fcmd:close()

local EnumCount = 0
string_gsub(scmd, "([^\n]*)\n", function(s)
	if string_sub(s, 1, 1) == "." or s == "init.lua" then return end
	local EnumName = string_sub(s, 1, string_len(s)-4)
	--rawset(Enum, EnumName, import("Enum/"..EnumName))
	Enum[EnumName] = import("Enum/"..EnumName)
	local EnumType = Enum[EnumName]

	EnumCount = EnumCount + 1
	local newEnumType = {
		Name = EnumName,
		Value = EnumCount,
		EnumType = EnumClassMT.__type,
		EnumObject = EnumType,
		EnumShared = Enum
	}
	EnumItems[EnumCount] = newEnumType

	for i, EnumSubName in ipairs(EnumType) do
		EnumCount = EnumCount + 1
		local newEnumValue = {
			Name = EnumSubName,
			Value = EnumCount,
			EnumType = EnumValueMT.__type,
			EnumObject = EnumCount,
			EnumShared = EnumName
		}
		EnumItems[EnumCount] = newEnumValue
		EnumType[EnumSubName] = newEnumValue
		EnumType[i] = nil
		setmetatable(newEnumValue, EnumValueMT)
	end

	setmetatable(newEnumType, EnumClassMT)
	Enum[EnumName] = newEnumType
end)

Enum.EnumItems = setmetatable({}, {
	__index = setmetatable({
		Load = function(_, _)
			return Table.clone(EnumItems, true)
		end
	}, {
		__index = function(self, index) return blund(EnumItems[index], string_format(ERROR_NOT_VALID_MEMBER, index, typeof(self))) end,
		__type = "EnumItems"
	}),
	__newindex = function(self, index, _) blund("Cannot create/redefine EnumItem manually.", 2) end,
	__tostring = function(_) return string_format("EnumItems<#%d>", rawlen(EnumItems)) end
})
setmetatable(Enum, EnumLibraryMT)

return Enum
