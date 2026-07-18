--!nonstrict
--[[
	@class TableLocaleLoader.spec.lua

	Unit tests for the in-memory table loader, using a recording writer.
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")
local TableLocaleLoader = require("TableLocaleLoader")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newRecordingWriter()
	local writer = { values = {}, examples = {} }

	function writer:SetEntryValue(key, source, context, localeId, text)
		table.insert(self.values, { key = key, source = source, context = context, localeId = localeId, text = text })
	end

	function writer:SetEntryExample(key, source, context, example)
		table.insert(self.examples, { key = key, source = source, context = context, example = example })
	end

	return writer
end

local function valueFor(writer, key, localeId)
	for _, op in writer.values do
		if op.key == key and op.localeId == localeId then
			return op
		end
	end
	return nil
end

local function newLoader(dataTable)
	return TableLocaleLoader.new(LocalizationEntryParserUtils.decodeFromTable("T", "en", dataTable))
end

describe("TableLocaleLoader", function()
	it("queues the decoded entries through the writer", function()
		local loader = newLoader({ greeting = "Hello" })
		local writer = newRecordingWriter()

		loader:LoadSourceLocale(writer)

		expect(valueFor(writer, "greeting", "en").text).toBe("Hello")
		expect(#writer.examples).toBe(1)
		expect(writer.examples[1].example).toBe("Hello")
	end)

	it("loads only once across the load entry points", function()
		local loader = newLoader({ greeting = "Hello" })
		local writer = newRecordingWriter()

		loader:LoadSourceLocale(writer)
		loader:LoadLocale("fr-fr", writer)
		loader:LoadAllLocales(writer)

		-- The in-memory data is loaded up front and never re-queued.
		expect(#writer.values).toBe(1)
		expect(#writer.examples).toBe(1)
	end)
end)
