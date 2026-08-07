--!strict
--[[
	@class TranslatorService.spec.lua
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

		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(entries["k.one"].Values["en"]).toBe("One")
		expect(entries["k.two"]).toBeNil()
		expect(service:PromiseEntriesWritten():IsPending()).toBe(true)

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

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		service:SetEntryExample("k.one", "One", "c1", "One")
		service:SetEntryValue("k.two", "Two", "c2", "en", "Two")
		service:SetEntryExample("k.two", "Two", "c2", "Two")
		service:SetEntryValue("k.three", "Three", "c3", "en", "Three")
		service:SetEntryExample("k.three", "Three", "c3", "Three")

		controller.awaitEntriesWritten()

		expect(service:GetLocalizationWriteCount()).toBe(1)

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

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		service:SetEntryExample("k.one", "One", "c1", "One")
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(1)
		controller:destroy()
	end)

	it("does not queue a write the table already holds", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		service:SetEntryExample("k.one", "One", "c1", "One")
		controller.awaitEntriesWritten()

		-- Registering unchanged text is the common case (every label built through
		-- ObserveTranslation mints -- and so re-registers -- its key), so it has to be dropped
		-- before it queues: a queued write schedules a flush and takes the key not-ready, which
		-- drives a re-translation pass through every reader of it.
		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		service:SetEntryExample("k.one", "One", "c1", "One")

		expect(service:IsTranslationReady("k.one")).toBe(true)
		expect(service:PromiseEntriesWritten():IsPending()).toBe(false)
		controller:destroy()
	end)

	it("queues a write that changes only the source or context", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		controller.awaitEntriesWritten()

		service:SetEntryValue("k.one", "Uno", "c2", "en", "One")
		expect(service:IsTranslationReady("k.one")).toBe(false)
		controller.awaitEntriesWritten()

		local entry = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.one"]
		expect(entry.Source).toBe("Uno")
		expect(entry.Context).toBe("c2")
		expect(entry.Values["en"]).toBe("One")
		controller:destroy()
	end)

	it("reports an entry registered whatever context it was registered under", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		expect(service:IsEntryRegistered("k.one", "One", "en", "One")).toBe(false)

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		-- Mid-change: what the table holds now says nothing about what the flush will leave.
		expect(service:IsEntryRegistered("k.one", "One", "en", "One")).toBe(false)
		controller.awaitEntriesWritten()

		-- Registered under "c1", and there is no context to ask about: a caller minting a key it
		-- would describe differently is asking whether the entry is there, not whose it is.
		expect(service:IsEntryRegistered("k.one", "One", "en", "One")).toBe(true)

		-- Source and text still count. Both are what a reader sees.
		expect(service:IsEntryRegistered("k.one", "Uno", "en", "One")).toBe(false)
		expect(service:IsEntryRegistered("k.one", "One", "en", "Uno")).toBe(false)
		expect(service:IsEntryRegistered("k.one", "One", "fr", "One")).toBe(false)
		controller:destroy()
	end)

	it("writes when a queued entry changes an existing value", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "c1", "en", "One")
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(1)

		service:SetEntryValue("k.one", "One", "c1", "en", "Uno")
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(2)
		expect(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.one"].Values["en"]).toBe("Uno")
		controller:destroy()
	end)
end)

describe("TranslatorService write cost while streaming in", function()
	-- Unbatched, each registration below is its own table write; batched, the count has to
	-- stay flat as the entry count grows.
	local function countWritesForEntries(entryCount: number): (number, any)
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		for index = 1, entryCount do
			local key = string.format("streamed.key%d", index)
			service:SetEntryValue(key, key, string.format("ctx%d", index), "en", key)
			service:SetEntryExample(key, key, string.format("ctx%d", index), key)
		end

		controller.awaitEntriesWritten()

		local writeCount = service:GetLocalizationWriteCount()
		local lastEntry =
			TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())[string.format("streamed.key%d", entryCount)]

		controller:destroy()
		return writeCount, lastEntry
	end

	it("costs one table write regardless of how many entries register in the frame", function()
		local fewWrites, fewLastEntry = countWritesForEntries(10)
		local manyWrites, manyLastEntry = countWritesForEntries(500)

		expect(fewWrites).toBe(1)
		expect(manyWrites).toBe(1)
		expect(fewLastEntry.Values["en"]).toBe("streamed.key10")
		expect(manyLastEntry.Values["en"]).toBe("streamed.key500")
	end)

	it("costs one table write when many translators register in the same frame", function()
		local controller = TranslatorTestUtils.setup()

		local defs = {}
		for index = 1, 25 do
			table.insert(defs, {
				name = string.format("Translator%d", index),
				data = { [string.format("pkg%d", index)] = { one = "One", two = "Two" } },
			})
		end

		local service = controller.newPackageServiceBag(defs :: { { name: string, data: any } })
		controller.awaitEntriesWritten(service)

		expect(service:GetLocalizationWriteCount()).toBe(1)
		expect(Table.count(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable()))).toBe(50)
		controller:destroy()
	end)

	it("lands a later handful of keys without rebuilding the whole table", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		for index = 1, 400 do
			local key = string.format("streamed.key%d", index)
			service:SetEntryValue(key, key, string.format("ctx%d", index), "en", key)
		end
		controller.awaitEntriesWritten()
		expect(service:GetLocalizationRebuildCount()).toBe(1)

		-- The load rebuilt the table once, which is right. A UI opening afterwards registers a
		-- couple of keys into that same 400-entry table, and rebuilding it again for two keys
		-- costs re-serializing all 400 -- so those land as targeted writes instead.
		service:SetEntryValue("late.one", "Late one", "lc1", "en", "Late one")
		service:SetEntryValue("late.two", "Late two", "lc2", "en", "Late two")
		controller.awaitEntriesWritten()

		expect(service:GetLocalizationRebuildCount()).toBe(1)
		expect(service:GetLocalizationWriteCount()).toBe(3)

		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(entries["late.one"].Values["en"]).toBe("Late one")
		expect(entries["late.two"].Values["en"]).toBe("Late two")
		-- The targeted writes must not have cost the entries already in the table.
		expect(entries["streamed.key1"].Values["en"]).toBe("streamed.key1")
		expect(entries["streamed.key400"].Values["en"]).toBe("streamed.key400")
		controller:destroy()
	end)

	it("rebuilds rather than writing hundreds of entries one at a time", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		for index = 1, 50 do
			local key = string.format("streamed.key%d", index)
			service:SetEntryValue(key, key, string.format("ctx%d", index), "en", key)
		end
		controller.awaitEntriesWritten()

		-- A batch large next to the table it writes into goes the other way: each targeted
		-- write invalidates the engine's cached contents just as hard as a rebuild does, so
		-- hundreds of them cost hundreds of invalidations to save one re-serialization.
		for index = 1, 300 do
			local key = string.format("later.key%d", index)
			service:SetEntryValue(key, key, string.format("lctx%d", index), "en", key)
		end
		controller.awaitEntriesWritten()

		expect(service:GetLocalizationWriteCount()).toBe(2)
		expect(service:GetLocalizationRebuildCount()).toBe(2)
		expect(Table.count(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable()))).toBe(350)
		controller:destroy()
	end)

	it("keeps a synchronous read from flushing the rest of the batch", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		for index = 1, 100 do
			local key = string.format("streamed.key%d", index)
			service:SetEntryValue(key, key, string.format("ctx%d", index), "en", key)
		end

		service:FlushEntryForKey("streamed.key1")

		-- The read lands its own key's locales and nothing else, so the batch survives to be
		-- coalesced into the single end-of-frame write. Landing a locale dequeues it, so the
		-- repeated read locales cost nothing and this is exactly one write.
		local writesAfterRead = service:GetLocalizationWriteCount()
		expect(writesAfterRead).toBe(1)
		expect(service:IsTranslationReady("streamed.key100")).toBe(false)

		controller.awaitEntriesWritten()
		expect(service:GetLocalizationWriteCount()).toBe(writesAfterRead + 1)
		controller:destroy()
	end)
end)

describe("TranslatorService entry merging", function()
	it("coalesces three translators initializing together into one write with no drops", function()
		local controller = TranslatorTestUtils.setup()

		local service = controller.newPackageServiceBag({
			{ name = "AlphaTranslator", data = { alpha = { one = "A1", two = "A2" } } },
			{ name = "BetaTranslator", data = { beta = "B" } },
			{ name = "GammaTranslator", data = { gamma = { deep = "G" } } },
		} :: { { name: string, data: any } })

		controller.awaitEntriesWritten(service)

		expect(service:GetLocalizationWriteCount()).toBe(1)

		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		expect(Table.count(entries)).toBe(4)
		expect(entries["alpha.one"].Values["en"]).toBe("A1")
		expect(entries["alpha.two"].Values["en"]).toBe("A2")
		expect(entries["beta"].Values["en"]).toBe("B")
		expect(entries["gamma.deep"].Values["en"]).toBe("G")
		controller:destroy()
	end)

	-- A LocalizationTable keys its entries by translation key alone. SetEntries rejects two
	-- entries that share a key even when their source/context differ, throwing
	-- "Entry at index N has the same (key) or (key,source,context) tuple as another entry".
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

		controller.awaitEntriesWritten()

		local entries = service:GetLocalizationTable():GetEntries()
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

		service:SetEntryValue("k.one", "One", "ctx-b", "en", "Uno")
		controller.awaitEntriesWritten()

		local matching = 0
		for _, entry in service:GetLocalizationTable():GetEntries() do
			if entry.Key == "k.one" then
				matching += 1
			end
		end
		expect(matching).toBe(1)

		-- The new metadata has to land with the value. A targeted write would have kept the old
		-- source and context (see "SetEntryValue leaves an existing entry's source and context
		-- alone") while the mirror recorded the new ones, so this batch takes the rebuild.
		local entry = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.one"]
		expect(entry.Values["en"]).toBe("Uno")
		expect(entry.Context).toBe("ctx-b")
		controller:destroy()
	end)

	it("preserves entries written directly to the table by an external writer", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService
		local localizationTable = service:GetLocalizationTable()

		localizationTable:SetEntryValue("external.key", "External", "extctx", "en", "External")

		service:SetEntryValue("internal.key", "Internal", "intctx", "en", "Internal")
		controller.awaitEntriesWritten()

		local entries = TranslatorTestUtils.getEntryMap(localizationTable)
		expect(entries["external.key"].Values["en"]).toBe("External")
		expect(entries["internal.key"].Values["en"]).toBe("Internal")
		expect(service:GetLocalizationWriteCount()).toBe(1)
		controller:destroy()
	end)

	-- The service mirrors the table's contents rather than reading it back per flush, so an
	-- entry written behind that mirror is one a rebuild could drop: a rebuild writes the whole
	-- entry list back. The rebuild path reads the table first for exactly this reason.
	it("preserves an entry written directly to the table after the mirror was built", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService
		local localizationTable = service:GetLocalizationTable()

		-- Builds the mirror, so the write below lands behind it rather than in front of it.
		service:SetEntryValue("internal.one", "Internal one", "intctx", "en", "Internal one")
		controller.awaitEntriesWritten()

		localizationTable:SetEntryValue("external.key", "External", "extctx", "en", "External")

		-- A batch large next to the table it writes into rebuilds rather than landing targeted
		-- writes, so this is the flush that writes the whole list back.
		for index = 1, 50 do
			local key = string.format("internal.key%d", index)
			service:SetEntryValue(key, key, string.format("ctx%d", index), "en", key)
		end
		controller.awaitEntriesWritten()
		-- The first flush landed its one entry as a targeted write, so this is the first rebuild.
		expect(service:GetLocalizationRebuildCount()).toBe(1)

		local entries = TranslatorTestUtils.getEntryMap(localizationTable)
		expect(entries["external.key"].Values["en"]).toBe("External")
		expect(entries["internal.one"].Values["en"]).toBe("Internal one")
		expect(entries["internal.key50"].Values["en"]).toBe("internal.key50")
		expect(Table.count(entries)).toBe(52)
		controller:destroy()
	end)
end)

-- The batched flush lands small batches as targeted SetEntryValue/SetEntryExample calls
-- rather than rebuilding the table, which means trusting those calls to leave the rest of the
-- entry alone. Nothing in the package would notice if they stopped: the mirror would simply
-- disagree with the table from then on, and a write it thinks is redundant is dropped. So the
-- assumptions are pinned here, against the engine, not against the service.
--
-- The third assumption -- that SetEntryValue overwrites source/context in place -- is written
-- up in docs/engine-behavior.md and pinned by "queues a write that changes only the source or
-- context" above.
describe("LocalizationTable behavior the targeted writes rest on", function()
	it("SetEntryValue leaves the entry's example alone", function()
		local localizationTable = Instance.new("LocalizationTable")

		localizationTable:SetEntryValue("k.one", "One", "ctx", "en", "One")
		localizationTable:SetEntryExample("k.one", "One", "ctx", "An example")
		localizationTable:SetEntryValue("k.one", "One", "ctx", "fr", "Un")

		local entry = TranslatorTestUtils.getEntryMap(localizationTable)["k.one"]
		expect(entry.Example).toBe("An example")
		expect(entry.Values["en"]).toBe("One")
		expect(entry.Values["fr"]).toBe("Un")
		localizationTable:Destroy()
	end)

	it("SetEntryValue leaves an existing entry's source and context alone", function()
		local localizationTable = Instance.new("LocalizationTable")

		localizationTable:SetEntryValue("k.one", "One", "ctx-a", "en", "One")

		-- Even though this call does change the value: on an entry that already exists the
		-- source and context are matched against, not written. So there is no targeted call that
		-- lands metadata at all, and a batch that changes any has to go through SetEntries --
		-- see the merge in TranslatorService._mergePendingEntries.
		localizationTable:SetEntryValue("k.one", "Uno", "ctx-b", "en", "Uno")

		local entries = localizationTable:GetEntries()
		expect(#entries).toBe(1)
		expect(entries[1].Source).toBe("One")
		expect(entries[1].Context).toBe("ctx-a")
		expect(entries[1].Values["en"]).toBe("Uno")
		localizationTable:Destroy()
	end)

	it("SetEntryExample leaves the entry's values alone", function()
		local localizationTable = Instance.new("LocalizationTable")

		localizationTable:SetEntryValue("k.one", "One", "ctx", "en", "One")
		localizationTable:SetEntryValue("k.one", "One", "ctx", "fr", "Un")
		localizationTable:SetEntryExample("k.one", "One", "ctx", "An example")

		local entry = TranslatorTestUtils.getEntryMap(localizationTable)["k.one"]
		expect(entry.Values["en"]).toBe("One")
		expect(entry.Values["fr"]).toBe("Un")
		expect(entry.Example).toBe("An example")
		localizationTable:Destroy()
	end)
end)
