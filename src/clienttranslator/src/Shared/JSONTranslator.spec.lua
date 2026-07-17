--!nonstrict
--[[
	@class JSONTranslator.spec.lua

	Pins the *current* behavior of [JSONTranslator]. These tests are intentionally
	behavior-pinning (characterization) tests: they document how the translator
	writes into a Roblox LocalizationTable today, so that an upcoming refactor
	(deferring/centralizing those writes to avoid replicating megabytes of
	localization data) can be validated against a known baseline.

	Notable behaviors pinned here that the refactor is expected to change:
	  * :Init() eagerly writes *every* entry (value + example) into the
	    localization table up-front. This is the write amplification we want to defer.
	  * :ToTranslationKey() has a side effect: it writes an "en" entry every time
	    it is called (see its `-- TODO: Only set if we don't need it`).
	  * :SetEntryValue() writes straight through to the localization table.

	The translator is exercised against a real (unparented) LocalizationTable and a
	lightweight fake TranslatorService so we can assert on exactly what gets written
	without touching LocalizationService or the cloud translator pipeline.
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local HttpService = game:GetService("HttpService")

local JSONTranslator = require("JSONTranslator")
local Jest = require("Jest")
local Maid = require("Maid")
local Promise = require("Promise")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local beforeEach = Jest.Globals.beforeEach
local afterEach = Jest.Globals.afterEach

-- Tracks everything created during a single test so we can tear it down cleanly.
local testMaid

beforeEach(function()
	testMaid = Maid.new()
end)

afterEach(function()
	testMaid:DoCleaning()
	testMaid = nil
end)

--[[
	A minimal stand-in for TranslatorService exposing only the surface that
	JSONTranslator consumes. Locale id and cloud translator are settable so tests
	can drive translation code paths deterministically.
]]
local function createFakeTranslatorService(localizationTable)
	local localeId = ValueObject.new("en", "string")
	local translator = ValueObject.new(nil)

	local service = {}

	function service.GetLocalizationTable()
		return localizationTable
	end

	function service.ObserveLocaleId()
		return localeId:Observe()
	end

	function service.GetLocaleId()
		return localeId.Value
	end

	function service.ObserveTranslator()
		return translator:Observe()
	end

	function service.GetTranslator()
		return translator.Value
	end

	function service.PromiseTranslator()
		if translator.Value then
			return Promise.resolved(translator.Value)
		end
		return Promise.new()
	end

	-- Test-only setters
	function service.SetLocaleId(_self, newLocaleId)
		localeId.Value = newLocaleId
	end

	function service.SetTranslator(_self, newTranslator)
		translator.Value = newTranslator
	end

	function service.Destroy()
		localeId:Destroy()
		translator:Destroy()
	end

	return service
end

-- A fake ServiceBag whose only job is to hand JSONTranslator our fake service.
local function createFakeServiceBag(translatorService)
	return {
		GetService = function(_self, _serviceType)
			return translatorService
		end,
	}
end

-- Builds an initialized translator wired to a fresh, unparented localization table.
local function makeTranslator(dataTable, localeId)
	local localizationTable = Instance.new("LocalizationTable")
	local fakeService = createFakeTranslatorService(localizationTable)

	local translator = JSONTranslator.new("TestTranslator", localeId or "en", dataTable)
	translator:Init(createFakeServiceBag(fakeService))

	testMaid:GiveTask(function()
		translator:Destroy()
		fakeService:Destroy()
		localizationTable:Destroy()
	end)

	return translator, localizationTable, fakeService
end

-- Reads back the localization table into a Key -> entry lookup for assertions.
local function getEntryMap(localizationTable)
	local map = {}
	for _, entry in localizationTable:GetEntries() do
		map[entry.Key] = entry
	end
	return map
end

local function countKeys(map)
	local count = 0
	for _ in map do
		count += 1
	end
	return count
end

describe("JSONTranslator.new", function()
	it("exposes the expected class identity", function()
		expect(JSONTranslator.ClassName).toBe("JSONTranslator")
	end)

	it("sets ServiceName to the translator name so it registers uniquely", function()
		local translator = JSONTranslator.new("MyTranslator", "en", {})
		expect(translator.ServiceName).toBe("MyTranslator")
	end)

	it("decodes entries from a (localeId, dataTable) pair in the constructor", function()
		-- Decoding happens in the constructor (into _entries); writing to a table is deferred to Init.
		local translator = JSONTranslator.new("TestTranslator", "en", {
			actions = {
				respawn = "Respawn {playerName}",
			},
		})

		local keys = {}
		for _, entry in translator._entries do
			keys[entry.Key] = entry.Values["en"]
		end
		expect(keys["actions.respawn"]).toBe("Respawn {playerName}")
	end)

	it("decodes entries from an Instance folder of StringValues", function()
		local folder = Instance.new("Folder")
		testMaid:GiveTask(folder)

		local en = Instance.new("StringValue")
		en.Name = "en.json"
		en.Value = HttpService:JSONEncode({ hello = "Hello" })
		en.Parent = folder

		local localizationTable = Instance.new("LocalizationTable")
		testMaid:GiveTask(localizationTable)

		local translator = JSONTranslator.new("TestTranslator", folder)
		translator:Init(createFakeServiceBag(createFakeTranslatorService(localizationTable)))
		testMaid:GiveTask(function()
			translator:Destroy()
		end)

		local entries = getEntryMap(localizationTable)
		expect(entries["hello"]).never.toBeNil()
		expect(entries["hello"].Values["en"]).toBe("Hello")
	end)

	it("errors when translatorName is not a string", function()
		expect(function()
			JSONTranslator.new(123 :: any, "en", {})
		end).toThrow()
	end)

	it("errors when neither an (localeId, dataTable) pair nor an Instance is given", function()
		expect(function()
			JSONTranslator.new("TestTranslator", "en", "not a table" :: any)
		end).toThrow()
	end)
end)

describe("JSONTranslator:Init eager writes", function()
	-- PIN: Init writes the entire decoded table into the localization table immediately.
	-- This up-front write is exactly the replication/loading cost the refactor targets.
	it("writes every decoded entry into the localization table during Init", function()
		local _translator, localizationTable = makeTranslator({
			actions = {
				respawn = "Respawn {playerName}",
				jump = "Jump",
			},
			greeting = "Hello there",
		})

		local entries = getEntryMap(localizationTable)
		expect(countKeys(entries)).toBe(3)
		expect(entries["actions.respawn"]).never.toBeNil()
		expect(entries["actions.jump"]).never.toBeNil()
		expect(entries["greeting"]).never.toBeNil()
	end)

	it("writes source, context, value and example for each entry", function()
		local _translator, localizationTable = makeTranslator({
			greeting = "Hello there",
		})

		local entry = getEntryMap(localizationTable)["greeting"]
		expect(entry).never.toBeNil()
		expect(entry.Source).toBe("Hello there")
		expect(entry.Values["en"]).toBe("Hello there")
		expect(entry.Example).toBe("Hello there")
		-- Context is generated deterministically from the translator name and key.
		expect(entry.Context).toBe("Generated from TestTranslator with key greeting")
	end)

	it("does not write before Init runs (writes are an Init side effect, not a new() side effect)", function()
		local localizationTable = Instance.new("LocalizationTable")
		testMaid:GiveTask(localizationTable)

		local translator = JSONTranslator.new("TestTranslator", "en", { greeting = "Hi" })
		expect(#localizationTable:GetEntries()).toBe(0)

		translator:Init(createFakeServiceBag(createFakeTranslatorService(localizationTable)))
		testMaid:GiveTask(function()
			translator:Destroy()
		end)

		expect(#localizationTable:GetEntries()).toBe(1)
	end)
end)

describe("JSONTranslator:SetEntryValue", function()
	it("writes the value straight through to the localization table", function()
		local translator, localizationTable = makeTranslator({})

		translator:SetEntryValue("some.key", "Source", "context", "en", "Translated")

		local entry = getEntryMap(localizationTable)["some.key"]
		expect(entry).never.toBeNil()
		expect(entry.Source).toBe("Source")
		expect(entry.Context).toBe("context")
		expect(entry.Values["en"]).toBe("Translated")
	end)

	it("validates its arguments", function()
		local translator = makeTranslator({})

		expect(function()
			translator:SetEntryValue(1 :: any, "s", "c", "en", "t")
		end).toThrow()
		expect(function()
			translator:SetEntryValue("k", "s", "c", "en", nil :: any)
		end).toThrow()
	end)

	-- PIN: outside of Studio, only the requested locale is written (no pseudo-localization).
	it("writes only the requested locale outside of Studio", function()
		local translator, localizationTable = makeTranslator({})

		translator:SetEntryValue("some.key", "Source", "context", "en", "Translated")

		local entry = getEntryMap(localizationTable)["some.key"]
		local localeCount = 0
		for _ in entry.Values do
			localeCount += 1
		end
		expect(localeCount).toBe(1)
	end)
end)

describe("JSONTranslator:ToTranslationKey", function()
	it("derives a stable translation key from a prefix and text", function()
		-- Text is lower-camel-cased (spaces are word boundaries) and capped at 20 chars.
		local translator = makeTranslator({})
		expect(translator:ToTranslationKey("button", "Play Now")).toBe("button.playNow")
	end)

	-- PIN: ToTranslationKey has a write side effect (its own TODO calls this out).
	-- The refactor should be able to make this lazy, so this test documents the status quo.
	it("writes an 'en' entry into the localization table as a side effect", function()
		local translator, localizationTable = makeTranslator({})

		expect(#localizationTable:GetEntries()).toBe(0)

		local key = translator:ToTranslationKey("button", "Play Now")

		local entry = getEntryMap(localizationTable)[key]
		expect(entry).never.toBeNil()
		expect(entry.Values["en"]).toBe("Play Now")
		expect(entry.Source).toBe("Play Now")
	end)
end)

describe("JSONTranslator:GetLocalizationTable / GetLocaleId", function()
	it("returns the localization table provided by the translator service", function()
		local translator, localizationTable = makeTranslator({})
		expect(translator:GetLocalizationTable()).toBe(localizationTable)
	end)

	it("delegates GetLocaleId to the translator service", function()
		local translator, _localizationTable, fakeService = makeTranslator({})
		expect(translator:GetLocaleId()).toBe("en")

		fakeService:SetLocaleId("fr-fr")
		expect(translator:GetLocaleId()).toBe("fr-fr")
	end)
end)

describe("JSONTranslator:FormatByKey", function()
	it("errors when the cloud translator has not been acquired yet", function()
		local translator = makeTranslator({ greeting = "Hello there" })
		expect(function()
			translator:FormatByKey("greeting")
		end).toThrow()
	end)

	it("formats using the acquired translator, substituting args", function()
		local translator, localizationTable, fakeService = makeTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		})

		-- Provide a real translator built from the now-populated table.
		fakeService:SetTranslator(localizationTable:GetTranslator("en"))

		expect(translator:FormatByKey("actions.respawn", { playerName = "Quenty" })).toBe("Respawn Quenty")
	end)

	it("falls back to the key itself when the key is missing", function()
		local translator, localizationTable, fakeService = makeTranslator({ greeting = "Hi" })
		fakeService:SetTranslator(localizationTable:GetTranslator("en"))

		expect(translator:FormatByKey("does.not.exist")).toBe("does.not.exist")
	end)
end)

describe("JSONTranslator:ObserveFormatByKey", function()
	it("emits a translation using the local translator when no cloud translator exists", function()
		local translator = makeTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		})

		local received
		testMaid:GiveTask(
			translator:ObserveFormatByKey("actions.respawn", { playerName = "Quenty" }):Subscribe(function(text)
				received = text
			end)
		)

		expect(received).toBe("Respawn Quenty")
	end)

	it("re-emits when the args observable changes", function()
		local translator = makeTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		})

		local name = ValueObject.new("Quenty", "string")
		testMaid:GiveTask(name)

		local received
		testMaid:GiveTask(
			translator:ObserveFormatByKey("actions.respawn", { playerName = name:Observe() }):Subscribe(function(text)
				received = text
			end)
		)

		expect(received).toBe("Respawn Quenty")

		name.Value = "James"
		expect(received).toBe("Respawn James")
	end)

	it("requires a string translation key", function()
		local translator = makeTranslator({})
		expect(function()
			translator:ObserveFormatByKey(5 :: any)
		end).toThrow()
	end)
end)

describe("JSONTranslator:Destroy", function()
	it("tears down its maid and unsets its metatable", function()
		local localizationTable = Instance.new("LocalizationTable")
		testMaid:GiveTask(localizationTable)

		local translator = JSONTranslator.new("TestTranslator", "en", { greeting = "Hi" })
		translator:Init(createFakeServiceBag(createFakeTranslatorService(localizationTable)))

		translator:Destroy()

		-- After Destroy the metatable is stripped, so method access is gone.
		expect(getmetatable(translator)).toBeNil()
	end)
end)
