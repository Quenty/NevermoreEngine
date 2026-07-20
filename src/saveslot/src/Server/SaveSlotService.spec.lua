--!nonstrict
--[[
	Coverage for SaveSlotService's ServiceBag-driven configuration surface — the parts reachable
	without a bound Player (a headless cloud test server has none). The player-driven slot
	selection flow (which needs a real Player on the HasSaveSlots binder) is characterized
	separately at the datastore layer in SaveSlotLoadFlow.spec.

	@class SaveSlotService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a ServiceBag with SaveSlotService, and a mock-injected PlayerDataStoreService so nothing
-- touches a real datastore. Returns the bag + service; the caller decides when to Start.
local function newServiceBag()
	local serviceBag = ServiceBag.new()
	local playerDataStoreService = serviceBag:GetService(require("PlayerDataStoreService"))
	local saveSlotService = serviceBag:GetService(require("SaveSlotService"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(DataStoreMock.new())
	return serviceBag, saveSlotService
end

describe("SaveSlotService initialization", function()
	it("should initialize and start without a bound player", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			serviceBag:Start()
		end).never.toThrow()
		expect(saveSlotService).never.toBeNil()

		serviceBag:Destroy()
	end)
end)

describe("SaveSlotService.GetExplicitSelectionRequired", function()
	it("should default to false", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(saveSlotService:GetExplicitSelectionRequired()).toEqual(false)

		serviceBag:Destroy()
	end)

	it("should be true after RequireExplicitSelection", function()
		local serviceBag, saveSlotService = newServiceBag()

		saveSlotService:RequireExplicitSelection()
		expect(saveSlotService:GetExplicitSelectionRequired()).toEqual(true)

		serviceBag:Destroy()
	end)
end)

describe("SaveSlotService configuration guards", function()
	it("should reject RequireExplicitSelection after Start", function()
		local serviceBag, saveSlotService = newServiceBag()
		serviceBag:Start()

		expect(function()
			saveSlotService:RequireExplicitSelection()
		end).toThrow("RequireExplicitSelection must be called before Start")

		serviceBag:Destroy()
	end)

	it("should reject SetMaxSlotCount after Start", function()
		local serviceBag, saveSlotService = newServiceBag()
		serviceBag:Start()

		expect(function()
			saveSlotService:SetMaxSlotCount(3)
		end).toThrow("SetMaxSlotCount must be called before Start")

		serviceBag:Destroy()
	end)

	it("should accept a valid SetMaxSlotCount before Start", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetMaxSlotCount(3)
		end).never.toThrow()

		serviceBag:Destroy()
	end)

	it("should reject a SetMaxSlotCount below 1", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetMaxSlotCount(0)
		end).toThrow("Bad maxSlotCount")

		serviceBag:Destroy()
	end)

	it("should accept SetUnlimitedSlots before Start", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetUnlimitedSlots()
		end).never.toThrow()

		serviceBag:Destroy()
	end)

	it("should reject SetUnlimitedSlots after Start", function()
		local serviceBag, saveSlotService = newServiceBag()
		serviceBag:Start()

		-- Delegates to SetMaxSlotCount, so it surfaces the same before-Start guard
		expect(function()
			saveSlotService:SetUnlimitedSlots()
		end).toThrow("SetMaxSlotCount must be called before Start")

		serviceBag:Destroy()
	end)

	it("should reject a non-function summary provider", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetDefaultSummaryProvider("not a function")
		end).toThrow("Bad provider")

		serviceBag:Destroy()
	end)

	it("should accept a function summary provider", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetDefaultSummaryProvider(function()
				return nil
			end)
		end).never.toThrow()

		serviceBag:Destroy()
	end)
end)
