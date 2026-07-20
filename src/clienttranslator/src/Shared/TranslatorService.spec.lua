--!strict
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
	built by [TranslatorTestUtils.TranslatorTestUtils.setup]; see there for details.
]]

local require = require(script.Parent.loader).load(script)

local LocalizationService = game:GetService("LocalizationService")

local Jest = require("Jest")
local Table = require("Table")
local TieRealms = require("TieRealms")
local TranslatorTestUtils = require("TranslatorTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("TranslatorService:GetLocalizationTable", function()
	it("creates a role-named LocalizationTable parented to LocalizationService", function()
		local controller = TranslatorTestUtils.setup()

		local localizationTable = controller.translatorService:GetLocalizationTable()

		expect(localizationTable:IsA("LocalizationTable")).toBe(true)
		expect(localizationTable.Name).toBe(TranslatorTestUtils.EXPECTED_TABLE_NAME)
		expect(localizationTable.Parent).toBe(LocalizationService)
		controller:destroy()
	end)

	it("caches the table so repeated calls return the same instance", function()
		local controller = TranslatorTestUtils.setup()

		local first = controller.translatorService:GetLocalizationTable()
		local second = controller.translatorService:GetLocalizationTable()

		expect(second).toBe(first)
		controller:destroy()
	end)

	it("resolves to the existing named table from a separate service instance", function()
		local controller = TranslatorTestUtils.setup()

		local first = controller.translatorService:GetLocalizationTable()
		local second = controller.newTranslatorService():GetLocalizationTable()

		expect(second).toBe(first)
		controller:destroy()
	end)
end)

describe("TranslatorService._getLocalizationTableName", function()
	it("names the table by server/client role", function()
		local controller = TranslatorTestUtils.setup()
		expect(controller.translatorService:_getLocalizationTableName()).toBe(TranslatorTestUtils.EXPECTED_TABLE_NAME)
		controller:destroy()
	end)

	it("uses the client table when the realm is injected as client", function()
		local controller = TranslatorTestUtils.setup({ tieRealm = TieRealms.CLIENT })
		expect(controller.translatorService:GetLocalizationTable().Name).toBe("GeneratedJSONTable_Client")
		controller:destroy()
	end)
end)

describe("TranslatorService forced locale", function()
	it("overrides GetLocaleId when a locale is forced", function()
		local controller = TranslatorTestUtils.setup()
		controller.translatorService:SetForcedLocaleId("de-de")
		expect(controller.translatorService:GetLocaleId()).toBe("de-de")
		controller:destroy()
	end)

	it("reverts to the inferred locale when the override is cleared", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetForcedLocaleId("de-de")
		service:SetForcedLocaleId(nil)

		expect(service:GetLocaleId()).toBe(LocalizationService.RobloxLocaleId)
		controller:destroy()
	end)

	it("emits the forced locale from ObserveLocaleId", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService
		service:SetForcedLocaleId("de-de")

		local received
		controller.track(service:ObserveLocaleId():Subscribe(function(localeId)
			received = localeId
		end))

		expect(received).toBe("de-de")
		controller:destroy()
	end)
end)

describe("TranslatorService:GetLocaleId", function()
	it("resolves to RobloxLocaleId on a server with no local player", function()
		local controller = TranslatorTestUtils.setup()
		-- With no LocalPlayer, the locale falls through to LocalizationService.RobloxLocaleId.
		expect(controller.translatorService:GetLocaleId()).toBe(LocalizationService.RobloxLocaleId)
		controller:destroy()
	end)
end)

describe("TranslatorService:GetTranslator / PromiseTranslator", function()
	it("acquires a Roblox translator", function()
		local controller = TranslatorTestUtils.setup()

		local translator = controller.awaitTranslator()
		expect(typeof(translator)).toBe("Instance")
		expect(translator:IsA("Translator")).toBe(true)
		controller:destroy()
	end)

	it("exposes the acquired translator through GetTranslator", function()
		local controller = TranslatorTestUtils.setup()

		local translator = controller.awaitTranslator()
		expect(controller.translatorService:GetTranslator()).toBe(translator)
		controller:destroy()
	end)

	it("resolves PromiseTranslator to the same translator on repeated calls", function()
		local controller = TranslatorTestUtils.setup()

		expect(controller.awaitTranslator()).toBe(controller.awaitTranslator())
		controller:destroy()
	end)
end)

describe("TranslatorService entry writes (deferred)", function()
	it("resolves PromiseEntriesWritten immediately when nothing is pending", function()
		local controller = TranslatorTestUtils.setup()
		expect(controller.translatorService:PromiseEntriesWritten():IsFulfilled()).toBe(true)
		controller:destroy()
	end)

	it("defers a SetEntryValue write until the flush", function()
		local controller = TranslatorTestUtils.setup()
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
		local controller = TranslatorTestUtils.setup()
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

	it("FlushEntriesForTesting applies the pending writes synchronously", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		controller.flushEntries()

		-- No yield needed; the entry is present immediately after the synchronous flush.
		expect(#service:GetLocalizationTable():GetEntries()).toBe(1)
		expect(service:PromiseEntriesWritten():IsFulfilled()).toBe(true)
		controller:destroy()
	end)
end)

describe("TranslatorService:FlushEntryForKey", function()
	it("lands only the requested key, leaving the rest of the batch pending", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx1", "en", "One")
		service:SetEntryValue("k.two", "Two", "ctx2", "en", "Two")

		service:FlushEntryForKey("k.one")

		-- The requested key landed; the other is still queued for the deferred flush.
		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(entries["k.one"].Values["en"]).toBe("One")
		expect(entries["k.two"]).toBeNil()
		expect(service:PromiseEntriesWritten():IsPending()).toBe(true)

		-- The still-pending key lands on the normal end-of-frame flush.
		controller.awaitEntriesWritten()
		expect(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.two"].Values["en"]).toBe("Two")
		controller:destroy()
	end)

	it("is a no-op when nothing is pending", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		controller.awaitEntriesWritten()
		local writesAfterFlush = service:GetLocalizationWriteCount()

		-- Nothing queued, so there is nothing to land and no extra write happens.
		service:FlushEntryForKey("k.one")
		expect(service:GetLocalizationWriteCount()).toBe(writesAfterFlush)
		controller:destroy()
	end)
end)

describe("TranslatorService localization write cost", function()
	-- Each raw write to a LocalizationTable invalidates every AutoLocalize entry in the
	-- engine, so the number of writes per flush is what we minimize: a whole frame's worth
	-- of queued values/examples is coalesced into a single SetEntries call.
	it("coalesces a batch of value and example writes into a single table write", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		-- Three entries, each with one locale value plus an example (six queued writes).
		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		service:SetEntryExample("k.one", "One", "c1", "One")
		service:SetEntryValue("k.two", "Two", "c2", "en", "Two")
		service:SetEntryExample("k.two", "Two", "c2", "Two")
		service:SetEntryValue("k.three", "Three", "c3", "en", "Three")
		service:SetEntryExample("k.three", "Three", "c3", "Three")

		controller.awaitEntriesWritten()

		-- One write for the whole batch, so one AutoLocalize invalidation instead of six.
		expect(service:GetLocalizationWriteCount()).toBe(1)

		-- The entries still land correctly.
		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(entries["k.one"].Values["en"]).toBe("One")
		expect(entries["k.one"].Example).toBe("One")
		expect(entries["k.two"].Values["en"]).toBe("Two")
		expect(entries["k.three"].Values["en"]).toBe("Three")
		controller:destroy()
	end)

	it("merges a later write into the existing entries without dropping them", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		controller.awaitEntriesWritten()

		-- A second, separate flush should preserve the first entry and add the new one.
		service:SetEntryValue("k.two", "Two", "c2", "en", "Two")
		controller.awaitEntriesWritten()

		expect(service:GetLocalizationWriteCount()).toBe(2)
		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(entries["k.one"].Values["en"]).toBe("One")
		expect(entries["k.two"].Values["en"]).toBe("Two")
		controller:destroy()
	end)

	it("does not write when a queued entry already matches the table", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		service:SetEntryExample("k.one", "One", "c1", "One")
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(1)

		-- Re-queue the identical entry: no net change, so no write and no invalidation.
		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		service:SetEntryExample("k.one", "One", "c1", "One")
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(1)
		controller:destroy()
	end)

	it("writes when a queued entry changes an existing value", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(1)

		-- A genuinely different value must still write.
		service:SetEntryValue("k.one", "One", "c1", "en", "Uno")
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(2)
		expect(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.one"].Values["en"]).toBe("Uno")
		controller:destroy()
	end)
end)

describe("TranslatorService entry merging", function()
	-- The common package-driven case: several translators register on one ServiceBag and
	-- initialize together. Their entries must all land, merged, in a single write.
	it("coalesces three translators initializing together into one write with no drops", function()
		local controller = TranslatorTestUtils.setup()

		local service = controller.newPackageServiceBag({
			{ name = "AlphaTranslator", data = { alpha = { one = "A1", two = "A2" } } },
			{ name = "BetaTranslator", data = { beta = "B" } },
			{ name = "GammaTranslator", data = { gamma = { deep = "G" } } },
		} :: { { name: string, data: any } })

		controller.awaitEntriesWritten(service)

		-- All three translators' entries flushed together as a single SetEntries.
		expect(service:GetLocalizationWriteCount()).toBe(1)

		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(Table.count(entries)).toBe(4)
		expect(entries["alpha.one"].Values["en"]).toBe("A1")
		expect(entries["alpha.two"].Values["en"]).toBe("A2")
		expect(entries["beta"].Values["en"]).toBe("B")
		expect(entries["gamma.deep"].Values["en"]).toBe("G")
		controller:destroy()
	end)

	-- Regression: a LocalizationTable keys its entries by translation key alone. SetEntries
	-- rejects two entries that share a key even when their source/context differ, throwing
	-- "Entry at index N has the same (key) or (key,source,context) tuple as another entry".
	-- The deferred writer used to queue one entry per (key, source, context), so two writes
	-- for the same key with different source/context fed SetEntries a duplicate key and blew
	-- up the flush. Seen in the wild: "collectable.toolUnlocked" written both as a collectable
	-- name and again "Generated from DialogLineLocalization with key collectable.toolUnlocked".
	it("collapses two writes for one key with differing source/context into a single entry", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local key = "collectable.toolUnlocked"
		service:SetEntryValue(key, "Tool unlocked!", "Generated from a collectable name", "en", "Tool unlocked!")
		service:SetEntryValue(
			key,
			"Tool unlocked!",
			"Generated from DialogLineLocalization with key collectable.toolUnlocked",
			"en",
			"Tool unlocked!"
		)

		-- Before the fix this flush threw inside SetEntries (duplicate key) and never resolved.
		controller.awaitEntriesWritten()

		local entries = service:GetLocalizationTable():GetEntries()
		-- Exactly one entry lands for the key -- the second write overwrote the first in place.
		local matching = 0
		for _, entry in entries do
			if entry.Key == key then
				matching += 1
			end
		end
		expect(matching).toBe(1)
		expect(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())[key].Values["en"]).toBe("Tool unlocked!")
		controller:destroy()
	end)

	it("rewrites a key with a new source/context across flushes without duplicating it", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx-a", "en", "One")
		controller.awaitEntriesWritten()

		-- A later flush re-registers the same key under a different source/context. The table
		-- still holds a single entry for the key rather than crashing on a duplicate.
		service:SetEntryValue("k.one", "One", "ctx-b", "en", "Uno")
		controller.awaitEntriesWritten()

		local matching = 0
		for _, entry in service:GetLocalizationTable():GetEntries() do
			if entry.Key == "k.one" then
				matching += 1
			end
		end
		expect(matching).toBe(1)
		expect(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.one"].Values["en"]).toBe("Uno")
		controller:destroy()
	end)

	it("preserves entries written directly to the table by an external writer", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService
		local localizationTable = service:GetLocalizationTable()

		-- External writer mutates the table directly, not through the service.
		localizationTable:SetEntryValue("external.key", "External", "extctx", "en", "External")

		-- Internal writer goes through the service and triggers a merged flush.
		service:SetEntryValue("internal.key", "Internal", "intctx", "en", "Internal")
		controller.awaitEntriesWritten()

		local entries = TranslatorTestUtils.getEntryMap(localizationTable)
		-- The external entry survives the SetEntries merge rather than being clobbered.
		expect(entries["external.key"].Values["en"]).toBe("External")
		expect(entries["internal.key"].Values["en"]).toBe("Internal")
		expect(service:GetLocalizationWriteCount()).toBe(1)
		controller:destroy()
	end)
end)
