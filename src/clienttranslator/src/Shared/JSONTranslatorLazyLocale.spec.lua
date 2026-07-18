--!nonstrict
--[[
	@class JSONTranslatorLazyLocale.spec.lua

	Covers lazy per-locale loading for instance-decoded translators (per-locale JSON
	StringValues under a folder). On the client the target locale is knowable, so a
	locale's JSON is only decoded and written when that locale is actually needed; the
	source locale is always loaded as the fallback. Off the client every locale is
	loaded eagerly, since there is no player locale to key off.

	The realm is injected with TieRealmService and the locale is driven with
	TranslatorService:SetForcedLocaleId, so this client behavior runs on the server
	test runner. See [TranslatorTestUtils.setup].
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Jest = require("Jest")
local TieRealms = require("TieRealms")
local TranslatorTestUtils = require("TranslatorTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a client world with a two-locale (en/fr) instance translator already loaded
-- at the source locale.
local function setupClientTranslator(jsonByLocale)
	local controller = TranslatorTestUtils.setup({ tieRealm = TieRealms.CLIENT })
	controller.setForcedLocaleId("en")

	local folder = controller.newInstanceFolder(jsonByLocale)
	controller.newTranslatorFromInstance(folder)
	controller.awaitEntriesWritten()

	return controller, folder
end

describe("JSONTranslator lazy locale loading (client)", function()
	it("writes only the source locale at init, deferring other locales", function()
		local controller = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})

		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"]
		expect(entry.Values["en"]).toBe("Hello")
		-- French was never decoded or written -- it is not the target locale.
		expect(entry.Values["fr"]).toBeNil()
		controller:destroy()
	end)

	it("writes a locale's data when the locale is swapped to", function()
		local controller = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})

		controller.setForcedLocaleId("fr")
		controller.awaitEntriesWritten()

		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"]
		expect(entry.Values["fr"]).toBe("Bonjour")
		-- The source locale stays loaded as the fallback.
		expect(entry.Values["en"]).toBe("Hello")
		controller:destroy()
	end)

	it("loads the universal and regional files sharing the target language on swap", function()
		local controller = TranslatorTestUtils.setup({ tieRealm = TieRealms.CLIENT })
		controller.setForcedLocaleId("en")

		local folder = controller.newInstanceFolder({
			en = { greeting = "Hello" },
			es = { greeting = "Hola" },
			["es-mx"] = { greeting = "Que onda" },
		})
		controller.newTranslatorFromInstance(folder)
		controller.awaitEntriesWritten()

		controller.setForcedLocaleId("es-mx")
		controller.awaitEntriesWritten()

		-- Both the universal Spanish and the Mexico-specific file are loaded, with English
		-- still present as the ultimate fallback.
		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"]
		expect(entry.Values["es"]).toBe("Hola")
		expect(entry.Values["es-mx"]).toBe("Que onda")
		expect(entry.Values["en"]).toBe("Hello")
		controller:destroy()
	end)

	it("resolves a regional locale to the closest available file", function()
		local controller = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})

		-- fr-fr has no file, so it resolves to the fr file.
		controller.setForcedLocaleId("fr-fr")
		controller.awaitEntriesWritten()

		expect(TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"].Values["fr"]).toBe(
			"Bonjour"
		)
		controller:destroy()
	end)

	it("does not decode a locale's JSON until it is needed", function()
		local controller = TranslatorTestUtils.setup({ tieRealm = TieRealms.CLIENT })
		controller.setForcedLocaleId("en")

		-- French holds invalid JSON: decoding it at init would throw. Init must not decode it.
		local folder = controller.track(Instance.new("Folder"))
		local en = Instance.new("StringValue")
		en.Name = "en.json"
		en.Value = HttpService:JSONEncode({ greeting = "Hello" })
		en.Parent = folder
		local frBad = Instance.new("StringValue")
		frBad.Name = "fr.json"
		frBad.Value = "{ not valid json"
		frBad.Parent = folder

		controller.newTranslatorFromInstance(folder)
		controller.awaitEntriesWritten()

		-- Init succeeded (only the source locale was decoded).
		expect(TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"].Values["en"]).toBe(
			"Hello"
		)
		controller:destroy()
	end)

	it("does not decode or write a locale again once it has been loaded", function()
		local controller, folder = setupClientTranslator({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})

		controller.setForcedLocaleId("fr")
		controller.awaitEntriesWritten()
		local writesAfterFirstLoad = controller.translatorService:GetLocalizationWriteCount()

		-- Change the French source after it has been loaded; a reload would pick this up.
		folder:FindFirstChild("fr.json").Value = HttpService:JSONEncode({ greeting = "CHANGED" })

		-- Swap away and back to French.
		controller.setForcedLocaleId("en")
		controller.setForcedLocaleId("fr")
		controller.awaitEntriesWritten()

		-- Still the originally-decoded value, and no additional writes happened.
		expect(TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"].Values["fr"]).toBe(
			"Bonjour"
		)
		expect(controller.translatorService:GetLocalizationWriteCount()).toBe(writesAfterFirstLoad)
		controller:destroy()
	end)
end)

describe("JSONTranslator instance loading off the client", function()
	it("loads every locale eagerly when the realm is not client", function()
		local controller = TranslatorTestUtils.setup()

		local folder = controller.newInstanceFolder({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})
		controller.newTranslatorFromInstance(folder)
		controller.awaitEntriesWritten()

		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"]
		expect(entry.Values["en"]).toBe("Hello")
		-- No target locale off the client, so every locale is written up front.
		expect(entry.Values["fr"]).toBe("Bonjour")
		controller:destroy()
	end)
end)
