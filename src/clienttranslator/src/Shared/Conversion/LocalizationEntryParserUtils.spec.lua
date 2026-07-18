--!strict
--[[
	@class LocalizationEntryParserUtils.spec.lua

	Unit tests for the JSON -> localization-entry decoding, including the lazy
	per-locale decode used by client instance translators.
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Jest = require("Jest")
local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Indexes a decoded entry list by Key for assertions.
local function byKey(entries)
	local map = {}
	for _, entry in entries do
		map[entry.Key] = entry
	end
	return map
end

-- Builds a folder of per-locale StringValues named "<locale>.json" with encoded JSON.
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

describe("LocalizationEntryParserUtils.decodeFromTable", function()
	it("flattens nested keys into dotted keys with source/context/example/value", function()
		local entries = byKey(LocalizationEntryParserUtils.decodeFromTable("MyTable", "en", {
			actions = {
				respawn = "Respawn {playerName}",
			},
			greeting = "Hello",
		}))

		local respawn = entries["actions.respawn"]
		expect(respawn).never.toBeNil()
		expect(respawn.Source).toBe("Respawn {playerName}")
		expect(respawn.Example).toBe("Respawn {playerName}")
		expect(respawn.Values["en"]).toBe("Respawn {playerName}")
		expect(respawn.Context).toBe("Generated from MyTable with key actions.respawn")

		expect(entries["greeting"].Values["en"]).toBe("Hello")
	end)

	it("errors on a non-string, non-table leaf", function()
		expect(function()
			LocalizationEntryParserUtils.decodeFromTable("MyTable", "en", { bad = 5 })
		end).toThrow()
	end)
end)

describe("LocalizationEntryParserUtils.decodeFromInstance", function()
	it("decodes and merges every locale's StringValue into one entry per key", function()
		local folder = makeFolder({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})

		local entry = byKey(LocalizationEntryParserUtils.decodeFromInstance("T", "en", folder))["greeting"]
		expect(entry).never.toBeNil()
		-- Source and context come from the source locale (en).
		expect(entry.Source).toBe("Hello")
		expect(entry.Context).toBe("Generated from T with key greeting")
		expect(entry.Values["en"]).toBe("Hello")
		expect(entry.Values["fr"]).toBe("Bonjour")

		folder:Destroy()
	end)
end)

describe("LocalizationEntryParserUtils.getAvailableLocales", function()
	it("infers locales from StringValue names, stripping the .json suffix", function()
		local folder = makeFolder({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
			["zh-hans"] = { greeting = "你好" },
		})

		local locales = LocalizationEntryParserUtils.getAvailableLocales(folder)
		expect(locales["en"]).toBe(true)
		expect(locales["fr"]).toBe(true)
		expect(locales["zh-hans"]).toBe(true)
		expect(locales["de"]).toBeNil()

		folder:Destroy()
	end)
end)

describe("LocalizationEntryParserUtils.decodeLocaleFromInstance", function()
	it("decodes only the requested locale into the shared lookup", function()
		local folder = makeFolder({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})

		local lookup = {}
		local entries = byKey(LocalizationEntryParserUtils.decodeLocaleFromInstance("T", "en", "en", folder, lookup))

		expect(entries["greeting"].Values["en"]).toBe("Hello")
		-- French was not touched.
		expect(entries["greeting"].Values["fr"]).toBeNil()

		folder:Destroy()
	end)

	it("merges a later locale onto the existing entries, keeping source/context", function()
		local folder = makeFolder({
			en = { greeting = "Hello" },
			fr = { greeting = "Bonjour" },
		})

		local lookup = {}
		-- Source locale first (as the lazy loader always does), then French.
		LocalizationEntryParserUtils.decodeLocaleFromInstance("T", "en", "en", folder, lookup)
		local frEntries = byKey(LocalizationEntryParserUtils.decodeLocaleFromInstance("T", "en", "fr", folder, lookup))

		local entry = frEntries["greeting"]
		expect(entry.Values["fr"]).toBe("Bonjour")
		-- Source and context stay from the source-locale decode so the value merges.
		expect(entry.Values["en"]).toBe("Hello")
		expect(entry.Source).toBe("Hello")
		expect(entry.Context).toBe("Generated from T with key greeting")

		folder:Destroy()
	end)

	it("returns nothing when the requested locale has no file", function()
		local folder = makeFolder({ en = { greeting = "Hello" } })

		local lookup = {}
		local entries = LocalizationEntryParserUtils.decodeLocaleFromInstance("T", "en", "de", folder, lookup)
		expect(#entries).toBe(0)

		folder:Destroy()
	end)

	it("does not decode the other locales' JSON", function()
		local folder = Instance.new("Folder")
		local en = Instance.new("StringValue")
		en.Name = "en.json"
		en.Value = HttpService:JSONEncode({ greeting = "Hello" })
		en.Parent = folder
		-- French holds invalid JSON; decoding only "en" must not touch it.
		local frBad = Instance.new("StringValue")
		frBad.Name = "fr.json"
		frBad.Value = "{ not valid json"
		frBad.Parent = folder

		local lookup = {}
		local entries = byKey(LocalizationEntryParserUtils.decodeLocaleFromInstance("T", "en", "en", folder, lookup))
		expect(entries["greeting"].Values["en"]).toBe("Hello")

		folder:Destroy()
	end)
end)
