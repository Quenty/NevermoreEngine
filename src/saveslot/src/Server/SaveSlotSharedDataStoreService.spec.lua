--!strict
--[[
	Coverage for the flat, session-lock-free shared snapshot store, driven against a mocked datastore.

	@class SaveSlotSharedDataStoreService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotSharedDataStoreService = require("SaveSlotSharedDataStoreService")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local mock = DataStoreMock.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local service: SaveSlotSharedDataStoreService.SaveSlotSharedDataStoreService =
		serviceBag:GetService(SaveSlotSharedDataStoreService) :: any
	serviceBag:Init()
	service:SetRobloxDataStore(mock)
	serviceBag:Start()

	local function Destroy(_self)
		maid:DoCleaning()
	end

	local controller = {
		service = service,
		mock = mock,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("SaveSlotSharedDataStoreService", function()
	it("round-trips a value by key", function()
		local context = setup()
		PromiseTestUtils.awaitFulfilled(context.service:PromiseWrite("code-1", { Coins = 9, World = { Eggs = 2 } }))

		local value = PromiseTestUtils.awaitFulfilled(context.service:PromiseRead("code-1"))
		expect(value.Coins).toEqual(9)
		expect(value.World.Eggs).toEqual(2)

		context:Destroy()
	end)

	it("reads nil for an absent key", function()
		local context = setup()
		expect(PromiseTestUtils.awaitFulfilled(context.service:PromiseRead("missing"))).toBeNil()

		context:Destroy()
	end)

	it("removes a value", function()
		local context = setup()
		PromiseTestUtils.awaitFulfilled(context.service:PromiseWrite("code-2", { A = 1 }))
		PromiseTestUtils.awaitFulfilled(context.service:PromiseRemove("code-2"))
		expect(PromiseTestUtils.awaitFulfilled(context.service:PromiseRead("code-2"))).toBeNil()

		context:Destroy()
	end)

	it("surfaces datastore failures as rejections", function()
		local context = setup()
		context.mock:FailNextRequests(1)
		PromiseTestUtils.awaitRejected(context.service:PromiseWrite("code-3", { A = 1 }))

		context:Destroy()
	end)
end)
