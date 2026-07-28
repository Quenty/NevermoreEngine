--!strict
--[[
	@class JSONTranslatorTranslationReady.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TieRealms = require("TieRealms")
local TranslatorTestUtils = require("TranslatorTestUtils")

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

describe("JSONTranslator:ObserveTranslationReady", function()
	it("emits nil while the key is queued, then the locale it is readable for", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })

		local received = collect(controller, translator:ObserveTranslationReady("greeting"))
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

		expect(collect(controller, translator:ObserveTranslationReady("greeting"))).toEqual({ "en-us" })
		controller:destroy()
	end)

	it("emits immediately for a key nothing ever registered", function()
		local controller = TranslatorTestUtils.setup()
		controller.setForcedLocaleId("en-us")
		local translator = controller.newTranslator({ greeting = "Hello" })
		controller.awaitEntriesWritten()

		expect(collect(controller, translator:ObserveTranslationReady("never.registered"))).toEqual({ "en-us" })
		controller:destroy()
	end)

	it("re-emits for the new locale when the locale swaps", function()
		local controller, translator = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})
		controller.awaitEntriesWritten()

		local received = collect(controller, translator:ObserveTranslationReady("greeting"))
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

		local received = collect(controller, translator:ObserveTranslationReady("greeting"))
		expect(received).toEqual({ "fr" })

		controller.setForcedLocaleId("en")
		expect(received).toEqual({ "fr", "en" })
		controller:destroy()
	end)

	it("does not write to the localization table while observing", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello", farewell = "Bye" })
		controller.awaitEntriesWritten()

		local writesBefore = controller.translatorService:GetLocalizationWriteCount()
		collect(controller, translator:ObserveTranslationReady("greeting"))
		collect(controller, translator:ObserveTranslationReady("farewell"))

		expect(controller.translatorService:GetLocalizationWriteCount()).toBe(writesBefore)
		controller:destroy()
	end)

	it("requires a string translation key", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello" })

		expect(function()
			translator:ObserveTranslationReady(5 :: any)
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

describe("TranslatorService:ObserveTranslationReady", function()
	it("emits the current state immediately", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")

		expect(collect(controller, service:ObserveTranslationReady("k.one"))).toEqual({ false })
		controller:destroy()
	end)

	it("emits false when a key is queued after subscribing, then true on the flush", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local received = collect(controller, service:ObserveTranslationReady("k.one"))
		expect(received).toEqual({ true })

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		expect(received).toEqual({ true, false })

		controller.awaitEntriesWritten()
		expect(received).toEqual({ true, false, true })
		controller:destroy()
	end)

	it("fires ready even when the queued value already matched the table", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		controller.awaitEntriesWritten()

		local received = collect(controller, service:ObserveTranslationReady("k.one"))
		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		controller.awaitEntriesWritten()

		expect(received).toEqual({ true, false, true })
		controller:destroy()
	end)

	it("serves multiple observers of the same key independently", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local first = {}
		local firstSub = service:ObserveTranslationReady("k.one"):Subscribe(function(value)
			table.insert(first, value)
		end)
		local second = collect(controller, service:ObserveTranslationReady("k.one"))

		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		expect(first).toEqual({ true, false })
		expect(second).toEqual({ true, false })

		firstSub:Destroy()
		controller.awaitEntriesWritten()

		expect(first).toEqual({ true, false })
		expect(second).toEqual({ true, false, true })
		controller:destroy()
	end)

	it("does not error when the last observer leaves before the flush", function()
		local controller = TranslatorTestUtils.setup()
		local service = controller.translatorService

		local sub = service:ObserveTranslationReady("k.one"):Subscribe(function() end)
		service:SetEntryValue("k.one", "One", "ctx", "en", "One")
		sub:Destroy()

		controller.awaitEntriesWritten()
		expect(service:IsTranslationReady("k.one")).toBe(true)
		controller:destroy()
	end)
end)

describe("JSONTranslator:ObserveFormatByKey readiness", function()
	it("emits immediately rather than waiting a frame for the batch", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello" })

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))

		expect(#received).toBe(1)
		controller:destroy()
	end)

	it("replaces the first emission with the translation once the batch lands", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({ greeting = "Hello" })

		local received = collect(controller, translator:ObserveFormatByKey("greeting"))
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
