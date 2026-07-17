--!nonstrict
--[[
	@class TranslatorService.spec.lua

	Pins the *current* behavior of [TranslatorService], focused on the parts that do
	not depend on the cloud translator pipeline (which yields and requires a real
	player/locale to resolve).

	The behaviors pinned here matter for the upcoming replication refactor:
	  * GetLocalizationTable() lazily creates a *single* named table under
	    LocalizationService and caches it. The name is role-based
	    ("GeneratedJSONTable_Server" vs "GeneratedJSONTable_Client"), and a second
	    lookup (even from a fresh service) resolves to the same instance. That shared,
	    replicated table is the thing we are trying to stop over-replicating.
	  * GetLocaleId() falls back through translator -> LocalPlayer -> RobloxLocaleId.
	  * PromiseTranslator() dedupes a single pending promise and resolves it once a
	    translator becomes available.

	These tests build TranslatorService instances directly (via the module metatable)
	rather than through a ServiceBag, so we can exercise individual methods without
	triggering Init's cloud translator subscription.
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local Jest = require("Jest")
local Maid = require("Maid")
local TranslatorService = require("TranslatorService")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local beforeEach = Jest.Globals.beforeEach
local afterEach = Jest.Globals.afterEach

-- The name GetLocalizationTable uses in this (server) test context.
local EXPECTED_TABLE_NAME = if RunService:IsServer() then "GeneratedJSONTable_Server" else "GeneratedJSONTable_Client"

local testMaid

-- Removes any generated tables so each test starts from a clean LocalizationService.
local function clearGeneratedTables()
	for _, child in LocalizationService:GetChildren() do
		if child:IsA("LocalizationTable") and string.match(child.Name, "^GeneratedJSONTable_") then
			child:Destroy()
		end
	end
end

-- Creates a bare TranslatorService instance (matching how ServiceBag constructs one).
local function newService()
	return setmetatable({}, { __index = TranslatorService })
end

beforeEach(function()
	testMaid = Maid.new()
	clearGeneratedTables()
end)

afterEach(function()
	testMaid:DoCleaning()
	testMaid = nil
	clearGeneratedTables()
end)

describe("TranslatorService:GetLocalizationTable", function()
	it("creates a role-named LocalizationTable parented to LocalizationService", function()
		local service = newService()

		local localizationTable = service:GetLocalizationTable()

		expect(localizationTable:IsA("LocalizationTable")).toBe(true)
		expect(localizationTable.Name).toBe(EXPECTED_TABLE_NAME)
		expect(localizationTable.Parent).toBe(LocalizationService)
	end)

	it("caches the table so repeated calls return the same instance", function()
		local service = newService()

		local first = service:GetLocalizationTable()
		local second = service:GetLocalizationTable()

		expect(second).toBe(first)
	end)

	-- PIN: the generated table is a single shared instance keyed by name. A second,
	-- independent service finds the already-created table rather than making a new one.
	-- This is why writes replicate widely -- every translator shares this one table.
	it("resolves to the existing named table from a separate service instance", function()
		local first = newService():GetLocalizationTable()
		local second = newService():GetLocalizationTable()

		expect(second).toBe(first)
	end)
end)

describe("TranslatorService._getLocalizationTableName", function()
	it("names the table by server/client role", function()
		expect(TranslatorService._getLocalizationTableName({})).toBe(EXPECTED_TABLE_NAME)
	end)
end)

describe("TranslatorService:GetLocaleId", function()
	it("returns the translator's LocaleId when a translator is present", function()
		local service = newService()
		service._translator = testMaid:Add(ValueObject.new(nil))

		local localizationTable = Instance.new("LocalizationTable")
		testMaid:GiveTask(localizationTable)
		service._translator.Value = localizationTable:GetTranslator("fr-fr")

		expect(service:GetLocaleId()).toBe("fr-fr")
	end)

	it("falls back to RobloxLocaleId when there is no translator or local player", function()
		local service = newService()
		service._translator = testMaid:Add(ValueObject.new(nil))

		-- No LocalPlayer on the server, so this falls through to RobloxLocaleId.
		expect(service:GetLocaleId()).toBe(LocalizationService.RobloxLocaleId)
	end)
end)

describe("TranslatorService:GetTranslator", function()
	it("returns nil before a translator is acquired and the value afterwards", function()
		local service = newService()
		service._translator = testMaid:Add(ValueObject.new(nil))

		expect(service:GetTranslator()).toBe(nil)

		local localizationTable = Instance.new("LocalizationTable")
		testMaid:GiveTask(localizationTable)
		local translator = localizationTable:GetTranslator("en")
		service._translator.Value = translator

		expect(service:GetTranslator()).toBe(translator)
	end)
end)

describe("TranslatorService:PromiseTranslator", function()
	it("returns an already-resolved promise when a translator exists", function()
		local service = newService()
		service._maid = testMaid:Add(Maid.new())
		service._translator = testMaid:Add(ValueObject.new(nil))

		local localizationTable = Instance.new("LocalizationTable")
		testMaid:GiveTask(localizationTable)
		service._translator.Value = localizationTable:GetTranslator("en")

		local promise = service:PromiseTranslator()
		expect(promise:IsFulfilled()).toBe(true)
	end)

	it("dedupes to a single pending promise while no translator exists", function()
		local service = newService()
		service._maid = testMaid:Add(Maid.new())
		service._translator = testMaid:Add(ValueObject.new(nil))

		local first = service:PromiseTranslator()
		local second = service:PromiseTranslator()

		expect(first:IsPending()).toBe(true)
		expect(second).toBe(first)
	end)

	it("resolves the pending promise once a translator becomes available", function()
		local service = newService()
		service._maid = testMaid:Add(Maid.new())
		service._translator = testMaid:Add(ValueObject.new(nil))

		local promise = service:PromiseTranslator()
		expect(promise:IsPending()).toBe(true)

		local localizationTable = Instance.new("LocalizationTable")
		testMaid:GiveTask(localizationTable)
		service._translator.Value = localizationTable:GetTranslator("en")

		expect(promise:IsFulfilled()).toBe(true)
	end)
end)
