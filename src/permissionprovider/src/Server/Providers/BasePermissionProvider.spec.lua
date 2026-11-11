--!strict
--[[
	@class BasePermissionProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BasePermissionProvider = require("BasePermissionProvider")
local Jest = require("Jest")
local Maid = require("Maid")
local PermissionLevel = require("PermissionLevel")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function createStubProvider(maid: Maid.Maid, promiseFactory: () -> any)
	local StubPermissionProvider = setmetatable({}, BasePermissionProvider)
	StubPermissionProvider.ClassName = "StubPermissionProvider"
	StubPermissionProvider.__index = StubPermissionProvider

	local queriedLevels = {}

	function StubPermissionProvider.PromiseIsPermissionLevel(_self: any, _player: any, permissionLevel: any)
		table.insert(queriedLevels, permissionLevel)
		return promiseFactory()
	end

	local config = PermissionProviderUtils.createSingleUserConfig({ userId = 12345 })
	local provider = maid:Add(setmetatable(BasePermissionProvider.new(config) :: any, StubPermissionProvider))

	return provider, queriedLevels
end

describe("BasePermissionProvider.new", function()
	it("should reject a nil config", function()
		expect(function()
			BasePermissionProvider.new(nil :: any)
		end).toThrow("Bad config")
	end)

	it("should reject a config without a remote function name", function()
		expect(function()
			BasePermissionProvider.new({} :: any)
		end).toThrow("remoteFunctionName")
	end)
end)

describe("BasePermissionProvider.PromiseIsPermissionLevel", function()
	it("should error as not implemented on the base class", function()
		local maid = Maid.new()
		local provider =
			maid:Add(BasePermissionProvider.new(PermissionProviderUtils.createSingleUserConfig({ userId = 12345 })))
		local player = maid:Add(PlayerMock.new({ UserId = 12345 }))

		expect(function()
			provider:PromiseIsPermissionLevel(player, PermissionLevel.ADMIN)
		end).toThrow("Not implemented")

		maid:DoCleaning()
	end)

	it("should reject a non-player value", function()
		local maid = Maid.new()
		local provider =
			maid:Add(BasePermissionProvider.new(PermissionProviderUtils.createSingleUserConfig({ userId = 12345 })))

		expect(function()
			provider:PromiseIsPermissionLevel(nil :: any, PermissionLevel.ADMIN)
		end).toThrow("Bad player")

		maid:DoCleaning()
	end)
end)

describe("BasePermissionProvider.IsPermissionLevel", function()
	it("should return false while the underlying promise is pending", function()
		local maid = Maid.new()
		local provider = createStubProvider(maid, function()
			return maid:Add(Promise.new())
		end)
		local player = maid:Add(PlayerMock.new({ UserId = 12345 }))

		expect(provider:IsPermissionLevel(player, PermissionLevel.ADMIN)).toEqual(false)

		maid:DoCleaning()
	end)

	it("should return the resolved value when the promise settles synchronously", function()
		local maid = Maid.new()
		local provider = createStubProvider(maid, function()
			return Promise.resolved(true)
		end)
		local player = maid:Add(PlayerMock.new({ UserId = 12345 }))

		expect(provider:IsPermissionLevel(player, PermissionLevel.ADMIN)).toEqual(true)
		expect(provider:IsCreator(player)).toEqual(true)
		expect(provider:IsAdmin(player)).toEqual(true)

		maid:DoCleaning()
	end)

	it("should return false when the underlying promise rejects", function()
		local maid = Maid.new()
		local provider = createStubProvider(maid, function()
			local promise = Promise.rejected("simulated failure")
			promise:Catch(function() end)
			return promise
		end)
		local player = maid:Add(PlayerMock.new({ UserId = 12345 }))

		expect(provider:IsPermissionLevel(player, PermissionLevel.ADMIN)).toEqual(false)

		maid:DoCleaning()
	end)
end)

describe("BasePermissionProvider promise wrappers", function()
	it("should route PromiseIsAdmin and PromiseIsCreator through the matching level", function()
		local maid = Maid.new()
		local provider, queriedLevels = createStubProvider(maid, function()
			return Promise.resolved(true)
		end)
		local player = maid:Add(PlayerMock.new({ UserId = 12345 }))

		provider:PromiseIsAdmin(player)
		provider:PromiseIsCreator(player)

		expect(queriedLevels).toEqual({ PermissionLevel.ADMIN, PermissionLevel.CREATOR } :: { string })

		maid:DoCleaning()
	end)
end)
