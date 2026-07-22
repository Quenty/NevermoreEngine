--!strict
--[[
	@class JSONTranslator.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local JSONTranslator = require("JSONTranslator")
local Jest = require("Jest")
local Table = require("Table")
local TranslatorTestUtils = require("TranslatorTestUtils")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("JSONTranslator.new", function()
	it("exposes the expected class identity", function()
		expect(JSONTranslator.ClassName).toBe("JSONTranslator")
	end)

	it("sets ServiceName to the translator name so it registers uniquely", function()
		local translator = JSONTranslator.new("MyTranslator", "en", {})
		expect(translator.ServiceName).toBe("MyTranslator")
	end)

	it("decodes entries from an Instance folder of StringValues", function()
		local controller = TranslatorTestUtils.setup()

		local folder = controller.track(Instance.new("Folder"))
		local en = Instance.new("StringValue")
		en.Name = "en.json"
		en.Value = HttpService:JSONEncode({ hello = "Hello" })
		en.Parent = folder

		controller.newTranslatorFromInstance(folder)
		controller.awaitEntriesWritten()

		local entries = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())
		expect(entries["hello"]).never.toBeNil()
		expect(entries["hello"].Values["en"]).toBe("Hello")
		controller:destroy()
	end)

	it("errors when translatorName is not a string", function()
		local controller = TranslatorTestUtils.setup()
		expect(function()
			JSONTranslator.new(123 :: any, "en", {})
		end).toThrow()
		controller:destroy()
	end)

	it("errors when neither an (localeId, dataTable) pair nor an Instance is given", function()
		local controller = TranslatorTestUtils.setup()
		expect(function()
			JSONTranslator.new("TestTranslator", "en", "not a table" :: any)
		end).toThrow()
		controller:destroy()
	end)
end)

describe("JSONTranslator:Init deferred writes", function()
	it("does not write during new() or synchronously during Init, then flushes on defer", function()
		local controller = TranslatorTestUtils.setup()

		local translator = JSONTranslator.new("TestTranslator", "en", { greeting = "Hi" })
		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		translator:Init(controller.serviceBag)
		controller.track(function()
			translator:Destroy()
		end)

		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		controller.awaitEntriesWritten()
		expect(#controller.getLocalizationTable():GetEntries()).toBe(1)
		controller:destroy()
	end)

	it("flushes every decoded entry after the deferred flush", function()
		local controller = TranslatorTestUtils.setup()
		controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
				jump = "Jump",
			},
			greeting = "Hello there",
		})

		controller.awaitEntriesWritten()

		local entries = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())
		expect(Table.count(entries)).toBe(3)
		expect(entries["actions.respawn"]).never.toBeNil()
		expect(entries["actions.jump"]).never.toBeNil()
		expect(entries["greeting"]).never.toBeNil()
		controller:destroy()
	end)

	it("writes source, context, value and example for each entry", function()
		local controller = TranslatorTestUtils.setup()
		controller.newTranslator({
			greeting = "Hello there",
		})

		controller.awaitEntriesWritten()

		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["greeting"]
		expect(entry).never.toBeNil()
		expect(entry.Source).toBe("Hello there")
		expect(entry.Values["en"]).toBe("Hello there")
		expect(entry.Example).toBe("Hello there")
		expect(entry.Context).toBe("Generated from TestTranslator with key greeting")
		controller:destroy()
	end)
end)

describe("JSONTranslator:SetEntryValue", function()
	it("defers the write, then applies it on the flush", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})

		translator:SetEntryValue("some.key", "Source", "context", "en", "Translated")

		expect(TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["some.key"]).toBeNil()

		controller.awaitEntriesWritten()

		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["some.key"]
		expect(entry).never.toBeNil()
		expect(entry.Source).toBe("Source")
		expect(entry.Context).toBe("context")
		expect(entry.Values["en"]).toBe("Translated")
		controller:destroy()
	end)

	it("validates its arguments", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})

		expect(function()
			translator:SetEntryValue(1 :: any, "s", "c", "en", "t")
		end).toThrow()
		expect(function()
			translator:SetEntryValue("k", "s", "c", "en", nil :: any)
		end).toThrow()
		controller:destroy()
	end)

	it("writes only the requested locale outside of Studio", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})

		translator:SetEntryValue("some.key", "Source", "context", "en", "Translated")
		controller.awaitEntriesWritten()

		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())["some.key"]
		expect(Table.count(entry.Values)).toBe(1)
		controller:destroy()
	end)
end)

describe("JSONTranslator:ToTranslationKey", function()
	it("derives a stable translation key from a prefix and text", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})
		expect(translator:ToTranslationKey("button", "Play Now")).toBe("button.playNow")
		controller:destroy()
	end)

	it("queues an 'en' entry as a side effect, written after the flush", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})

		local key = translator:ToTranslationKey("button", "Play Now")

		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		controller.awaitEntriesWritten()

		local entry = TranslatorTestUtils.getEntryMap(controller.getLocalizationTable())[key]
		expect(entry).never.toBeNil()
		expect(entry.Values["en"]).toBe("Play Now")
		expect(entry.Source).toBe("Play Now")
		controller:destroy()
	end)
end)

describe("JSONTranslator:GetLocalizationTable / GetLocaleId", function()
	it("returns the same localization table as the translator service", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})
		expect(translator:GetLocalizationTable()).toBe(controller.translatorService:GetLocalizationTable())
		controller:destroy()
	end)

	it("delegates GetLocaleId to the translator service", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})
		expect(translator:GetLocaleId()).toBe(controller.translatorService:GetLocaleId())
		controller:destroy()
	end)
end)

describe("JSONTranslator:FormatByKey", function()
	it("formats using the acquired translator, substituting args", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.awaitLoaded(controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		}))

		expect(translator:FormatByKey("actions.respawn", { playerName = "Quenty" })).toBe("Respawn Quenty")
		controller:destroy()
	end)

	it("falls back to the key itself when the key is missing", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.awaitLoaded(controller.newTranslator({ greeting = "Hi" }))

		expect(translator:FormatByKey("does.not.exist")).toBe("does.not.exist")
		controller:destroy()
	end)
end)

describe("JSONTranslator:ObserveFormatByKey", function()
	it("does not emit until the deferred entry writes have flushed", function()
		local controller = TranslatorTestUtils.setup()
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

		expect(received).toBeNil()

		controller.awaitEntriesWritten()
		expect(received).toBe("Respawn Quenty")
		controller:destroy()
	end)

	it("emits synchronously once entries are written", function()
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		})
		controller.awaitEntriesWritten()

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
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
			},
		})
		controller.awaitEntriesWritten()

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
		local controller = TranslatorTestUtils.setup()
		local translator = controller.newTranslator({})
		expect(function()
			translator:ObserveFormatByKey(5 :: any)
		end).toThrow()
		controller:destroy()
	end)
end)

describe("JSONTranslator:Destroy", function()
	it("tears down its maid and unsets its metatable", function()
		local controller = TranslatorTestUtils.setup()

		local translator = JSONTranslator.new("TestTranslator", "en", { greeting = "Hi" })
		translator:Init(controller.serviceBag)

		translator:Destroy()

		expect(getmetatable(translator)).toBeNil()
		controller:destroy()
	end)
end)
