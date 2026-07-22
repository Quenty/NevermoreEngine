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
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockServiceClient = require("PlayerMockServiceClient")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach
local beforeEach = Jest.Globals.beforeEach

describe("PlayerMockServiceClient", function()
	local maid

	beforeEach(function()
		maid = Maid.new()
	end)

	afterEach(function()
		maid:DoCleaning()
	end)

	local function makeService(): any
		local serviceBag = maid:Add(ServiceBag.new())
		local service = serviceBag:GetService(PlayerMockServiceClient)
		serviceBag:Init()
		serviceBag:Start()
		return service
	end

	local function newMock(userId: number): Player
		local player = maid:Add(PlayerMock.new({ UserId = userId }))
		player.Parent = workspace
		return player
	end

	it("sees a parented mock in GetPlayerMocks", function()
		local service = makeService()

		local player = newMock(1)

		expect(service:GetPlayerMocks()).toEqual({ player })
	end)

	it("observes mocks parented before and after the observation started", function()
		local service = makeService()

		local before = newMock(1)

		local seen = {}
		maid:GiveTask(service:ObservePlayerMocks(function(observed)
			table.insert(seen, observed)
		end))

		local after = newMock(2)

		expect(seen).toEqual({ before, after })
	end)

	it("stops observing after disconnect", function()
		local service = makeService()

		local seen = {}
		local disconnect = service:ObservePlayerMocks(function(observed)
			table.insert(seen, observed)
		end)
		disconnect()

		newMock(1)

		expect(seen).toEqual({})
	end)

	it("tolerates concurrent client services sharing the place's mocks", function()
		local service = makeService()
		local otherService = makeService()

		local player = newMock(1)

		expect(service:GetPlayerMocks()).toEqual({ player })
		expect(otherService:GetPlayerMocks()).toEqual({ player })
	end)

	it("designates the mocked local player and records it per service", function()
		local service = makeService()

		local player = newMock(1)
		service:SetLocalPlayer(player)

		expect(PlayerMock.getMockedLocalPlayer()).toBe(player)
		expect(service:GetLocalPlayer()).toBe(player)
	end)

	it("keeps its own local player when another client designates a different mock", function()
		local service = makeService()
		local otherService = makeService()

		local first = newMock(1)
		local second = newMock(2)
		service:SetLocalPlayer(first)
		otherService:SetLocalPlayer(second)

		expect(service:GetLocalPlayer()).toBe(first)
		expect(otherService:GetLocalPlayer()).toBe(second)
		expect(PlayerMock.getMockedLocalPlayer()).toBe(second)
	end)

	it("adopts a designation made before the bag booted", function()
		local player = newMock(1)
		PlayerMock.setMockedLocalPlayer(player)

		local service = makeService()

		expect(service:GetLocalPlayer()).toBe(player)
	end)

	it("clears the designation when the service is destroyed", function()
		local serviceMaid = Maid.new()
		local serviceBag = serviceMaid:Add(ServiceBag.new())
		local service: any = serviceBag:GetService(PlayerMockServiceClient)
		serviceBag:Init()
		serviceBag:Start()

		local player = newMock(1)
		service:SetLocalPlayer(player)
		serviceMaid:DoCleaning()

		expect(PlayerMock.getMockedLocalPlayer()).toBeNil()
	end)

	it("clears an adopted pre-boot designation when the service is destroyed", function()
		local player = newMock(1)
		PlayerMock.setMockedLocalPlayer(player)

		local serviceMaid = Maid.new()
		local serviceBag = serviceMaid:Add(ServiceBag.new())
		serviceBag:GetService(PlayerMockServiceClient)
		serviceBag:Init()
		serviceBag:Start()

		serviceMaid:DoCleaning()

		expect(PlayerMock.getMockedLocalPlayer()).toBeNil()
	end)

	it("fails when a mock outlived the service that consumed it", function()
		local firstMaid = Maid.new()
		local firstBag = firstMaid:Add(ServiceBag.new())
		firstBag:GetService(PlayerMockServiceClient)
		firstBag:Init()
		firstBag:Start()

		local _leaked = newMock(1)

		firstMaid:DoCleaning()

		local uninitialized = setmetatable({}, { __index = PlayerMockServiceClient })
		expect(function()
			uninitialized:Init(maid:Add(ServiceBag.new()) :: any)
		end).toThrow("leaked")
	end)
end)
