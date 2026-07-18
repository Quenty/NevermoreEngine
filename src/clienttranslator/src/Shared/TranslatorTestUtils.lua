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

local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local JSONTranslator = require("JSONTranslator")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
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

	`options.tieRealm` (a TieRealms value) injects the realm on the service bag, exactly
	like the Raven stories do, so client-only behavior can be exercised on the server test
	runner.
]]
function TranslatorTestUtils.setup(options)
	options = options or {}

	local maid = Maid.new()

	local function giveTask(item)
		maid:GiveTask(item)
		return item
	end

	TranslatorTestUtils.clearGeneratedTables()

	local function newTranslatorService(tieRealm)
		local serviceBag = maid:Add(ServiceBag.new())
		if tieRealm then
			serviceBag:GetService(TieRealmService):SetTieRealm(tieRealm)
		end
		serviceBag:GetService(TranslatorService)
		serviceBag:Init()
		serviceBag:Start()
		return serviceBag:GetService(TranslatorService), serviceBag
	end

	local translatorService, serviceBag = newTranslatorService(options.tieRealm)

	-- Builds a fresh ServiceBag and registers translators the package-driven way
	-- (serviceBag:GetService(translator) before Init/Start, exactly how games wire up
	-- their JSONTranslators), then returns that bag's shared TranslatorService.
	local function newPackageServiceBag(defs, tieRealm)
		local bag = maid:Add(ServiceBag.new())
		if tieRealm then
			bag:GetService(TieRealmService):SetTieRealm(tieRealm)
		end
		for _, def in defs do
			bag:GetService(JSONTranslator.new(def.name, def.localeId or "en", def.data))
		end
		bag:Init()
		bag:Start()
		return bag:GetService(TranslatorService)
	end

	-- Builds a Folder of per-locale StringValues (named "<locale>.json") whose values are
	-- the JSON-encoded tables, matching the instance-decoded translator layout.
	local function newInstanceFolder(jsonByLocale)
		local folder = giveTask(Instance.new("Folder"))
		for localeId, dataTable in jsonByLocale do
			local stringValue = Instance.new("StringValue")
			stringValue.Name = localeId .. ".json"
			stringValue.Value = HttpService:JSONEncode(dataTable)
			stringValue.Parent = folder
		end
		return folder
	end

	-- Creates a JSONTranslator initialized against the real service bag. The translator
	-- is initialized directly (like a service consuming it during its own Init) rather
	-- than registered on the bag, which is already started.
	local function newTranslator(dataTable, localeId)
		local translator = JSONTranslator.new("TestTranslator", localeId or "en", dataTable)
		translator:Init(serviceBag)
		giveTask(function()
			if translator.Destroy then
				translator:Destroy()
			end
		end)
		return translator
	end

	local function newTranslatorFromInstance(folder)
		local translator = JSONTranslator.new("TestTranslator", folder)
		translator:Init(serviceBag)
		giveTask(function()
			if translator.Destroy then
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

	-- Waits for the given (or default) service's deferred localization writes to flush.
	local function awaitEntriesWritten(service)
		local ok = (service or translatorService):PromiseEntriesWritten():Yield()
		assert(ok, "Entries were never written")
	end

	-- Flushes the deferred localization writes synchronously.
	local function flushEntries()
		translatorService:FlushEntriesForTesting()
	end

	return {
		serviceBag = serviceBag,
		translatorService = translatorService,
		newTranslatorService = function()
			return (newTranslatorService())
		end,
		newTranslator = newTranslator,
		newTranslatorFromInstance = newTranslatorFromInstance,
		newPackageServiceBag = newPackageServiceBag,
		newInstanceFolder = newInstanceFolder,
		awaitLoaded = awaitLoaded,
		awaitTranslator = awaitTranslator,
		awaitEntriesWritten = awaitEntriesWritten,
		flushEntries = flushEntries,
		setForcedLocaleId = function(localeId)
			translatorService:SetForcedLocaleId(localeId)
		end,
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
