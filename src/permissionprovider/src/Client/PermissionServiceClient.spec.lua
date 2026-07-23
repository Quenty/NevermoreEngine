--!strict
--[[
	Coverage for PermissionServiceClient booted headless in a client ServiceBag against a
	pre-designated mock local player (designation precedes Init -- production parity, where
	Players.LocalPlayer exists before any service runs). Real remotes can never reach a server
	realm headless, so server answers are driven by stubbing the remote promise cached by the
	resolved PermissionProviderClient. The deny case assumes RunService:IsStudio() == false (true
	in the cloud test runner); in Studio the provider short-circuits every answer to true.

	Bad-player failures surface as synchronous throws, not rejections: the provider promise is
	already fulfilled, so the Then handler (and the provider's asserts) run inline at call time.

	@class PermissionServiceClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local PermissionServiceClient = require("PermissionServiceClient")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LOCAL_USER_ID = 88772001

local function setup()
	local maid = Maid.new()

	local localPlayer = maid:Add(PlayerMock.new({ UserId = LOCAL_USER_ID }))
	localPlayer.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(localPlayer)

	local serviceBag = maid:Add(ServiceBag.new())
	local service: PermissionServiceClient.PermissionServiceClient =
		serviceBag:GetService(PermissionServiceClient) :: any
	serviceBag:Init()
	serviceBag:Start()

	return {
		localPlayer = localPlayer,
		serviceBag = serviceBag,
		service = service,
		stubServerAnswer = function(invokeServer: () -> any)
			local ok, provider = service:PromisePermissionProvider():Yield()
			assert(ok, "No provider resolved")

			local anyProvider: any = provider
			anyProvider._remoteFunctionPromise = Promise.resolved({
				InvokeServer = function(_self)
					return invokeServer()
				end,
			})
		end,
		fakePlayer = function(userId: number): Player
			return maid:Add(PlayerMock.new({ UserId = userId }))
		end,
		awaitBool = function(promise: any): boolean
			expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			return value
		end,
		destroy = function(_self)
			PlayerMock.setMockedLocalPlayer(nil)
			maid:DoCleaning()
		end,
	}
end

describe("PermissionServiceClient initialization", function()
	it("resolves the permission provider immediately after init", function()
		local controller = setup()

		local promise = controller.service:PromisePermissionProvider()
		expect(promise:IsPending()).toEqual(false)

		local ok, provider = promise:Yield()
		expect(ok).toEqual(true)
		expect((provider :: any).ClassName).toEqual("PermissionProviderClient")

		controller:destroy()
	end)

	it("rejects double initialization", function()
		local controller = setup()

		local bare: any = setmetatable({}, { __index = PermissionServiceClient })
		bare:Init(controller.serviceBag)

		expect(function()
			bare:Init(controller.serviceBag)
		end).toThrow("Already initialized")

		bare:Destroy()
		controller:destroy()
	end)
end)

describe("PermissionServiceClient.PromiseIsAdmin", function()
	it("rejects a non-player value", function()
		local controller = setup()

		expect(function()
			controller.service:PromiseIsAdmin(5 :: any)
		end).toThrow("Bad player")

		controller:destroy()
	end)

	it("resolves the server's answer for the designated local player", function()
		local controller = setup()
		controller.stubServerAnswer(function()
			return true
		end)

		expect(controller.awaitBool(controller.service:PromiseIsAdmin(controller.localPlayer))).toEqual(true)

		controller:destroy()
	end)

	it("resolves the server's answer for a nil player", function()
		local controller = setup()
		controller.stubServerAnswer(function()
			return true
		end)

		expect(controller.awaitBool(controller.service:PromiseIsAdmin(nil))).toEqual(true)

		controller:destroy()
	end)

	it("denies the designated local player when the server answers false", function()
		local controller = setup()
		controller.stubServerAnswer(function()
			return false
		end)

		expect(controller.awaitBool(controller.service:PromiseIsAdmin(controller.localPlayer))).toEqual(false)

		controller:destroy()
	end)

	it("throws for a mock that is not the designated local player", function()
		local controller = setup()
		local otherPlayer = controller.fakePlayer(LOCAL_USER_ID + 1)

		expect(function()
			controller.service:PromiseIsAdmin(otherPlayer)
		end).toThrow("We only support local player")

		controller:destroy()
	end)

	it("caches the server answer across calls", function()
		local controller = setup()
		local invokeCount = 0
		controller.stubServerAnswer(function()
			invokeCount += 1
			return true
		end)

		expect(controller.awaitBool(controller.service:PromiseIsAdmin(controller.localPlayer))).toEqual(true)
		expect(controller.awaitBool(controller.service:PromiseIsAdmin(controller.localPlayer))).toEqual(true)
		expect(invokeCount).toEqual(1)

		controller:destroy()
	end)
end)
