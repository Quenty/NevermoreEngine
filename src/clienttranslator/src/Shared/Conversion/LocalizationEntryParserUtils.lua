--[=[
	Utility to build a localization table from json, intended to be used with rojo. Can also handle Rojo json
	objects turned into tables!

	@class LocalizationEntryParserUtils
]=]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local require = require(script.Parent.loader).load(script)

local PseudoLocalize = require("PseudoLocalize")

local LocalizationEntryParserUtils = {}

function LocalizationEntryParserUtils.decodeFromInstance(tableName, sourceLocaleId, folder)
	assert(type(tableName) == "string", "Bad tableName")
	assert(typeof(folder) == "Instance", "Bad folder")

	local lookupTable = {}
	local baseKey = ""

	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("StringValue") then
			local localeId = LocalizationEntryParserUtils._parseLocaleFromName(descendant.Name)
			local decodedTable = HttpService:JSONDecode(descendant.Value)

			LocalizationEntryParserUtils._parseTableToResultsList(lookupTable, sourceLocaleId, localeId, baseKey, decodedTable, tableName)
		elseif descendant:IsA("ModuleScript") then
			local localeId = LocalizationEntryParserUtils._parseLocaleFromName(descendant.Name)
			local decodedTable = require(descendant)

			LocalizationEntryParserUtils._parseTableToResultsList(lookupTable, sourceLocaleId, localeId, baseKey, decodedTable, tableName)
		end
	end

	local results = {}
	for _, item in lookupTable do
		table.insert(results, item)
	end
	return results
end

function LocalizationEntryParserUtils.decodeFromTable(tableName, localeId, dataTable)
	assert(type(tableName) == "string", "Bad tableName")
	assert(type(localeId) == "string", "Bad localeId")
	assert(type(dataTable) == "table", "Bad dataTable")

	local lookupTable = {}

	local baseKey = ""
	LocalizationEntryParserUtils._parseTableToResultsList(
		lookupTable,
		localeId,
		localeId,
		baseKey,
		dataTable,
		tableName
	)

	local results = {}
	for _, item in lookupTable do
		table.insert(results, item)
	end
	return results
end

function LocalizationEntryParserUtils._parseLocaleFromName(name)
	if string.sub(name, -5) == ".json" then
		return string.sub(name, 1, #name-5)
	else
		return name
	end
end

function LocalizationEntryParserUtils._parseTableToResultsList(lookupTable, sourceLocaleId, localeId, baseKey, dataTable, tableName)
	assert(type(lookupTable) == "table", "Bad lookupTable")
	assert(type(sourceLocaleId) == "string", "Bad sourceLocaleId")
	assert(type(localeId) == "string", "Bad localeId")
	assert(type(baseKey) == "string", "Bad baseKey")
	assert(type(dataTable) == "table", "Bad dataTable")
	assert(type(tableName) == "string", "Bad tableName")

	for index, text in dataTable do
		local key = baseKey .. index
		if type(text) == "table" then
			LocalizationEntryParserUtils._parseTableToResultsList(lookupTable, sourceLocaleId, localeId, key .. ".", text, tableName)
		elseif type(text) == "string" then
			local found = lookupTable[key]
			if found then
				found.Values[localeId] = text
			else
				found = {
					Example = text;
					Key = key;
					Context = string.format("[TEMP] - Generated from %s with key %s", tableName, key);
					Source = text; -- Tempt!
					Values = {
						[localeId] = text;
					};
				}

				lookupTable[key] = found
			end

			-- Ensure assignment
			if sourceLocaleId == localeId then
				-- Guarantee the context is unique. This is important because Roblox will not
				-- allow something with the same source without a differing context text.
				found.Context = string.format("Generated from %s with key %s", tableName, key)
				found.Source = text

				if RunService:IsStudio() then
					found.Values[PseudoLocalize.getDefaultPseudoLocaleId()] = PseudoLocalize.pseudoLocalize(text)
				end
			end
		else
			error(string.format("Bad type for text at key '%s'", key))
		end
	end
end

return LocalizationEntryParserUtils