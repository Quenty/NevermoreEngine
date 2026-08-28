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

local function runWithContext(body)
	local context = setup()
	local ok, err = pcall(body, context)
	context:Destroy()
	if not ok then
		error(err, 0)
	end
end

local function awaitValueOf(promise)
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		error("promise hung", 0)
	end
	local ok, value = promise:Yield()
	if not ok then
		error(`promise rejected: {tostring(value)}`, 0)
	end
	return value
end

local function awaitResolved(promise): boolean
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		error("promise hung", 0)
	end
	return (promise:Yield())
end

describe("SaveSlotSharedDataStoreService", function()
	it("round-trips a value by key", function()
		runWithContext(function(context)
			awaitValueOf(context.service:PromiseWrite("code-1", { Coins = 9, World = { Eggs = 2 } }))

			local value = awaitValueOf(context.service:PromiseRead("code-1"))
			expect(value.Coins).toEqual(9)
			expect(value.World.Eggs).toEqual(2)
		end)
	end)

	it("reads nil for an absent key", function()
		runWithContext(function(context)
			expect(awaitValueOf(context.service:PromiseRead("missing"))).toBeNil()
		end)
	end)

	it("removes a value", function()
		runWithContext(function(context)
			awaitValueOf(context.service:PromiseWrite("code-2", { A = 1 }))
			awaitValueOf(context.service:PromiseRemove("code-2"))
			expect(awaitValueOf(context.service:PromiseRead("code-2"))).toBeNil()
		end)
	end)

	it("surfaces datastore failures as rejections", function()
		runWithContext(function(context)
			context.mock:FailNextRequests(1)
			expect(awaitResolved(context.service:PromiseWrite("code-3", { A = 1 }))).toEqual(false)
		end)
	end)
end)
