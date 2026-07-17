--!nonstrict
--[[
	@class JSONTranslator.spec.lua

	Pins the *current* behavior of [JSONTranslator]. These tests are intentionally
	behavior-pinning (characterization) tests: they document how the translator
	writes into a Roblox LocalizationTable today, so that an upcoming refactor
	(deferring/centralizing those writes to avoid replicating megabytes of
	localization data) can be validated against a known baseline.

	Notable behaviors pinned here that the refactor is expected to change:
	  * :Init() eagerly writes *every* entry (value + example) into the
	    localization table up-front. This is the write amplification we want to defer.
	  * :ToTranslationKey() has a side effect: it writes an "en" entry every time
	    it is called (see its `-- TODO: Only set if we don't need it`).
	  * :SetEntryValue() writes straight through to the localization table.

	The shared world (real ServiceBag + real TranslatorService, isolated per test) is
	built by [TranslatorTestUtils.setup]; see there for details.
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local HttpService = game:GetService("HttpService")

local JSONTranslator = require("JSONTranslator")
local Jest = require("Jest")
local Table = require("Table")
local TranslatorTestUtils = require("TranslatorTestUtils")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local setup = TranslatorTestUtils.setup
local getEntryMap = TranslatorTestUtils.getEntryMap

describe("JSONTranslator.new", function()
	it("exposes the expected class identity", function()
		local controller = setup()
		expect(JSONTranslator.ClassName).toBe("JSONTranslator")
		controller:destroy()
	end)

	it("sets ServiceName to the translator name so it registers uniquely", function()
		local controller = setup()
		local translator = JSONTranslator.new("MyTranslator", "en", {})
		expect(translator.ServiceName).toBe("MyTranslator")
		controller:destroy()
	end)

	it("decodes entries from a (localeId, dataTable) pair in the constructor", function()
		-- Decoding happens in the constructor (into _entries); writing to a table is deferred to Init.
		local controller = setup()
		local translator = JSONTranslator.new("TestTranslator", "en", {
			actions = {
				respawn = "Respawn {playerName}",
			},
		})

		local keys = {}
		for _, entry in translator._entries do
			keys[entry.Key] = entry.Values["en"]
		end
		expect(keys["actions.respawn"]).toBe("Respawn {playerName}")
		controller:destroy()
	end)

	it("decodes entries from an Instance folder of StringValues", function()
		local controller = setup()

		local folder = controller.track(Instance.new("Folder"))
		local en = Instance.new("StringValue")
		en.Name = "en.json"
		en.Value = HttpService:JSONEncode({ hello = "Hello" })
		en.Parent = folder

		controller.newTranslatorFromInstance(folder)

		local entries = getEntryMap(controller.getLocalizationTable())
		expect(entries["hello"]).never.toBeNil()
		expect(entries["hello"].Values["en"]).toBe("Hello")
		controller:destroy()
	end)

	it("errors when translatorName is not a string", function()
		local controller = setup()
		expect(function()
			JSONTranslator.new(123 :: any, "en", {})
		end).toThrow()
		controller:destroy()
	end)

	it("errors when neither an (localeId, dataTable) pair nor an Instance is given", function()
		local controller = setup()
		expect(function()
			JSONTranslator.new("TestTranslator", "en", "not a table" :: any)
		end).toThrow()
		controller:destroy()
	end)
end)

describe("JSONTranslator:Init eager writes", function()
	-- PIN: Init writes the entire decoded table into the localization table immediately.
	-- This up-front write is exactly the replication/loading cost the refactor targets.
	it("writes every decoded entry into the localization table during Init", function()
		local controller = setup()
		controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
				jump = "Jump",
			},
			greeting = "Hello there",
		})

		local entries = getEntryMap(controller.getLocalizationTable())
		expect(Table.count(entries)).toBe(3)
		expect(entries["actions.respawn"]).never.toBeNil()
		expect(entries["actions.jump"]).never.toBeNil()
		expect(entries["greeting"]).never.toBeNil()
		controller:destroy()
	end)

	it("writes source, context, value and example for each entry", function()
		local controller = setup()
		controller.newTranslator({
			greeting = "Hello there",
		})

		local entry = getEntryMap(controller.getLocalizationTable())["greeting"]
		expect(entry).never.toBeNil()
		expect(entry.Source).toBe("Hello there")
		expect(entry.Values["en"]).toBe("Hello there")
		expect(entry.Example).toBe("Hello there")
		-- Context is generated deterministically from the translator name and key.
		expect(entry.Context).toBe("Generated from TestTranslator with key greeting")
		controller:destroy()
	end)

	it("does not write before Init runs (writes are an Init side effect, not a new() side effect)", function()
		local controller = setup()

		local translator = JSONTranslator.new("TestTranslator", "en", { greeting = "Hi" })
		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		translator:Init(controller.serviceBag)
		controller.track(function()
			translator:Destroy()
		end)

		expect(#controller.getLocalizationTable():GetEntries()).toBe(1)
		controller:destroy()
	end)
end)

describe("JSONTranslator:SetEntryValue", function()
	it("writes the value straight through to the localization table", function()
		local controller = setup()
		local translator = controller.newTranslator({})

		translator:SetEntryValue("some.key", "Source", "context", "en", "Translated")

		local entry = getEntryMap(controller.getLocalizationTable())["some.key"]
		expect(entry).never.toBeNil()
		expect(entry.Source).toBe("Source")
		expect(entry.Context).toBe("context")
		expect(entry.Values["en"]).toBe("Translated")
		controller:destroy()
	end)

	it("validates its arguments", function()
		local controller = setup()
		local translator = controller.newTranslator({})

		expect(function()
			translator:SetEntryValue(1 :: any, "s", "c", "en", "t")
		end).toThrow()
		expect(function()
			translator:SetEntryValue("k", "s", "c", "en", nil :: any)
		end).toThrow()
		controller:destroy()
	end)

	-- PIN: outside of Studio, only the requested locale is written (no pseudo-localization).
	it("writes only the requested locale outside of Studio", function()
		local controller = setup()
		local translator = controller.newTranslator({})

		translator:SetEntryValue("some.key", "Source", "context", "en", "Translated")

		local entry = getEntryMap(controller.getLocalizationTable())["some.key"]
		expect(Table.count(entry.Values)).toBe(1)
		controller:destroy()
	end)
end)

describe("JSONTranslator:ToTranslationKey", function()
	it("derives a stable translation key from a prefix and text", function()
		-- Text is lower-camel-cased (spaces are word boundaries) and capped at 20 chars.
		local controller = setup()
		local translator = controller.newTranslator({})
		expect(translator:ToTranslationKey("button", "Play Now")).toBe("button.playNow")
		controller:destroy()
	end)

	-- PIN: ToTranslationKey has a write side effect (its own TODO calls this out).
	-- The refactor should be able to make this lazy, so this test documents the status quo.
	it("writes an 'en' entry into the localization table as a side effect", function()
		local controller = setup()
		local translator = controller.newTranslator({})

		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		local key = translator:ToTranslationKey("button", "Play Now")

		local entry = getEntryMap(controller.getLocalizationTable())[key]
		expect(entry).never.toBeNil()
		expect(entry.Values["en"]).toBe("Play Now")
		expect(entry.Source).toBe("Play Now")
		controller:destroy()
	end)
end)

describe("JSONTranslator:GetLocalizationTable / GetLocaleId", function()
	it("returns the same localization table as the translator service", function()
		local controller = setup()
		local translator = controller.newTranslator({})
		expect(translator:GetLocalizationTable()).toBe(controller.translatorService:GetLocalizationTable())
		controller:destroy()
	end)

	it("delegates GetLocaleId to the translator service", function()
		local controller = setup()
		local translator = controller.newTranslator({})
		expect(translator:GetLocaleId()).toBe(controller.translatorService:GetLocaleId())
		controller:destroy()
	end)
end)

describe("JSONTranslator:FormatByKey", function()
	it("formats using the acquired translator, substituting args", function()
		local controller = setup()
		local translator = controller.awaitLoaded(controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		}))

		expect(translator:FormatByKey("actions.respawn", { playerName = "Quenty" })).toBe("Respawn Quenty")
		controller:destroy()
	end)

	it("falls back to the key itself when the key is missing", function()
		local controller = setup()
		local translator = controller.awaitLoaded(controller.newTranslator({ greeting = "Hi" }))

		expect(translator:FormatByKey("does.not.exist")).toBe("does.not.exist")
		controller:destroy()
	end)
end)

describe("JSONTranslator:ObserveFormatByKey", function()
	it("emits a formatted translation for a key", function()
		local controller = setup()
		local translator = controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		})

		local received
		controller.track(
			translator:ObserveFormatByKey("actions.respawn", { playerName = "Quenty" }):Subscribe(function(text)
				received = text
			end)
		)

		expect(received).toBe("Respawn Quenty")
		controller:destroy()
	end)

	it("re-emits when the args observable changes", function()
		local controller = setup()
		local translator = controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		})

		local name = controller.track(ValueObject.new("Quenty", "string"))

		local received
		controller.track(
			translator:ObserveFormatByKey("actions.respawn", { playerName = name:Observe() }):Subscribe(function(text)
				received = text
			end)
		)

		expect(received).toBe("Respawn Quenty")

		name.Value = "James"
		expect(received).toBe("Respawn James")
		controller:destroy()
	end)

	it("requires a string translation key", function()
		local controller = setup()
		local translator = controller.newTranslator({})
		expect(function()
			translator:ObserveFormatByKey(5 :: any)
		end).toThrow()
		controller:destroy()
	end)
end)

describe("JSONTranslator:Destroy", function()
	it("tears down its maid and unsets its metatable", function()
		local controller = setup()

		local translator = JSONTranslator.new("TestTranslator", "en", { greeting = "Hi" })
		translator:Init(controller.serviceBag)

		translator:Destroy()

		-- After Destroy the metatable is stripped, so method access is gone.
		expect(getmetatable(translator)).toBeNil()
		controller:destroy()
	end)
end)
