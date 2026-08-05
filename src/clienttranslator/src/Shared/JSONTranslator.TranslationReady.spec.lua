--!strict
--[[
	@class JSONTranslatorTranslationReady.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TieRealms = require("TieRealms")
local TranslatorTestUtils = require("TranslatorTestUtils")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setupClientTranslator(jsonByLocale)
	local controller = TranslatorTestUtils.setup({ tieRealm = TieRealms.CLIENT })
	controller.setForcedLocaleId("en")

	local folder = controller.newInstanceFolder(jsonByLocale)
	local translator = controller.newTranslatorFromInstance(folder)

	return controller, translator
end

-- Records emissions in order. nil is a meaningful emission here (a key that is not readable
-- yet), so it is recorded as "<nil>" rather than leaving a hole in the array.
local function collect(controller, observable)
	local received = {}
	local count = 0

	controller.track(observable:Subscribe(function(value)
		count += 1
		if value == nil then
			received[count] = "<nil>"
		else
			received[count] = value
		end
	end))

	return received
end

describe("JSONTranslator:_observeTranslationReady", function()
	it("emits nil while the key is queued, then the locale it is readable for", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })

		local received = collect(controller, translator:_observeTranslationReady("greeting"))
		expect(received).toEqual({ "<nil>" })

		controller.awaitEntriesWritten()
		expect(received).toEqual({ "<nil>", "en-us" })
		controller:destroy()
	end)

	it("emits the locale immediately for a key whose writes already landed", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })
		controller.awaitEntriesWritten()

		expect(collect(controller, translator:_observeTranslationReady("greeting"))).toEqual({ "en-us" })
		controller:destroy()
	end)

	it("emits immediately for a key nothing ever registered", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })
		controller.awaitEntriesWritten()

		expect(collect(controller, translator:_observeTranslationReady("never.registered"))).toEqual({ "en-us" })
		controller:destroy()
	end)

	it("re-emits for the new locale when the locale swaps", function()
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:_observeTranslationReady("greeting"))
		expect(received).toEqual({ "en" })

		controller.setForcedLocaleId("fr")
		task.wait()

		expect(received).toEqual({ "en", "<nil>", "fr" })
		controller:destroy()
	end)

	it("emits without waiting when swapping back to an already loaded locale", function()
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})
		controller.setForcedLocaleId("fr")
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:_observeTranslationReady("greeting"))
		expect(received).toEqual({ "fr" })

		controller.setForcedLocaleId("en")
		expect(received).toEqual({ "fr", "en" })
		controller:destroy()
	end)

	it("does not write to the localization table while observing a queued key", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello", farewell = "Bye" })

		local writesBefore = controller.translatorService:GetLocalizationWriteCount()
		collect(controller, translator:_observeTranslationReady("greeting"))
		collect(controller, translator:_observeTranslationReady("farewell"))

		expect(controller.translatorService:GetLocalizationWriteCount()).toBe(writesBefore)
		expect(controller.translatorService:IsTranslationReady("greeting")).toBe(false)
		controller:destroy()
	end)

	it("requires a string translation key", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello" })

		expect(function()
			translator:_observeTranslationReady(5 :: any)
		end).toThrow()
		controller:destroy()
	end)
end)

describe("TranslatorService:IsTranslationReady", function()
	it("is false while a key is queued and true once the batch lands", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		expect(service:IsTranslationReady("k.one")).toBe(false)

		controller.awaitEntriesWritten()
		expect(service:IsTranslationReady("k.one")).toBe(true)
		controller:destroy()
	end)

	it("is true for a key nothing ever queued", function()
		local controller = TranslatorTestUtils.setup()

		expect(controller.translatorService:IsTranslationReady("never.registered")).toBe(true)
		controller:destroy()
	end)

	it("stays false until the flush, even after a single-key read landed its locales", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		service:FlushEntryForKey("k.one")
		expect(service:IsTranslationReady("k.one")).toBe(false)

		controller.awaitEntriesWritten()
		expect(service:IsTranslationReady("k.one")).toBe(true)
		controller:destroy()
	end)
end)

describe("TranslatorService:ObserveIsTranslationReady", function()
	it("emits the current state immediately", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")

		expect(collect(controller, service:ObserveIsTranslationReady("k.one"))).toEqual({ false })
		controller:destroy()
	end)

	it("emits false when a key is queued after subscribing, then true on the flush", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local received = collect(controller, service:ObserveIsTranslationReady("k.one"))
		expect(received).toEqual({ true })

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		expect(received).toEqual({ true, false })

		controller.awaitEntriesWritten()
		expect(received).toEqual({ true, false, true })
		controller:destroy()
	end)

	-- A write the table already holds never gets queued at all (TranslatorService.spec.lua,
	-- "does not queue a write the table already holds"), so the way a key reaches the flush
	-- with nothing left to write is a single-key read landing its value first. The key is in
	-- the table either way, and a key that never went ready would strand its readers.
	it("fires ready even when the flush found nothing left to write", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		local received = collect(controller, service:ObserveIsTranslationReady("k.one"))
		expect(received).toEqual({ false })

		-- Lands the value and dequeues that locale, leaving the entry queued for the flush.
		service:FlushEntryForKey("k.one")
		local writesAfterRead = service:GetLocalizationWriteCount()

		controller.awaitEntriesWritten()

		expect(received).toEqual({ false, true })
		expect(service:GetLocalizationWriteCount()).toBe(writesAfterRead)
		controller:destroy()
	end)

	it("serves multiple observers of the same key independently", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local first = {}
		local firstSub = service:ObserveIsTranslationReady("k.one"):Subscribe(function(value)
			table.insert(first, value)
		end)
		local second = collect(controller, service:ObserveIsTranslationReady("k.one"))

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		expect(first).toEqual({ true, false })
		expect(second).toEqual({ true, false })

		firstSub:Destroy()
		controller.awaitEntriesWritten()

		expect(first).toEqual({ true, false })
		expect(second).toEqual({ true, false, true })
		controller:destroy()
	end)

	it("stops emitting to an observer that left before the flush", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local received = {}
		local sub = service:ObserveIsTranslationReady("k.one"):Subscribe(function(isReady)
			table.insert(received, isReady)
		end)
		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		expect(received).toEqual({ true, false })

		sub:Destroy()
		controller.awaitEntriesWritten()

		expect(received).toEqual({ true, false })
		expect(service:IsTranslationReady("k.one")).toBe(true)
		controller:destroy()
	end)

	it("reports not-ready only once the queued value is stored and the flush is scheduled", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local seen = {}
		controller.track(service:ObserveIsTranslationReady("k.one"):Subscribe(function(isReady)
			if not isReady then
				table.insert(seen, {
					pendingFlush = service:PromiseEntriesWritten():IsPending(),
					isReady = service:IsTranslationReady("k.one"),
				})
			end
		end))

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")

		expect(#seen).toBe(1)
		expect(seen[1].pendingFlush).toBe(true)
		expect(seen[1].isReady).toBe(false)
		controller:destroy()
	end)
end)

describe("TranslatorService readiness re-entrancy", function()
	it("resolves the flush promise its own batch belongs to when a handler queues more", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		local firstFlush = service:PromiseEntriesWritten()

		controller.track(service:ObserveIsTranslationReady("k.one"):Subscribe(function(isReady)
			if isReady then
				service:SetEntryValue("k.two", "Two", "ctx", "en", "Two")
			end
		end))

		controller.awaitEntriesWritten()

		expect(firstFlush:IsFulfilled()).toBe(true)
		expect(service:PromiseEntriesWritten():IsPending()).toBe(true)

		controller.awaitEntriesWritten()
		expect(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.two"].Values["en"]).toBe("Two")
		controller:destroy()
	end)

	it("never reports a key ready while it is pending again, whatever order the batch fires in", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local keys = {}
		for index = 1, 10 do
			local key = string.format("k.%d", index)
			table.insert(keys, key)
			service:SetEntryValue(key, key, "ctx", "en", "first")
		end

		-- Whichever key the fan-out reaches first re-queues every other key, so the rest are
		-- pending again before their own turn comes regardless of iteration order.
		local disagreements = 0
		local requeued = false
		for _, key in keys do
			controller.track(service:ObserveIsTranslationReady(key):Subscribe(function(isReady)
				if isReady and not service:IsTranslationReady(key) then
					disagreements += 1
				end

				if isReady and not requeued then
					requeued = true
					for _, otherKey in keys do
						if otherKey ~= key then
							service:SetEntryValue(otherKey, otherKey, "ctx", "en", "second")
						end
					end
				end
			end))
		end

		controller.awaitEntriesWritten()
		controller.awaitEntriesWritten()

		expect(disagreements).toBe(0)
		expect(requeued).toBe(true)

		-- Every key except whichever one the fan-out happened to reach first was re-queued,
		-- and all of those second writes landed.
		local entries = TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())
		local rewritten = 0
		for _, key in keys do
			if entries[key].Values["en"] == "second" then
				rewritten += 1
			end
		end
		expect(rewritten).toBe(#keys - 1)
		controller:destroy()
	end)

	it("tells every surviving observer when a handler unsubscribes itself and a later one", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")

		local told = {}
		local subscriptions: { [number]: any } = {}
		for index = 1, 4 do
			subscriptions[index] =
				controller.track(service:ObserveIsTranslationReady("k.one"):Subscribe(function(isReady)
					if not isReady then
						return
					end

					told[index] = true

					-- Tearing itself and a sibling down from inside a handler is ordinary UI
					-- behavior, and must not cost the untouched observers their emission.
					if index == 1 then
						subscriptions[1]:Destroy()
						subscriptions[2]:Destroy()
					end
				end))
		end

		controller.awaitEntriesWritten()

		expect(told[1]).toBe(true)
		expect(told[2]).toBeNil()
		expect(told[3]).toBe(true)
		expect(told[4]).toBe(true)
		controller:destroy()
	end)

	it("tells a later observer the truth when an earlier one re-queued the key", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en-us", "first")

		local requeued = false
		controller.track(service:ObserveIsTranslationReady("k.one"):Subscribe(function(isReady)
			if isReady and not requeued then
				requeued = true
				service:SetEntryValue("k.one", "One", "ctx", "en-us", "second")
			end
		end))

		local disagreements = 0
		local received = {}
		controller.track(service:ObserveIsTranslationReady("k.one"):Subscribe(function(isReady)
			table.insert(received, isReady)
			if isReady ~= service:IsTranslationReady("k.one") then
				disagreements += 1
			end
		end))

		controller.awaitEntriesWritten()
		controller.awaitEntriesWritten()

		expect(requeued).toBe(true)
		expect(disagreements).toBe(0)
		expect(received[#received]).toBe(true)
		expect(TranslatorTestUtils.getEntryMap(service:GetLocalizationTable())["k.one"].Values["en-us"]).toBe("second")
		controller:destroy()
	end)
end)

describe("TranslatorService:IsTranslationReadyForLocale", function()
	it("is true once a single-key flush landed that locale, while the key is still queued", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en")
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		service:SetEntryValue("k.one", "One", "ctx", "fr", "Un")
		expect(service:IsTranslationReadyForLocale("k.one", "en")).toBe(false)

		service:FlushEntryForKey("k.one")

		expect(service:IsTranslationReadyForLocale("k.one", "en")).toBe(true)
		expect(service:IsTranslationReadyForLocale("k.one", "fr")).toBe(false)
		expect(service:IsTranslationReady("k.one")).toBe(false)
		controller:destroy()
	end)

	it("is true for a key nothing ever queued", function()
		local controller = TranslatorTestUtils.setup()

		expect(controller.translatorService:IsTranslationReadyForLocale("never.registered", "en")).toBe(true)
		controller:destroy()
	end)
end)

describe("TranslatorService teardown", function()
	it("keeps a key readable after a write that arrives post-destroy", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.newTranslatorService()

		service:Destroy()
		service:SetEntryValue("k.late", "Late", "ctx", "en", "Late")

		expect(service:IsTranslationReady("k.late")).toBe(true)
		expect(collect(controller, service:ObserveIsTranslationReady("k.late"))).toEqual({ true })
		controller:destroy()
	end)

	it("settles a readiness observer for a key still queued at destroy", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.newTranslatorService()

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		local received = collect(controller, service:ObserveIsTranslationReady("k.one"))
		expect(received).toEqual({ false })

		service:Destroy()

		expect(received[#received]).toBe(true)
		controller:destroy()
	end)

	it("does not write a queued entry that arrives after destroy", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.newTranslatorService()
		local localizationTable = service:GetLocalizationTable()

		service:Destroy()
		service:SetEntryValue("k.late", "Late", "ctx", "en", "Late")

		task.wait()

		expect(TranslatorTestUtils.getEntryMap(localizationTable)["k.late"]).toBeNil()
		controller:destroy()
	end)

	it("settles a pending flush promise instead of stranding its awaiters", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.newTranslatorService()

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		local promise = service:PromiseEntriesWritten()
		expect(promise:IsPending()).toBe(true)

		service:Destroy()

		expect(promise:IsPending()).toBe(false)
		controller:destroy()
	end)

	it("stops feeding a translator that was destroyed before its service", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))
		local emittedBeforeDestroy = #received

		translator:Destroy()

		-- The service outlives the translator, so this write reaches a readiness observer
		-- whose translator has already had its metatable stripped.
		controller.translatorService:SetEntryValue("greeting", "Hello", "ctx", "en-us", "Howdy")
		controller.awaitEntriesWritten()

		expect(#received).toBe(emittedBeforeDestroy)
		controller:destroy()
	end)

	it("delivers the ready state for a key re-registered inside a readiness handler", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))
		local rewritten = false
		controller.track(translator:_observeTranslationReady("greeting"):Subscribe(function(localeId)
			if localeId and not rewritten then
				rewritten = true
				translator:SetEntryValue("greeting", "Hello", "ctx", "en-us", "Howdy")
			end
		end))

		controller.awaitEntriesWritten()
		controller.awaitEntriesWritten()

		expect(received[#received]).toBe("Howdy")
		controller:destroy()
	end)

	it("survives a translation key that collides with a Maid member name", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ Destroy = "Bye", GiveTask = "Task" })

		local received = collect(controller, translator:ObserveFormatByKey("Destroy"))
		controller.awaitEntriesWritten()

		expect(received[#received]).toBe("Bye")
		expect(controller.translatorService:IsTranslationReady("GiveTask")).toBe(true)
		controller:destroy()
	end)
end)

describe("JSONTranslator:ObserveFormatByKey readiness", function()
	it("emits a fallback immediately, then the translation once the batch lands", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello" })

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))
		expect(received).toEqual({ "greeting" })

		controller.awaitEntriesWritten()

		expect(received[#received]).toBe("Hello")
		controller:destroy()
	end)

	it("translates a locale swap without any explicit flush", function()
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))
		expect(received[#received]).toBe("Hello")

		controller.setForcedLocaleId("fr")
		task.wait()

		expect(received[#received]).toBe("Bonjour")
		controller:destroy()
	end)

	it("never falls back to the source while a swapped-to locale is still queued", function()
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hello" },
			it = { greeting = "Ciao" },
		})
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))
		local emittedBeforeSwap = #received

		controller.setForcedLocaleId("it")
		task.wait()

		for index = emittedBeforeSwap + 1, #received do
			expect(received[index]).toBe("Ciao")
		end
		expect(received[#received]).toBe("Ciao")
		controller:destroy()
	end)

	it("translates a swap back to an already loaded locale", function()
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
			it = { greeting = "Ciao" },
		})
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))

		controller.setForcedLocaleId("fr")
		task.wait()
		expect(received[#received]).toBe("Bonjour")

		controller.setForcedLocaleId("it")
		task.wait()
		expect(received[#received]).toBe("Ciao")

		-- Nothing is queued this time, so readiness never drops and the translation runs on
		-- the swap itself rather than on a flush.
		controller.setForcedLocaleId("fr")
		expect(received[#received]).toBe("Bonjour")

		task.wait()
		expect(received[#received]).toBe("Bonjour")
		controller:destroy()
	end)

	it("keeps translating for the locale asked for, not the one a translator was built for", function()
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})
		controller.setForcedLocaleId("fr")
		controller.awaitEntriesWritten()

		-- A translator built for another language answers fluently rather than failing, so the
		-- target locale has to win over whichever translator is consulted first.
		local received = collect(controller, translator:ObserveFormatByKey("greeting"))
		expect(received[#received]).toBe("Bonjour")

		local enTranslator = controller.getLocalizationTable():GetTranslator("en")
		expect(translator:_doTranslation(enTranslator, "greeting", nil, "fr")).toBe("Bonjour")
		expect(translator:_doTranslation(enTranslator, "greeting", nil, "en")).toBe("Hello")
		controller:destroy()
	end)

	it("picks up a value registered after subscribing", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveFormatByKey("late.key"))
		expect(received[#received]).toBe("late.key")

		translator:SetEntryValue("late.key", "Later", "ctx", "en-us", "Later")
		controller.awaitEntriesWritten()

		expect(received[#received]).toBe("Later")
		controller:destroy()
	end)

	it("emits the key itself for a key nothing registered", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello" })
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveFormatByKey("does.not.exist"))

		expect(received[#received]).toBe("does.not.exist")
		controller:destroy()
	end)

	it("does not flicker to the source language when an arg emits during a locale swap", function()
		-- Starts in French, not the source locale, so a fallback to English is distinguishable
		-- from the correct text. Swapping from the source locale would render the same string
		-- either way and prove nothing.
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hi {name}" },
			fr = { greeting = "Salut {name}" },
			it = { greeting = "Ciao {name}" },
		})
		controller.setForcedLocaleId("fr")
		controller.awaitEntriesWritten()

		local name = controller.track(ValueObject.new("Quenty", "string"))
		local received = collect(controller, translator:ObserveFormatByKey("greeting", { name = name:Observe() }))
		expect(received[#received]).toBe("Salut Quenty")

		-- The swap queues the Italian data; the arg emits before that batch lands. The text
		-- must stay French until Italian is readable, never drop to the source language.
		controller.setForcedLocaleId("it")
		name.Value = "James"
		expect(received[#received]).toBe("Salut James")

		task.wait()
		expect(received[#received]).toBe("Ciao James")
		controller:destroy()
	end)

	it("does not force the batch to flush early", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello", farewell = "Bye" })

		local writesBefore = controller.translatorService:GetLocalizationWriteCount()
		collect(controller, translator:ObserveFormatByKey("greeting"))

		expect(controller.translatorService:GetLocalizationWriteCount()).toBe(writesBefore)
		expect(controller.translatorService:IsTranslationReady("farewell")).toBe(false)
		controller:destroy()
	end)
end)
