--- Utility to build a localization table from json, intended to be used with rojo. Can also handle Rojo json
-- objects turned into tables!
-- @module JsonToLocalizationTable

local HttpService = game:GetService("HttpService")

local JsonToLocalizationTable = {}

--- Recursively iterates through the object to construct strings and add it to the localization table
-- @param localeId The localizationid to add
-- @param baseKey the key to add
-- @param object The value to iterate over
local function recurseAdd(localizationTable, localeId, baseKey, object)
	if baseKey ~= "" then
		baseKey = baseKey .. "."
	end

	for index, value in pairs(object) do
		local key = baseKey .. index
		if type(value) == "table" then
			recurseAdd(localizationTable, localeId, key, value)
		elseif type(value) == "string" then
			local source = ""
			local context = ""

			if localeId == "en" then
				source = value
			end

			localizationTable:SetEntryValue(key, source, context, localeId, value)
		else
			error("Bad type for value in '" .. key .. "'.")
		end
	end
end

--- Extracts the locale from the name
-- @param name The name to parse
-- @return The locale
function JsonToLocalizationTable.localeFromName(name)
	if name:sub(-5) == ".json" then
		return name:sub(1, #name-5)
	else
		return name
	end
end

--- Loads a folder into a localization table
-- @parm folder A Roblox folder with StringValues containing JSON, named with the localization in mind
function JsonToLocalizationTable.loadFolder(folder)
	local localizationTable = Instance.new("LocalizationTable")
	for _, item in pairs(folder:GetDescendants()) do
		if item:IsA("StringValue") then
			local localeId = JsonToLocalizationTable.localeFromName(item.Name)
			JsonToLocalizationTable.addJsonToTable(localizationTable, localeId, item.Value)
		elseif item:IsA("ModuleScript") then
			local localeId = JsonToLocalizationTable.localeFromName(item.Name)
			recurseAdd(localizationTable, localeId, "", require(item))
		end
	end
	return localizationTable
end

--- Adds json to a localization table
-- @param localizationTable The localization table to add to
-- @param localeId The localeId to use
-- @param json The json to add with
function JsonToLocalizationTable.addJsonToTable(localizationTable, localeId, json)
	local decodedTable = HttpService:JSONDecode(json)
	recurseAdd(localizationTable, localeId, "", decodedTable)
end

return JsonToLocalizationTable

