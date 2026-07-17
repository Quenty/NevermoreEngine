--!nonstrict
--[[
	@class TranslatorService.spec.lua

	Pins the *current* behavior of [TranslatorService] as exercised through a real
	ServiceBag.

	The behaviors pinned here matter for the upcoming replication refactor:
	  * GetLocalizationTable() lazily creates a *single* named table under
	    LocalizationService and caches it. The name is role-based
	    ("GeneratedJSONTable_Server" vs "GeneratedJSONTable_Client"), and a second,
	    independent service resolves to the same instance. That shared, replicated
	    table is the thing we are trying to stop over-replicating.
	  * GetLocaleId() resolves the current locale (RobloxLocaleId on a server with no
	    local player).
	  * PromiseTranslator() / GetTranslator() acquire the Roblox translator.

	The shared world (real ServiceBag + real TranslatorService, isolated per test) is
	built by [TranslatorTestUtils.setup]; see there for details.
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local LocalizationService = game:GetService("LocalizationService")

local Jest = require("Jest")
local TranslatorService = require("TranslatorService")
local TranslatorTestUtils = require("TranslatorTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local setup = TranslatorTestUtils.setup
local EXPECTED_TABLE_NAME = TranslatorTestUtils.EXPECTED_TABLE_NAME

describe("TranslatorService:GetLocalizationTable", function()
	it("creates a role-named LocalizationTable parented to LocalizationService", function()
		local controller = setup()

		local localizationTable = controller.translatorService:GetLocalizationTable()

		expect(localizationTable:IsA("LocalizationTable")).toBe(true)
		expect(localizationTable.Name).toBe(EXPECTED_TABLE_NAME)
		expect(localizationTable.Parent).toBe(LocalizationService)
		controller:destroy()
	end)

	it("caches the table so repeated calls return the same instance", function()
		local controller = setup()

		local first = controller.translatorService:GetLocalizationTable()
		local second = controller.translatorService:GetLocalizationTable()

		expect(second).toBe(first)
		controller:destroy()
	end)

	-- PIN: the generated table is a single shared instance keyed by name. A second,
	-- independent service finds the already-created table rather than making a new one.
	-- This is why writes replicate widely -- every translator shares this one table.
	it("resolves to the existing named table from a separate service instance", function()
		local controller = setup()

		local first = controller.translatorService:GetLocalizationTable()
		local second = controller.newTranslatorService():GetLocalizationTable()

		expect(second).toBe(first)
		controller:destroy()
	end)
end)

describe("TranslatorService._getLocalizationTableName", function()
	it("names the table by server/client role", function()
		local controller = setup()
		expect(TranslatorService._getLocalizationTableName({})).toBe(EXPECTED_TABLE_NAME)
		controller:destroy()
	end)
end)

describe("TranslatorService:GetLocaleId", function()
	it("resolves to RobloxLocaleId on a server with no local player", function()
		local controller = setup()
		-- With no LocalPlayer, the locale falls through to LocalizationService.RobloxLocaleId.
		expect(controller.translatorService:GetLocaleId()).toBe(LocalizationService.RobloxLocaleId)
		controller:destroy()
	end)
end)

describe("TranslatorService:GetTranslator / PromiseTranslator", function()
	it("acquires a Roblox translator", function()
		local controller = setup()

		local translator = controller.awaitTranslator()
		expect(typeof(translator)).toBe("Instance")
		expect(translator:IsA("Translator")).toBe(true)
		controller:destroy()
	end)

	it("exposes the acquired translator through GetTranslator", function()
		local controller = setup()

		local translator = controller.awaitTranslator()
		expect(controller.translatorService:GetTranslator()).toBe(translator)
		controller:destroy()
	end)

	it("resolves PromiseTranslator to the same translator on repeated calls", function()
		local controller = setup()

		expect(controller.awaitTranslator()).toBe(controller.awaitTranslator())
		controller:destroy()
	end)
end)

describe("TranslatorService entry writes (deferred)", function()
	it("resolves PromiseEntriesWritten immediately when nothing is pending", function()
		local controller = setup()
		expect(controller.translatorService:PromiseEntriesWritten():IsFulfilled()).toBe(true)
		controller:destroy()
	end)

	it("defers a SetEntryValue write until the flush", function()
		local controller = setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")

		-- Pending: not yet applied to the table.
		expect(#service:GetLocalizationTable():GetEntries()).toBe(0)
		expect(service:PromiseEntriesWritten():IsPending()).toBe(true)

		controller.awaitEntriesWritten()
		expect(#service:GetLocalizationTable():GetEntries()).toBe(1)
		controller:destroy()
	end)

	it("batches multiple writes into a single flush", function()
		local controller = setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx1", "en", "One")
		service:SetEntryValue("k.two", "Two", "ctx2", "en", "Two")
		service:SetEntryExample("k.one", "One", "ctx1", "One")

		expect(#service:GetLocalizationTable():GetEntries()).toBe(0)

		controller.awaitEntriesWritten()

		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(entries["k.one"]).never.toBeNil()
		expect(entries["k.two"]).never.toBeNil()
		controller:destroy()
	end)

	it("FlushEntries applies the pending writes synchronously", function()
		local controller = setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		controller.flushEntries()

		-- No yield needed; the entry is present immediately after the synchronous flush.
		expect(#service:GetLocalizationTable():GetEntries()).toBe(1)
		expect(service:PromiseEntriesWritten():IsFulfilled()).toBe(true)
		controller:destroy()
	end)
end)
