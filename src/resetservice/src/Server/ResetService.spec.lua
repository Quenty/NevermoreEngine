--!strict
--[[
	@class ResetService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local ResetService = require("ResetService")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LOAD_CHARACTER_TIMEOUT = 30

local specCounter = 0

local function setup()
	specCounter += 1

	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local resetService: any = serviceBag:GetService(ResetService)
	local playerMockService: any = serviceBag:GetService(PlayerMockService)

	serviceBag:Init()
	serviceBag:Start()

	local mock = playerMockService:CreatePlayer({ UserId = 77341200 + specCounter })

	local controller = {
		serviceBag = serviceBag,
		resetService = resetService,
		mock = mock,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("ResetService.PromiseResetCharacter", function()
	it("loads a new character through the default reset provider", function()
		local controller = setup()

		expect(PlayerMock.read(controller.mock, "Character")).toBeNil()

		local promise = controller.resetService:PromiseResetCharacter(controller.mock)
		expect(PromiseTestUtils.awaitSettled(promise, LOAD_CHARACTER_TIMEOUT)).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)

		local character = PlayerMock.read(controller.mock, "Character")
		expect(character).never.toBeNil()
		expect(character:FindFirstChildOfClass("Humanoid")).never.toBeNil()

		controller:Destroy()
	end)

	it("rejects a player that is not in the DataModel", function()
		local controller = setup()

		local orphan = PlayerMock.new({ UserId = 77341999 })

		local promise = controller.resetService:PromiseResetCharacter(orphan)
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toBe(true)
		expect(promise:IsRejected()).toBe(true)

		orphan:Destroy()
		controller:Destroy()
	end)

	it("rejects a bad player", function()
		local controller = setup()

		expect(function()
			controller.resetService:PromiseResetCharacter(nil)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("ResetService.PushResetProvider", function()
	it("routes the reset through the pushed provider instead of the default", function()
		local controller = setup()

		local resetPlayers = {}
		controller.resetService:PushResetProvider(function(player: Player)
			table.insert(resetPlayers, player)
			return Promise.resolved("custom")
		end)

		local promise = controller.resetService:PromiseResetCharacter(controller.mock)
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toBe(true)

		local ok, value = promise:Yield()
		expect(ok).toBe(true)
		expect(value).toBe("custom")
		expect(resetPlayers).toEqual({ controller.mock })

		-- The default provider never ran, so no character was spawned.
		expect(PlayerMock.read(controller.mock, "Character")).toBeNil()

		controller:Destroy()
	end)

	it("restores the previous provider once the pushed one is popped", function()
		local controller = setup()

		local firstCount = 0
		controller.resetService:PushResetProvider(function()
			firstCount += 1
			return Promise.resolved("first")
		end)

		local popSecond = controller.resetService:PushResetProvider(function()
			return Promise.resolved("second")
		end)

		local promise = controller.resetService:PromiseResetCharacter(controller.mock)
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toBe(true)
		local _, value = promise:Yield()
		expect(value).toBe("second")
		expect(firstCount).toBe(0)

		popSecond()

		local afterPop = controller.resetService:PromiseResetCharacter(controller.mock)
		expect(PromiseTestUtils.awaitSettled(afterPop, 5)).toBe(true)
		local _, afterValue = afterPop:Yield()
		expect(afterValue).toBe("first")
		expect(firstCount).toBe(1)

		controller:Destroy()
	end)

	it("rejects a bad provider", function()
		local controller = setup()

		expect(function()
			controller.resetService:PushResetProvider("not a function")
		end).toThrow()

		controller:Destroy()
	end)
end)
