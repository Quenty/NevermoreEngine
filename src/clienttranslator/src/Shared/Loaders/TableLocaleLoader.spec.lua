--!nonstrict
--[[
	@class TableLocaleLoader.spec.lua

	Exercises the in-memory table loader through a real ServiceBag and asserts on what
	actually reached the TranslatorService's localization table. The shared world is built
	by [LocaleLoaderTestUtils.LocaleLoaderTestUtils.setup].
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local LocaleLoaderTestUtils = require("LocaleLoaderTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("TableLocaleLoader", function()
	it("writes the decoded entries to the translator service", function()
		local controller = LocaleLoaderTestUtils.setup()
		local loader = controller.newTableLoader({ greeting = "Hello" })

		loader:LoadSourceLocale()
		controller.flush()

		local entry = controller.getEntryMap()["greeting"]
		expect(entry.Values["en"]).toBe("Hello")
		expect(entry.Example).toBe("Hello")

		controller:destroy()
	end)

	it("loads only once across the load entry points", function()
		local controller = LocaleLoaderTestUtils.setup()
		local loader = controller.newTableLoader({ greeting = "Hello" })

		loader:LoadSourceLocale()
		controller.flush()
		expect(controller.getWriteCount()).toBe(1)

		-- The in-memory data is loaded up front and never re-queued.
		loader:LoadLocale("fr-fr")
		loader:LoadAllLocales()
		expect(controller.isIdle()).toBe(true)
		controller.flush()
		expect(controller.getWriteCount()).toBe(1)

		controller:destroy()
	end)
end)
