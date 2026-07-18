--!nonstrict
--[[
	@class InstanceLocaleLoader.spec.lua

	Exercises the lazy per-locale loader through a real ServiceBag and asserts on what
	actually reached the TranslatorService's localization table. The shared world is built
	by [LocaleLoaderTestUtils.LocaleLoaderTestUtils.setup].
]]

local require = require(script.Parent.loader).load(script)

local InstanceLocaleLoader = require("InstanceLocaleLoader")
local Jest = require("Jest")
local LocaleLoaderTestUtils = require("LocaleLoaderTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InstanceLocaleLoader.LoadSourceLocale", function()
	it("writes the source locale's values and example to the service", function()
		local controller = LocaleLoaderTestUtils.setup()
		local loader = controller.newInstanceLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })

		loader:LoadSourceLocale()
		controller.flush()

		local entry = controller.getEntryMap()["greeting"]
		expect(entry.Values["en"]).toBe("Hello")
		expect(entry.Source).toBe("Hello")
		expect(entry.Context).toBe("Generated from T with key greeting")
		-- No other locale was written.
		expect(entry.Values["fr"]).toBeNil()
		-- The source locale carries the example.
		expect(entry.Example).toBe("Hello")

		controller:destroy()
	end)
end)

describe("InstanceLocaleLoader.LoadLocale", function()
	it("merges a later locale onto the source entries (keeping source/context)", function()
		local controller = LocaleLoaderTestUtils.setup()
		local loader = controller.newInstanceLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })

		loader:LoadSourceLocale()
		loader:LoadLocale("fr")
		controller.flush()

		local entry = controller.getEntryMap()["greeting"]
		expect(entry.Values["fr"]).toBe("Bonjour")
		-- Source and context come from the source locale so the value merges onto one entry.
		expect(entry.Source).toBe("Hello")
		expect(entry.Context).toBe("Generated from T with key greeting")
		-- A non-source locale contributes no example, so the source's example stands.
		expect(entry.Example).toBe("Hello")

		controller:destroy()
	end)

	it("loads the universal and regional files that share the target language", function()
		local controller = LocaleLoaderTestUtils.setup()
		-- A universal "es" plus a Mexico-specific "es-mx"; a target of es-mx needs both.
		local loader = controller.newInstanceLoader({
			en = { greeting = "Hello" },
			es = { greeting = "Hola" },
			["es-mx"] = { greeting = "Que onda" },
		})

		loader:LoadSourceLocale()
		loader:LoadLocale("es-mx")
		controller.flush()

		expect(controller.valueFor("greeting", "es")).toBe("Hola")
		expect(controller.valueFor("greeting", "es-mx")).toBe("Que onda")

		controller:destroy()
	end)

	it("loads sibling regional locales so they can serve as fallbacks", function()
		local controller = LocaleLoaderTestUtils.setup()
		-- fr-fr and fr-ca each hold a key the other lacks; a fr-fr target loads both.
		local loader = controller.newInstanceLoader({
			en = { shared = "Shared" },
			["fr-fr"] = { onlyFr = "Seulement FR" },
			["fr-ca"] = { onlyCa = "Seulement CA" },
		})

		loader:LoadSourceLocale()
		loader:LoadLocale("fr-fr")
		controller.flush()

		expect(controller.valueFor("onlyFr", "fr-fr")).toBe("Seulement FR")
		expect(controller.valueFor("onlyCa", "fr-ca")).toBe("Seulement CA")

		controller:destroy()
	end)

	it("uses the source Source/Context even if a regional file is decoded first", function()
		local controller = LocaleLoaderTestUtils.setup()
		-- Only en-gb shares en's language; the explicit source-first load must still win.
		local loader = controller.newInstanceLoader({ en = { greeting = "Hello" }, ["en-gb"] = { greeting = "Hiya" } })

		loader:LoadLocale("en-gb")
		controller.flush()

		local entry = controller.getEntryMap()["greeting"]
		expect(entry.Values["en-gb"]).toBe("Hiya")
		expect(entry.Source).toBe("Hello")
		expect(entry.Context).toBe("Generated from T with key greeting")

		controller:destroy()
	end)

	it("does not load a locale twice", function()
		local controller = LocaleLoaderTestUtils.setup()
		local loader = controller.newInstanceLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })

		loader:LoadSourceLocale()
		loader:LoadLocale("fr")
		controller.flush()
		expect(controller.getWriteCount()).toBe(1)

		-- The repeat and a regional variant of it decode nothing, so nothing is queued.
		loader:LoadLocale("fr")
		loader:LoadLocale("fr-fr")
		expect(controller.isIdle()).toBe(true)
		controller.flush()
		expect(controller.getWriteCount()).toBe(1)

		controller:destroy()
	end)

	it("writes nothing extra for a language with no files", function()
		local controller = LocaleLoaderTestUtils.setup()
		local loader = controller.newInstanceLoader({ en = { greeting = "Hello" } })

		loader:LoadSourceLocale()
		controller.flush()
		expect(controller.getWriteCount()).toBe(1)

		loader:LoadLocale("de-de")
		expect(controller.isIdle()).toBe(true)
		controller.flush()
		expect(controller.getWriteCount()).toBe(1)

		controller:destroy()
	end)

	it("does not decode the other locales' JSON", function()
		local controller = LocaleLoaderTestUtils.setup()
		local folder = controller.newInstanceFolder({ en = { greeting = "Hello" } })
		-- Invalid JSON; loading only the source must not touch it.
		local frBad = Instance.new("StringValue")
		frBad.Name = "fr.json"
		frBad.Value = "{ not valid json"
		frBad.Parent = folder

		local loader = InstanceLocaleLoader.new(controller.serviceBag, "T", "en", folder)
		loader:LoadSourceLocale()
		controller.flush()

		expect(controller.valueFor("greeting", "en")).toBe("Hello")

		controller:destroy()
	end)
end)

describe("InstanceLocaleLoader.LoadAllLocales", function()
	it("writes every available locale, with the example only from the source", function()
		local controller = LocaleLoaderTestUtils.setup()
		local loader = controller.newInstanceLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })

		loader:LoadAllLocales()
		controller.flush()

		local entry = controller.getEntryMap()["greeting"]
		expect(entry.Values["en"]).toBe("Hello")
		expect(entry.Values["fr"]).toBe("Bonjour")
		-- Only the source contributes an example.
		expect(entry.Example).toBe("Hello")

		controller:destroy()
	end)
end)
