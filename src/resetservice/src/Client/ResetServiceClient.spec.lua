--!strict
--[[
	Dual-realm integration coverage for ResetServiceClient. Boots a SERVER and a CLIENT ServiceBag
	in the same DataModel and drives a reset end-to-end against a PlayerMock designated as the
	simulated client's local player -- the client kills the local humanoid and the request crosses
	the production remoting path to the server's reset provider.

	@class ResetServiceClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local PlayerMockServiceClient = require("PlayerMockServiceClient")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local ResetService = require("ResetService")
local ResetServiceClient = require("ResetServiceClient")
local RigBuilderUtils = require("RigBuilderUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LOAD_CHARACTER_TIMEOUT = 30

local specCounter = 0

local function setup()
	specCounter += 1

	local serverBag = ServiceBag.new()
	local resetService: any = serverBag:GetService(ResetService)
	local playerMockService: any = serverBag:GetService(PlayerMockService)
	serverBag:Init()
	serverBag:Start()

	local mock = playerMockService:CreatePlayer({ UserId = 77911300 + specCounter })

	local clientBag = ServiceBag.new()
	local resetServiceClient: any = clientBag:GetService(ResetServiceClient)
	local playerMockServiceClient: any = clientBag:GetService(PlayerMockServiceClient)
	clientBag:Init()
	playerMockServiceClient:SetLocalPlayer(mock)
	clientBag:Start()

	return {
		serverBag = serverBag,
		clientBag = clientBag,
		resetService = resetService,
		resetServiceClient = resetServiceClient,
		mock = mock,
		loadRig = function(_self): (Model, Humanoid)
			local character = PlayerMock.loadCharacterAsync(mock, RigBuilderUtils.createR6BaseRig())
			return character, assert(character:FindFirstChildOfClass("Humanoid"), "No humanoid in rig")
		end,
		destroy = function(_self)
			-- Client bags first: the server bag owns the mock, and destroying it out from under a
			-- live client is not something production ever does.
			clientBag:Destroy()
			serverBag:Destroy()
		end,
	}
end

describe("ResetServiceClient dual-realm boot", function()
	it("boots both the server and client reset services", function()
		local controller = setup()

		expect(controller.resetService).never.toBeNil()
		expect(controller.resetServiceClient).never.toBeNil()

		controller:destroy()
	end)
end)

describe("ResetServiceClient.PromiseResetCharacter", function()
	it("kills the local humanoid and reaches the server reset provider", function()
		local controller = setup()

		local _character, humanoid = controller:loadRig()

		local resetPlayers = {}
		controller.resetService:PushResetProvider(function(player: Player)
			table.insert(resetPlayers, player)
			return Promise.resolved("custom")
		end)

		local promise = controller.resetServiceClient:PromiseResetCharacter()
		expect(PromiseTestUtils.awaitSettled(promise, 10)).toBe(true)

		local ok, value = promise:Yield()
		expect(ok).toBe(true)
		expect(value).toBe("custom")
		expect(humanoid.Health).toBe(0)
		expect(resetPlayers).toEqual({ controller.mock })

		controller:destroy()
	end)

	it("respawns the character through the default reset provider", function()
		local controller = setup()

		local character = controller:loadRig()

		local promise = controller.resetServiceClient:PromiseResetCharacter()
		expect(PromiseTestUtils.awaitSettled(promise, LOAD_CHARACTER_TIMEOUT)).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)

		local newCharacter = PlayerMock.read(controller.mock, "Character")
		expect(newCharacter).never.toBeNil()
		expect(newCharacter).never.toBe(character)
		expect(character.Parent).toBeNil()

		controller:destroy()
	end)

	it("resets without a character", function()
		local controller = setup()

		controller.resetService:PushResetProvider(function()
			return Promise.resolved("custom")
		end)

		local promise = controller.resetServiceClient:PromiseResetCharacter()
		expect(PromiseTestUtils.awaitSettled(promise, 10)).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)

		controller:destroy()
	end)
end)

describe("ResetServiceClient.RequestResetCharacter", function()
	it("requests a reset the same way as PromiseResetCharacter", function()
		local controller = setup()

		local _character, humanoid = controller:loadRig()

		local resetPlayers = {}
		controller.resetService:PushResetProvider(function(player: Player)
			table.insert(resetPlayers, player)
			return Promise.resolved("custom")
		end)

		local promise = controller.resetServiceClient:RequestResetCharacter()
		expect(PromiseTestUtils.awaitSettled(promise, 10)).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)
		expect(humanoid.Health).toBe(0)
		expect(resetPlayers).toEqual({ controller.mock })

		controller:destroy()
	end)
end)

describe("ResetServiceClient.PushDisable", function()
	it("starts enabled", function()
		local controller = setup()

		expect(controller.resetServiceClient:IsDisabled()).toBe(false)

		controller:destroy()
	end)

	it("disables while a state is held and re-enables once it is popped", function()
		local controller = setup()

		local cancel = controller.resetServiceClient:PushDisable()
		expect(controller.resetServiceClient:IsDisabled()).toBe(true)

		cancel()
		expect(controller.resetServiceClient:IsDisabled()).toBe(false)

		controller:destroy()
	end)

	it("stays disabled until every pushed state is popped", function()
		local controller = setup()

		local cancelFirst = controller.resetServiceClient:PushDisable()
		local cancelSecond = controller.resetServiceClient:PushDisable()

		cancelFirst()
		expect(controller.resetServiceClient:IsDisabled()).toBe(true)

		cancelSecond()
		expect(controller.resetServiceClient:IsDisabled()).toBe(false)

		controller:destroy()
	end)

	it("emits each disabled state to observers", function()
		local controller = setup()

		local states = {}
		local sub = controller.resetServiceClient:ObserveIsDisabled():Subscribe(function(disabled)
			table.insert(states, disabled)
		end)

		local cancel = controller.resetServiceClient:PushDisable()
		cancel()

		expect(states).toEqual({ false, true, false })

		sub:Destroy()
		controller:destroy()
	end)

	it("still resets programmatically while disabled", function()
		local controller = setup()

		controller.resetServiceClient:PushDisable()

		local resetPlayers = {}
		controller.resetService:PushResetProvider(function(player: Player)
			table.insert(resetPlayers, player)
			return Promise.resolved("custom")
		end)

		local promise = controller.resetServiceClient:PromiseResetCharacter()
		expect(PromiseTestUtils.awaitSettled(promise, 10)).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)
		expect(resetPlayers).toEqual({ controller.mock })

		controller:destroy()
	end)
end)

describe("ResetServiceClient reset button callback", function()
	it("resets when the bindable bound to ResetButtonCallback fires", function()
		local controller = setup()

		local _character, humanoid = controller:loadRig()

		local resetPlayers = {}
		controller.resetService:PushResetProvider(function(player: Player)
			table.insert(resetPlayers, player)
			return Promise.resolved("custom")
		end)

		controller.resetServiceClient._resetBindable:Fire()

		expect(PromiseTestUtils.awaitValue(function()
			return #resetPlayers == 1
		end, 10)).toBe(true)
		expect(humanoid.Health).toBe(0)
		expect(resetPlayers).toEqual({ controller.mock })

		controller:destroy()
	end)
end)
