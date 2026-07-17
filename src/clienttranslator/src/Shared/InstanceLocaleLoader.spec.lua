--!nonstrict
--[[
	@class InstanceLocaleLoader.spec.lua

	Unit tests for the lazy per-locale loader in isolation, using a recording writer
	(no ServiceBag / TranslatorService needed).
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local HttpService = game:GetService("HttpService")

local InstanceLocaleLoader = require("InstanceLocaleLoader")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Records the writes the loader makes so tests can assert on them.
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

local function makeFolder(jsonByLocale)
	local folder = Instance.new("Folder")
	for localeId, dataTable in jsonByLocale do
		local stringValue = Instance.new("StringValue")
		stringValue.Name = localeId .. ".json"
		stringValue.Value = HttpService:JSONEncode(dataTable)
		stringValue.Parent = folder
	end
	return folder
end

local function newLoader(jsonByLocale)
	local folder = makeFolder(jsonByLocale)
	return InstanceLocaleLoader.new("T", "en", folder), folder
end

describe("InstanceLocaleLoader.LoadSourceLocale", function()
	it("writes the source locale's values and examples", function()
		local loader, folder = newLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })
		local writer = newRecordingWriter()

		expect(loader:LoadSourceLocale(writer)).toBe("en")

		local value = valueFor(writer, "greeting", "en")
		expect(value.text).toBe("Hello")
		expect(value.source).toBe("Hello")
		expect(value.context).toBe("Generated from T with key greeting")
		-- No other locale was written.
		expect(valueFor(writer, "greeting", "fr")).toBeNil()
		-- The source locale carries the example.
		expect(#writer.examples).toBe(1)
		expect(writer.examples[1].example).toBe("Hello")

		folder:Destroy()
	end)
end)

describe("InstanceLocaleLoader.LoadLocale", function()
	it("merges a later locale onto the source entries (keeping source/context)", function()
		local loader, folder = newLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })
		local writer = newRecordingWriter()

		loader:LoadSourceLocale(writer)
		expect(loader:LoadLocale("fr", writer)).toBe("fr")

		local value = valueFor(writer, "greeting", "fr")
		expect(value.text).toBe("Bonjour")
		-- Source and context come from the source locale so the value merges onto one entry.
		expect(value.source).toBe("Hello")
		expect(value.context).toBe("Generated from T with key greeting")
		-- A non-source locale contributes no example.
		expect(#writer.examples).toBe(1)

		folder:Destroy()
	end)

	it("resolves a regional locale to the closest available file", function()
		local loader, folder = newLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })
		local writer = newRecordingWriter()

		expect(loader:LoadLocale("fr-fr", writer)).toBe("fr")
		expect(valueFor(writer, "greeting", "fr").text).toBe("Bonjour")

		folder:Destroy()
	end)

	it("does not load a locale twice", function()
		local loader, folder = newLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })
		local writer = newRecordingWriter()

		expect(loader:LoadLocale("fr", writer)).toBe("fr")
		local writesAfterFirst = #writer.values

		-- Second call resolves to the same, already-loaded locale: nothing happens.
		expect(loader:LoadLocale("fr", writer)).toBeNil()
		expect(loader:LoadLocale("fr-fr", writer)).toBeNil()
		expect(#writer.values).toBe(writesAfterFirst)

		folder:Destroy()
	end)

	it("does nothing for a locale with no file", function()
		local loader, folder = newLoader({ en = { greeting = "Hello" } })
		local writer = newRecordingWriter()

		expect(loader:LoadLocale("de", writer)).toBeNil()
		expect(#writer.values).toBe(0)

		folder:Destroy()
	end)

	it("does not decode the other locales' JSON", function()
		local folder = Instance.new("Folder")
		local en = Instance.new("StringValue")
		en.Name = "en.json"
		en.Value = HttpService:JSONEncode({ greeting = "Hello" })
		en.Parent = folder
		-- Invalid JSON; loading only "en" must not touch it.
		local frBad = Instance.new("StringValue")
		frBad.Name = "fr.json"
		frBad.Value = "{ not valid json"
		frBad.Parent = folder

		local loader = InstanceLocaleLoader.new("T", "en", folder)
		local writer = newRecordingWriter()
		expect(loader:LoadSourceLocale(writer)).toBe("en")
		expect(valueFor(writer, "greeting", "en").text).toBe("Hello")

		folder:Destroy()
	end)
end)

describe("InstanceLocaleLoader.IsLoaded", function()
	it("reflects whether a locale has been loaded", function()
		local loader, folder = newLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })
		local writer = newRecordingWriter()

		expect(loader:IsLoaded("fr")).toBe(false)
		loader:LoadLocale("fr-fr", writer)
		expect(loader:IsLoaded("fr")).toBe(true)
		expect(loader:IsLoaded("fr-fr")).toBe(true)
		expect(loader:IsLoaded("de")).toBe(false)

		folder:Destroy()
	end)
end)

describe("InstanceLocaleLoader.LoadAllLocales", function()
	it("writes every available locale, with the example only from the source", function()
		local loader, folder = newLoader({ en = { greeting = "Hello" }, fr = { greeting = "Bonjour" } })
		local writer = newRecordingWriter()

		loader:LoadAllLocales(writer)

		expect(valueFor(writer, "greeting", "en").text).toBe("Hello")
		expect(valueFor(writer, "greeting", "fr").text).toBe("Bonjour")
		expect(#writer.examples).toBe(1)

		folder:Destroy()
	end)
end)
