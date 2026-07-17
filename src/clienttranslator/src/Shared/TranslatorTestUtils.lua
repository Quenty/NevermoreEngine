--!nonstrict
--[[
	Shared test helpers for the clienttranslator specs.

	Builds a real world through `setup()`: a real ServiceBag with the real
	TranslatorService, translator factories initialized against it, and await
	helpers for the (async) Roblox translator. Writes land in the real (shared,
	role-named) LocalizationService table, which is cleared before and after every
	test for isolation. `controller:destroy()` tears the world down.

	@class TranslatorTestUtils
]]

local require = require(script.Parent.loader).load(script)

local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local JSONTranslator = require("JSONTranslator")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TranslatorService = require("TranslatorService")

local TranslatorTestUtils = {}

-- The name TranslatorService.GetLocalizationTable uses in the current run context.
TranslatorTestUtils.EXPECTED_TABLE_NAME = if RunService:IsServer()
	then "GeneratedJSONTable_Server"
	else "GeneratedJSONTable_Client"

-- Reads a localization table back into a Key -> entry lookup for assertions.
function TranslatorTestUtils.getEntryMap(localizationTable)
	local map = {}
	for _, entry in localizationTable:GetEntries() do
		map[entry.Key] = entry
	end
	return map
end

-- Removes any generated tables so each test starts from a clean LocalizationService.
function TranslatorTestUtils.clearGeneratedTables()
	for _, child in LocalizationService:GetChildren() do
		if child:IsA("LocalizationTable") and string.match(child.Name, "^GeneratedJSONTable_") then
			child:Destroy()
		end
	end
end

--[[
	Builds an isolated test world. Call once per test and pair with controller:destroy().
]]
function TranslatorTestUtils.setup()
	local maid = Maid.new()

	local function giveTask(item)
		maid:GiveTask(item)
		return item
	end

	TranslatorTestUtils.clearGeneratedTables()

	local function newTranslatorService()
		local serviceBag = maid:Add(ServiceBag.new())
		serviceBag:GetService(TranslatorService)
		serviceBag:Init()
		serviceBag:Start()
		return serviceBag:GetService(TranslatorService), serviceBag
	end

	local translatorService, serviceBag = newTranslatorService()

	-- Creates a JSONTranslator initialized against the real service bag. The translator
	-- is initialized directly (like a service consuming it during its own Init) rather
	-- than registered on the bag, which is already started.
	local function newTranslator(dataTable, localeId)
		local translator = JSONTranslator.new("TestTranslator", localeId or "en", dataTable)
		translator:Init(serviceBag)
		giveTask(function()
			if getmetatable(translator) then
				translator:Destroy()
			end
		end)
		return translator
	end

	local function newTranslatorFromInstance(folder)
		local translator = JSONTranslator.new("TestTranslator", folder)
		translator:Init(serviceBag)
		giveTask(function()
			if getmetatable(translator) then
				translator:Destroy()
			end
		end)
		return translator
	end

	-- Waits for the Roblox translator to be acquired, so FormatByKey has something to use.
	local function awaitLoaded(translator)
		local ok = translator:PromiseLoaded():Yield()
		assert(ok, "Translator was never loaded")
		return translator
	end

	-- Waits for the given (or default) service's Roblox translator to be acquired.
	local function awaitTranslator(service)
		local ok, translator = (service or translatorService):PromiseTranslator():Yield()
		assert(ok, "Translator was never acquired")
		return translator
	end

	-- Waits for the deferred localization writes to flush to the table.
	local function awaitEntriesWritten()
		local ok = translatorService:PromiseEntriesWritten():Yield()
		assert(ok, "Entries were never written")
	end

	-- Flushes the deferred localization writes synchronously.
	local function flushEntries()
		translatorService:FlushEntries()
	end

	return {
		serviceBag = serviceBag,
		translatorService = translatorService,
		newTranslatorService = function()
			return (newTranslatorService())
		end,
		newTranslator = newTranslator,
		newTranslatorFromInstance = newTranslatorFromInstance,
		awaitLoaded = awaitLoaded,
		awaitTranslator = awaitTranslator,
		awaitEntriesWritten = awaitEntriesWritten,
		flushEntries = flushEntries,
		getLocalizationTable = function()
			return translatorService:GetLocalizationTable()
		end,
		track = function(item)
			return giveTask(item)
		end,
		destroy = function()
			maid:DoCleaning()
			TranslatorTestUtils.clearGeneratedTables()
		end,
	}
end

return TranslatorTestUtils
