--!strict
--[[
	The "server side" is stood in by parenting hand-built mocks -- replication is the default, so
	parenting is all CreatePlayer adds. The leak test calls Init directly on a bare service instance:
	ServiceBag runs service Inits in their own thread, so a throw cannot be observed through
	serviceBag:Init().

	@class PlayerMockServiceClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockServiceClient = require("PlayerMockServiceClient")
local ServiceBag = require("ServiceBag")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		maid = maid,
		newService = function(): any
			local serviceBag = maid:Add(ServiceBag.new())
			local service = serviceBag:GetService(PlayerMockServiceClient)
			serviceBag:Init()
			serviceBag:Start()
			return service
		end,
		newLooseService = function(): (any, any)
			local serviceBag = ServiceBag.new()
			local service = serviceBag:GetService(PlayerMockServiceClient)
			serviceBag:Init()
			serviceBag:Start()
			return serviceBag, service
		end,
		newMock = function(userId: number): Player
			local player = maid:Add(PlayerMock.new({ UserId = userId }))
			player.Parent = workspace
			return player
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("PlayerMockServiceClient", function()
	it("sees a parented mock in GetPlayerMocks", function()
		local controller = setup()

		local service = controller.newService()

		local player = controller.newMock(1)

		expect(service:GetPlayerMocks()).toEqual({ player })

		controller.destroy()
	end)

	it("observes mocks parented before and after the observation started", function()
		local controller = setup()

		local service = controller.newService()

		local before = controller.newMock(1)

		local seen = {}
		controller.maid:GiveTask(service:ObservePlayerMocks():Subscribe(function(observed)
			table.insert(seen, observed)
		end))

		local after = controller.newMock(2)
		StepUtils.deferWait()

		expect(seen).toEqual({ before, after })

		controller.destroy()
	end)

	it("stops observing after unsubscribe", function()
		local controller = setup()

		local service = controller.newService()

		local seen = {}
		local subscription = service:ObservePlayerMocks():Subscribe(function(observed)
			table.insert(seen, observed)
		end)
		subscription:Destroy()

		controller.newMock(1)
		StepUtils.deferWait()

		expect(seen).toEqual({})

		controller.destroy()
	end)

	it("tolerates concurrent client services sharing the place's mocks", function()
		local controller = setup()

		local service = controller.newService()
		local otherService = controller.newService()

		local player = controller.newMock(1)

		expect(service:GetPlayerMocks()).toEqual({ player })
		expect(otherService:GetPlayerMocks()).toEqual({ player })

		controller.destroy()
	end)

	it("designates the mocked local player and records it per service", function()
		local controller = setup()

		local service = controller.newService()

		local player = controller.newMock(1)
		service:SetLocalPlayer(player)

		expect(PlayerMock.getMockedLocalPlayer()).toBe(player)
		expect(service:GetLocalPlayer()).toBe(player)

		controller.destroy()
	end)

	it("keeps its own local player when another client designates a different mock", function()
		local controller = setup()

		local service = controller.newService()
		local otherService = controller.newService()

		local first = controller.newMock(1)
		local second = controller.newMock(2)
		service:SetLocalPlayer(first)
		otherService:SetLocalPlayer(second)

		expect(service:GetLocalPlayer()).toBe(first)
		expect(otherService:GetLocalPlayer()).toBe(second)
		expect(PlayerMock.getMockedLocalPlayer()).toBe(second)

		controller.destroy()
	end)

	it("adopts a designation made before the bag booted", function()
		local controller = setup()

		local player = controller.newMock(1)
		PlayerMock.setMockedLocalPlayer(player)

		local service = controller.newService()

		expect(service:GetLocalPlayer()).toBe(player)

		controller.destroy()
	end)

	it("clears the designation when the service is destroyed", function()
		local controller = setup()

		local serviceBag, service = controller.newLooseService()

		local player = controller.newMock(1)
		service:SetLocalPlayer(player)
		serviceBag:Destroy()

		expect(PlayerMock.getMockedLocalPlayer()).toBeNil()

		controller.destroy()
	end)

	it("clears an adopted pre-boot designation when the service is destroyed", function()
		local controller = setup()

		local player = controller.newMock(1)
		PlayerMock.setMockedLocalPlayer(player)

		local serviceBag = controller.newLooseService()

		serviceBag:Destroy()

		expect(PlayerMock.getMockedLocalPlayer()).toBeNil()

		controller.destroy()
	end)

	it("fails when a mock outlived the service that consumed it", function()
		local controller = setup()

		local firstBag = controller.newLooseService()

		local _leaked = controller.newMock(1)

		firstBag:Destroy()

		local uninitialized = setmetatable({}, { __index = PlayerMockServiceClient })
		expect(function()
			uninitialized:Init(controller.maid:Add(ServiceBag.new()) :: any)
		end).toThrow("leaked")

		controller.destroy()
	end)
end)
