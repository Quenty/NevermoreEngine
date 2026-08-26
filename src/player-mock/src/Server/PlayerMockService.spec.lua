--!strict
--[[
	The leak and concurrency tests call Init directly on a bare service instance: ServiceBag runs
	service Inits in their own thread, so a throw cannot be observed through serviceBag:Init().

	@class PlayerMockService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
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
			local service = serviceBag:GetService(PlayerMockService)
			serviceBag:Init()
			serviceBag:Start()
			return service
		end,
		newClientService = function(): any
			local serviceBag = maid:Add(ServiceBag.new())
			local service = serviceBag:GetService(PlayerMockServiceClient)
			serviceBag:Init()
			serviceBag:Start()
			return service
		end,
		newLooseService = function(): (any, any)
			local serviceBag = ServiceBag.new()
			local service = serviceBag:GetService(PlayerMockService)
			serviceBag:Init()
			serviceBag:Start()
			return serviceBag, service
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("PlayerMockService", function()
	it("creates a mock parented into the world and discovers it", function()
		local controller = setup()

		local service = controller.newService()

		local player = service:CreatePlayer({ UserId = 12345 })

		expect(PlayerMock.isMock(player)).toBe(true)
		expect(PlayerMock.read(player, "UserId")).toBe(12345)
		expect((player :: Instance):IsDescendantOf(game)).toBe(true)
		expect(service:GetPlayerMocks()).toEqual({ player })

		controller.destroy()
	end)

	it("discovers its mock from a client-realm service in another bag", function()
		local controller = setup()

		local service = controller.newService()
		local clientService = controller.newClientService()

		local player = service:CreatePlayer()

		expect(clientService:GetPlayerMocks()).toEqual({ player })

		controller.destroy()
	end)

	it("discovers a mock created before the service booted", function()
		local controller = setup()

		local player = controller.maid:Add(PlayerMock.new({ UserId = 1 }))
		player.Parent = workspace

		local service = controller.newService()

		expect(service:GetPlayerMocks()).toEqual({ player })

		controller.destroy()
	end)

	it("discovers a hand-built mock once parented", function()
		local controller = setup()

		local service = controller.newService()

		local player = controller.maid:Add(PlayerMock.new({ UserId = 1 }))
		expect(service:GetPlayerMocks()).toEqual({})

		player.Parent = workspace

		expect(service:GetPlayerMocks()).toEqual({ player })

		controller.destroy()
	end)

	it("observes mocks created before and after the observation started, across realms", function()
		local controller = setup()

		local service = controller.newService()
		local clientService = controller.newClientService()

		local before = service:CreatePlayer({ UserId = 1 })

		local seen = {}
		controller.maid:GiveTask(clientService:ObservePlayerMocks():Subscribe(function(observed)
			table.insert(seen, observed)
		end))

		local after = service:CreatePlayer({ UserId = 2 })
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

		service:CreatePlayer()
		StepUtils.deferWait()

		expect(seen).toEqual({})

		controller.destroy()
	end)

	it("drops a kicked mock from discovery", function()
		local controller = setup()

		local service = controller.newService()

		local player = service:CreatePlayer()
		PlayerMock.kick(player, "gone")

		expect(service:GetPlayerMocks()).toEqual({})

		controller.destroy()
	end)

	it("destroys its created mocks on teardown", function()
		local controller = setup()

		local clientService = controller.newClientService()

		local serviceBag, teardownService = controller.newLooseService()

		local player = teardownService:CreatePlayer()
		serviceBag:Destroy()

		expect((player :: Instance).Parent).toBeNil()
		expect(clientService:GetPlayerMocks()).toEqual({})

		controller.destroy()
	end)

	it("fails when a mock outlived the service that consumed it", function()
		local controller = setup()

		local firstBag = controller.newLooseService()

		local leaked = controller.maid:Add(PlayerMock.new({ UserId = 1 }))
		leaked.Parent = workspace

		firstBag:Destroy()

		local uninitialized = setmetatable({}, { __index = PlayerMockService })
		expect(function()
			uninitialized:Init(controller.maid:Add(ServiceBag.new()) :: any)
		end).toThrow("leaked")

		controller.destroy()
	end)

	it("fails when a second server-realm service boots alongside a live one", function()
		local controller = setup()

		local service = controller.newService()
		service:CreatePlayer()

		local second = setmetatable({}, { __index = PlayerMockService })
		expect(function()
			second:Init(controller.maid:Add(ServiceBag.new()) :: any)
		end).toThrow("alive at once")

		controller.destroy()
	end)
end)
