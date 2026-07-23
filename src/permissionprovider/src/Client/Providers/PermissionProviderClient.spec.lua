--!strict
--[[
	Coverage for PermissionProviderClient against a stubbed server remote. Headless sessions
	(RunService:IsRunning() == false) hand out detached mock RemoteFunctions that can never reach a
	server realm, so tests inject the remote promise the provider caches and answer InvokeServer
	directly. The deny case assumes RunService:IsStudio() == false (true in the cloud test runner);
	in Studio the provider short-circuits every answer to true.

	@class PermissionProviderClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local PermissionProviderClient = require("PermissionProviderClient")
local PermissionProviderConstants = require("PermissionProviderConstants")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LOCAL_USER_ID = 88771001

local function setup()
	local maid = Maid.new()

	local localPlayer = maid:Add(PlayerMock.new({ UserId = LOCAL_USER_ID }))
	localPlayer.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(localPlayer)

	return {
		localPlayer = localPlayer,
		makeProvider = function(invokeServer: (() -> any)?): any
			local provider: any = PermissionProviderClient.new("PermissionProviderClientSpecRemote")
			if invokeServer then
				provider._remoteFunctionPromise = Promise.resolved({
					InvokeServer = function(_self)
						return invokeServer()
					end,
				})
			end
			return provider
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
		awaitError = function(promise: any): string
			expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
			local ok, err = promise:Yield()
			expect(ok).toEqual(false)
			return tostring(err)
		end,
		destroy = function(_self)
			PlayerMock.setMockedLocalPlayer(nil)
			maid:DoCleaning()
		end,
	}
end

describe("PermissionProviderClient construction", function()
	it("defaults the remote function name when none is given", function()
		local provider: any = PermissionProviderClient.new(nil :: any)

		expect(provider._remoteFunctionName).toEqual(PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME)
	end)

	it("uses the provided remote function name", function()
		local provider: any = PermissionProviderClient.new("PermissionProviderClientSpecRemote")

		expect(provider._remoteFunctionName).toEqual("PermissionProviderClientSpecRemote")
	end)
end)

describe("PermissionProviderClient.PromiseIsAdmin argument validation", function()
	it("rejects a non-player value", function()
		local controller = setup()
		local provider = controller.makeProvider()

		expect(function()
			provider:PromiseIsAdmin(5 :: any)
		end).toThrow("Bad player")

		controller:destroy()
	end)

	it("rejects a player other than the designated local player", function()
		local controller = setup()
		local provider = controller.makeProvider()
		local otherPlayer = controller.fakePlayer(LOCAL_USER_ID + 1)

		expect(function()
			provider:PromiseIsAdmin(otherPlayer)
		end).toThrow("We only support local player")

		controller:destroy()
	end)
end)

describe("PermissionProviderClient.PromiseIsAdmin", function()
	it("resolves the server's answer for the designated local player", function()
		local controller = setup()
		local provider = controller.makeProvider(function()
			return true
		end)

		expect(controller.awaitBool(provider:PromiseIsAdmin(controller.localPlayer))).toEqual(true)

		controller:destroy()
	end)

	it("resolves the server's answer for a nil player", function()
		local controller = setup()
		local provider = controller.makeProvider(function()
			return true
		end)

		expect(controller.awaitBool(provider:PromiseIsAdmin(nil))).toEqual(true)

		controller:destroy()
	end)

	it("denies when the server answers false", function()
		local controller = setup()
		local provider = controller.makeProvider(function()
			return false
		end)

		expect(controller.awaitBool(provider:PromiseIsAdmin(controller.localPlayer))).toEqual(false)

		controller:destroy()
	end)

	it("rejects a non-boolean server answer", function()
		local controller = setup()
		local provider = controller.makeProvider(function()
			return "yes"
		end)

		local message = controller.awaitError(provider:PromiseIsAdmin(controller.localPlayer))
		expect(message).toContain("Got non-boolean from server")

		controller:destroy()
	end)

	it("rejects when the server invoke throws", function()
		local controller = setup()
		local provider = controller.makeProvider(function()
			error("Server invoke failed")
		end)

		local message = controller.awaitError(provider:PromiseIsAdmin(controller.localPlayer))
		expect(message).toContain("Server invoke failed")

		controller:destroy()
	end)

	it("caches the admin answer across calls", function()
		local controller = setup()
		local invokeCount = 0
		local provider = controller.makeProvider(function()
			invokeCount += 1
			return true
		end)

		local first = provider:PromiseIsAdmin(controller.localPlayer)
		local second = provider:PromiseIsAdmin(controller.localPlayer)

		expect(second).toBe(first)
		expect(controller.awaitBool(first)).toEqual(true)
		expect(invokeCount).toEqual(1)

		controller:destroy()
	end)
end)
