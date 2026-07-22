--!strict
--[[
	The leak and concurrency tests call Init directly on a bare service instance: ServiceBag runs
	service Inits in their own thread, so a throw cannot be observed through serviceBag:Init().

	@class PlayerMockService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local PlayerMockServiceClient = require("PlayerMockServiceClient")
local ServiceBag = require("ServiceBag")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach
local beforeEach = Jest.Globals.beforeEach

describe("PlayerMockService", function()
	local maid

	beforeEach(function()
		maid = Maid.new()
	end)

	afterEach(function()
		maid:DoCleaning()
	end)

	local function makeService(): any
		local serviceBag = maid:Add(ServiceBag.new())
		local service = serviceBag:GetService(PlayerMockService)
		serviceBag:Init()
		serviceBag:Start()
		return service
	end

	local function makeClientService(): any
		local serviceBag = maid:Add(ServiceBag.new())
		local service = serviceBag:GetService(PlayerMockServiceClient)
		serviceBag:Init()
		serviceBag:Start()
		return service
	end

	it("creates a mock parented into the world and discovers it", function()
		local service = makeService()

		local player = service:CreatePlayer({ UserId = 12345 })

		expect(PlayerMock.isMock(player)).toBe(true)
		expect(PlayerMock.read(player, "UserId")).toBe(12345)
		expect((player :: Instance):IsDescendantOf(game)).toBe(true)
		expect(service:GetPlayerMocks()).toEqual({ player })
	end)

	it("discovers its mock from a client-realm service in another bag", function()
		local service = makeService()
		local clientService = makeClientService()

		local player = service:CreatePlayer()

		expect(clientService:GetPlayerMocks()).toEqual({ player })
	end)

	it("discovers a mock created before the service booted", function()
		local player = maid:Add(PlayerMock.new({ UserId = 1 }))
		player.Parent = workspace

		local service = makeService()

		expect(service:GetPlayerMocks()).toEqual({ player })
	end)

	it("discovers a hand-built mock once parented", function()
		local service = makeService()

		local player = maid:Add(PlayerMock.new({ UserId = 1 }))
		expect(service:GetPlayerMocks()).toEqual({})

		player.Parent = workspace

		expect(service:GetPlayerMocks()).toEqual({ player })
	end)

	it("observes mocks created before and after the observation started, across realms", function()
		local service = makeService()
		local clientService = makeClientService()

		local before = service:CreatePlayer({ UserId = 1 })

		local seen = {}
		maid:GiveTask(clientService:ObservePlayerMocks():Subscribe(function(observed)
			table.insert(seen, observed)
		end))

		local after = service:CreatePlayer({ UserId = 2 })
		StepUtils.deferWait()

		expect(seen).toEqual({ before, after })
	end)

	it("stops observing after unsubscribe", function()
		local service = makeService()

		local seen = {}
		local subscription = service:ObservePlayerMocks():Subscribe(function(observed)
			table.insert(seen, observed)
		end)
		subscription:Destroy()

		service:CreatePlayer()
		StepUtils.deferWait()

		expect(seen).toEqual({})
	end)

	it("drops a kicked mock from discovery", function()
		local service = makeService()

		local player = service:CreatePlayer()
		PlayerMock.kick(player, "gone")

		expect(service:GetPlayerMocks()).toEqual({})
	end)

	it("destroys its created mocks on teardown", function()
		local clientService = makeClientService()

		local teardownMaid = Maid.new()
		local serviceBag = teardownMaid:Add(ServiceBag.new())
		local teardownService: any = serviceBag:GetService(PlayerMockService)
		serviceBag:Init()
		serviceBag:Start()

		local player = teardownService:CreatePlayer()
		teardownMaid:DoCleaning()

		expect((player :: Instance).Parent).toBeNil()
		expect(clientService:GetPlayerMocks()).toEqual({})
	end)

	it("fails when a mock outlived the service that consumed it", function()
		local firstMaid = Maid.new()
		local firstBag = firstMaid:Add(ServiceBag.new())
		firstBag:GetService(PlayerMockService)
		firstBag:Init()
		firstBag:Start()

		local leaked = maid:Add(PlayerMock.new({ UserId = 1 }))
		leaked.Parent = workspace

		firstMaid:DoCleaning()

		local uninitialized = setmetatable({}, { __index = PlayerMockService })
		expect(function()
			uninitialized:Init(maid:Add(ServiceBag.new()) :: any)
		end).toThrow("leaked")
	end)

	it("fails when a second server-realm service boots alongside a live one", function()
		local service = makeService()
		service:CreatePlayer()

		local second = setmetatable({}, { __index = PlayerMockService })
		expect(function()
			second:Init(maid:Add(ServiceBag.new()) :: any)
		end).toThrow("alive at once")
	end)
end)
