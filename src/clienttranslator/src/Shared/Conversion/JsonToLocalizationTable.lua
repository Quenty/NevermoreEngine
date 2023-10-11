--[=[
	Utility to build a localization table from json, intended to be used with rojo. Can also handle Rojo json
	objects turned into tables!

	@class JsonToLocalizationTable
]=]

local LocalizationService = game:GetService("LocalizationService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local JsonToLocalizationTable = {}

local LOCALIZATION_TABLE_NAME_CLIENT = "GeneratedJSONTable_Client"
local LOCALIZATION_TABLE_NAME_SERVER = "GeneratedJSONTable_Server"

--[[
	Recursively iterates through the object to construct strings and add it to the localization table

	@param localizationTable LocalizationTable
	@param localeId string -- The localizationid to add
	@param baseKey string -- the key to add
	@param object any -- The value to iterate over
]]
local function recurseAdd(localizationTable, localeId, baseKey, object, tableName)
	if baseKey ~= "" then
		baseKey = baseKey .. "."
	end

	for index, value in pairs(object) do
		local key = baseKey .. index
		if type(value) == "table" then
			recurseAdd(localizationTable, localeId, key, value, tableName)
		elseif type(value) == "string" then
			local source = ""

			-- Guarantee the context is unique. This is important because Roblox will not
			-- allow something with the same source without a differing context value.
			local context = tableName .. "." .. key

			if localeId == "en" then
				source = value
			end

			localizationTable:SetEntryValue(key, source, context, localeId, value)
		else
			error("Bad type for value in '" .. key .. "'.")
		end
	end
end

--[=[
	Extracts the locale from the name

	@param name string -- The name to parse
	@return string -- The locale
]=]
function JsonToLocalizationTable.localeFromName(name)
	if name:sub(-5) == ".json" then
		return name:sub(1, #name-5)
	else
		return name
	end
end

--[=[
	Gets or creates the global localization table. If the game isn't running (i.e. test mode), then
	we'll just not parent it.

	@return string -- The locale
]=]
function JsonToLocalizationTable.getOrCreateLocalizationTable()
	local localizationTableName
	if RunService:IsServer() then
		localizationTableName = LOCALIZATION_TABLE_NAME_SERVER
	else
		localizationTableName = LOCALIZATION_TABLE_NAME_CLIENT
	end

	local localizationTable = LocalizationService:FindFirstChild(localizationTableName)

	if not localizationTable then
		localizationTable = Instance.new("LocalizationTable")
		localizationTable.Name = localizationTableName

		if RunService:IsRunning() then
			localizationTable.Parent = LocalizationService
		end
	end

	return localizationTable
end

--[=[
	Loads a folder into a localization table.

	@param tableName string -- Used for source
	@param folder Folder -- A Roblox folder with StringValues containing JSON, named with the localization in mind
]=]
function JsonToLocalizationTable.loadFolder(tableName, folder)
	assert(type(tableName) == "string", "Bad tableName")

	local localizationTable = JsonToLocalizationTable.getOrCreateLocalizationTable()

	for _, item in pairs(folder:GetDescendants()) do
		if item:IsA("StringValue") then
			local localeId = JsonToLocalizationTable.localeFromName(item.Name)
			JsonToLocalizationTable.addJsonToTable(localizationTable, localeId, item.Value, tableName)
		elseif item:IsA("ModuleScript") then
			local localeId = JsonToLocalizationTable.localeFromName(item.Name)
			recurseAdd(localizationTable, localeId, "", require(item), tableName)
		end
	end
	return localizationTable
end

--[=[
	Extracts the locale from the folder, or a locale and table.

	@param tableName string -- Used for source
	@param first Instance | string
	@param second table?
	@return LocalizationTable
]=]
function JsonToLocalizationTable.toLocalizationTable(tableName, first, second)
	assert(type(tableName) == "string", "Bad tableName")

	if typeof(first) == "Instance" then
		local result = JsonToLocalizationTable.loadFolder(tableName, first)
		-- result.Name = ("JSONTable_%s"):format(first.Name)
		return result
	elseif type(first) == "string" and type(second) == "table" then
		local result = JsonToLocalizationTable.loadTable(tableName, first, second)
		return result
	else
		error("Bad args")
	end
end

--[=[
	Extracts the locale from the name

	@param tableName string -- Used for source
	@param localeId string -- the defaultlocaleId
	@param dataTable table -- Data table to load from
	@return LocalizationTable
]=]
function JsonToLocalizationTable.loadTable(tableName, localeId, dataTable)
	assert(type(tableName) == "string", "Bad tableName")

	local localizationTable = JsonToLocalizationTable.getOrCreateLocalizationTable()

	recurseAdd(localizationTable, localeId, "", dataTable, tableName)

	return localizationTable
end

--[=[
	Adds json to a localization table

	@param localizationTable LocalizationTable -- The localization table to add to
	@param localeId string -- The localeId to use
	@param json string -- The json to add with
	@param tableName string -- Used for source
]=]
function JsonToLocalizationTable.addJsonToTable(localizationTable, localeId, json, tableName)
	assert(type(tableName) == "string", "Bad tableName")

	local decodedTable = HttpService:JSONDecode(json)
	recurseAdd(localizationTable, localeId, "", decodedTable, tableName)
end

return JsonToLocalizationTable

