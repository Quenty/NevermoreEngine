--!nonstrict
--[[
	@class JSONTranslator.spec.lua

	Pins the *current* behavior of [JSONTranslator]. These tests are intentionally
	behavior-pinning (characterization) tests: they document how the translator
	writes into a Roblox LocalizationTable today, so that an upcoming refactor
	(deferring/centralizing those writes to avoid replicating megabytes of
	localization data) can be validated against a known baseline.

	Writes into the localization table are deferred: JSONTranslator queues them with
	the centralized TranslatorService, which batches and flushes them at the end of
	the frame (via task.defer). So:
	  * :Init() does NOT write synchronously; entries appear after the deferred flush.
	  * :SetEntryValue() and :ToTranslationKey() queue writes the same way.
	  * Read paths (ObserveFormatByKey / PromiseFormatByKey / FormatByKey) wait for
	    the flush so a key is never read before it has been written.

	Tests drive the flush explicitly via controller.awaitEntriesWritten().

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

	it("decodes entries from an Instance folder of StringValues", function()
		local controller = setup()

		local folder = controller.track(Instance.new("Folder"))
		local en = Instance.new("StringValue")
		en.Name = "en.json"
		en.Value = HttpService:JSONEncode({ hello = "Hello" })
		en.Parent = folder

		controller.newTranslatorFromInstance(folder)
		controller.awaitEntriesWritten()

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

describe("JSONTranslator:Init deferred writes", function()
	-- PIN: entries are queued, not written synchronously. new() writes nothing, Init
	-- writes nothing synchronously, and the entries only land after the deferred flush.
	it("does not write during new() or synchronously during Init, then flushes on defer", function()
		local controller = setup()

		local translator = JSONTranslator.new("TestTranslator", "en", { greeting = "Hi" })
		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		translator:Init(controller.serviceBag)
		controller.track(function()
			translator:Destroy()
		end)

		-- Still nothing: the write is deferred to the end of the frame.
		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		controller.awaitEntriesWritten()
		expect(#controller.getLocalizationTable():GetEntries()).toBe(1)
		controller:destroy()
	end)

	it("flushes every decoded entry after the deferred flush", function()
		local controller = setup()
		controller.newTranslator({
			actions = {
				respawn = "Respawn {playerName}",
				jump = "Jump",
			},
			greeting = "Hello there",
		})

		controller.awaitEntriesWritten()

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

		controller.awaitEntriesWritten()

		local entry = getEntryMap(controller.getLocalizationTable())["greeting"]
		expect(entry).never.toBeNil()
		expect(entry.Source).toBe("Hello there")
		expect(entry.Values["en"]).toBe("Hello there")
		expect(entry.Example).toBe("Hello there")
		-- Context is generated deterministically from the translator name and key.
		expect(entry.Context).toBe("Generated from TestTranslator with key greeting")
		controller:destroy()
	end)
end)

describe("JSONTranslator:SetEntryValue", function()
	it("defers the write, then applies it on the flush", function()
		local controller = setup()
		local translator = controller.newTranslator({})

		translator:SetEntryValue("some.key", "Source", "context", "en", "Translated")

		-- Deferred: nothing in the table yet.
		expect(getEntryMap(controller.getLocalizationTable())["some.key"]).toBeNil()

		controller.awaitEntriesWritten()

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
		controller.awaitEntriesWritten()

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

	-- ToTranslationKey queues an "en" entry as a side effect; like other writes it is deferred.
	it("queues an 'en' entry as a side effect, written after the flush", function()
		local controller = setup()
		local translator = controller.newTranslator({})

		local key = translator:ToTranslationKey("button", "Play Now")

		-- Deferred: nothing written yet.
		expect(#controller.getLocalizationTable():GetEntries()).toBe(0)

		controller.awaitEntriesWritten()

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
	-- The key read-before-write guarantee: with entry writes still pending, the
	-- observable does not emit until the deferred flush has landed the entries.
	it("does not emit until the deferred entry writes have flushed", function()
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

		-- Writes are still pending, so nothing has been emitted yet.
		expect(received).toBeNil()

		controller.awaitEntriesWritten()
		expect(received).toBe("Respawn Quenty")
		controller:destroy()
	end)

	it("emits synchronously once entries are written", function()
		local controller = setup()
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
		local controller = setup()
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
