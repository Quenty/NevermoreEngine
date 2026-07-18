--!nonstrict
--[[
	Shared test helpers for the locale-loader specs.

	Builds a real world through `setup()`: a real ServiceBag with the real
	TranslatorService, plus factories that build the loaders against that bag. Loader
	writes land in the real (shared, role-named) LocalizationService table, which is
	cleared before and after every test for isolation, so tests assert on what actually
	reached the TranslatorService rather than on a stand-in recording writer.
	`controller:destroy()` tears the world down.

	@class LocaleLoaderTestUtils
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")

local InstanceLocaleLoader = require("InstanceLocaleLoader")
local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TableLocaleLoader = require("TableLocaleLoader")
local TieRealmService = require("TieRealmService")
local TranslatorService = require("TranslatorService")

local LocaleLoaderTestUtils = {}

-- Removes any generated tables so each test starts from a clean LocalizationService.
function LocaleLoaderTestUtils.clearGeneratedTables()
	for _, child in LocalizationService:GetChildren() do
		if child:IsA("LocalizationTable") and string.match(child.Name, "^GeneratedJSONTable_") then
			child:Destroy()
		end
	end
end

--[[
	Builds an isolated test world. Call once per test and pair with controller:destroy().

	`options.tieRealm` (a TieRealms value) injects the realm on the service bag, matching
	how the client-only paths are exercised on the server test runner.
]]
function LocaleLoaderTestUtils.setup(options)
	options = options or {}

	local maid = Maid.new()

	local function giveTask(item)
		maid:GiveTask(item)
		return item
	end

	LocaleLoaderTestUtils.clearGeneratedTables()

	local serviceBag = maid:Add(ServiceBag.new())
	if options.tieRealm then
		serviceBag:GetService(TieRealmService):SetTieRealm(options.tieRealm)
	end
	local translatorService = serviceBag:GetService(TranslatorService)
	serviceBag:Init()
	serviceBag:Start()

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

	-- Builds an InstanceLocaleLoader wired to the real TranslatorService via the bag.
	local function newInstanceLoader(jsonByLocale, sourceLocaleId)
		local folder = newInstanceFolder(jsonByLocale)
		return InstanceLocaleLoader.new(serviceBag, "T", sourceLocaleId or "en", folder), folder
	end

	-- Builds a TableLocaleLoader over an already-decoded in-memory table.
	local function newTableLoader(dataTable, localeId)
		local entries = LocalizationEntryParserUtils.decodeFromTable("T", localeId or "en", dataTable)
		return TableLocaleLoader.new(serviceBag, entries)
	end

	-- Flushes the deferred localization writes synchronously so the table can be read.
	local function flush()
		translatorService:FlushEntriesForTesting()
	end

	-- Reads the localization table back into a Key -> entry lookup for assertions.
	local function getEntryMap()
		local map = {}
		for _, entry in translatorService:GetLocalizationTable():GetEntries() do
			map[entry.Key] = entry
		end
		return map
	end

	-- The text written for a given key/locale, or nil if the key or locale is absent.
	local function valueFor(key, localeId)
		local entry = getEntryMap()[key]
		if not entry then
			return nil
		end
		return entry.Values[localeId]
	end

	-- True when no deferred writes are pending -- i.e. the last load queued nothing new.
	local function isIdle()
		return translatorService:PromiseEntriesWritten():IsFulfilled()
	end

	return {
		serviceBag = serviceBag,
		translatorService = translatorService,
		newInstanceLoader = newInstanceLoader,
		newInstanceFolder = newInstanceFolder,
		newTableLoader = newTableLoader,
		flush = flush,
		getEntryMap = getEntryMap,
		valueFor = valueFor,
		isIdle = isIdle,
		getWriteCount = function()
			return translatorService:GetLocalizationWriteCount()
		end,
		track = function(item)
			return giveTask(item)
		end,
		destroy = function()
			maid:DoCleaning()
			LocaleLoaderTestUtils.clearGeneratedTables()
		end,
	}
end

return LocaleLoaderTestUtils
