--!nonstrict
--[[
	Coverage for TeleportDataService's pure data-assembly and arrived-data surface -- the parts
	reachable on a headless cloud test server (which has no joined players, so arrived data is
	exercised through the test seam rather than a real teleport).

	@class TeleportDataService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Controller pattern (see docs/testing/testing.md): the maid owns the ServiceBag and every fake
-- player folder, so a batch run leaves nothing running in a later package's window.
local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local service = serviceBag:GetService(require("TeleportDataService"))
	serviceBag:Init()

	return {
		service = service,
		-- A Folder is an Instance, so it satisfies the `typeof(player) == "Instance"` guards and can
		-- stand in for a Player as long as arrived data is injected (never hitting GetJoinData).
		fakePlayer = function()
			return maid:Add(Instance.new("Folder"))
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("TeleportDataService.BuildTeleportData", function()
	it("should return an empty table with no providers and no base data", function()
		local controller = setup()

		expect(controller.service:BuildTeleportData({})).toEqual({})

		controller:destroy()
	end)

	it("should copy base data through when there are no providers", function()
		local controller = setup()

		expect(controller.service:BuildTeleportData({}, { a = 1, b = "two" })).toEqual({ a = 1, b = "two" })

		controller:destroy()
	end)

	it("should merge a single provider's contribution", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return { slot = "abc" }
		end)

		expect(controller.service:BuildTeleportData({})).toEqual({ slot = "abc" })

		controller:destroy()
	end)

	it("should merge multiple providers together", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)
		controller.service:RegisterTeleportDataProvider(function()
			return { b = 2 }
		end)

		expect(controller.service:BuildTeleportData({})).toEqual({ a = 1, b = 2 })

		controller:destroy()
	end)

	it("should let base data win over provider keys", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return { shared = "provider" }
		end)

		expect(controller.service:BuildTeleportData({}, { shared = "caller" })).toEqual({ shared = "caller" })

		controller:destroy()
	end)

	it("should ignore a provider that returns nil", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return nil
		end)
		controller.service:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)

		expect(controller.service:BuildTeleportData({})).toEqual({ a = 1 })

		controller:destroy()
	end)

	it("should pass the players list to providers", function()
		local controller = setup()

		local players = { controller.fakePlayer() }
		local received
		controller.service:RegisterTeleportDataProvider(function(givenPlayers)
			received = givenPlayers
			return nil
		end)

		controller.service:BuildTeleportData(players)
		expect(received).toBe(players)

		controller:destroy()
	end)

	it("should stop merging a provider after it is unregistered", function()
		local controller = setup()

		local unregister = controller.service:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)
		expect(controller.service:BuildTeleportData({})).toEqual({ a = 1 })

		unregister()
		expect(controller.service:BuildTeleportData({})).toEqual({})

		controller:destroy()
	end)
end)

describe("TeleportDataService arrived data", function()
	it("should read an injected arrived value", function()
		local controller = setup()
		local player = controller.fakePlayer()

		controller.service:SetArrivedTeleportDataForTesting(player, { key = "value" })

		expect(controller.service:GetArrivedTeleportData(player)).toEqual({ key = "value" })
		expect(controller.service:GetArrivedValue(player, "key")).toEqual("value")
		expect(controller.service:HasArrivedValue(player, "key")).toEqual(true)

		controller:destroy()
	end)

	it("should report a missing key as absent", function()
		local controller = setup()
		local player = controller.fakePlayer()

		controller.service:SetArrivedTeleportDataForTesting(player, { key = "value" })

		expect(controller.service:GetArrivedValue(player, "other")).toBeNil()
		expect(controller.service:HasArrivedValue(player, "other")).toEqual(false)

		controller:destroy()
	end)

	it("should clear an injected override back to nil", function()
		local controller = setup()
		local player = controller.fakePlayer()

		controller.service:SetArrivedTeleportDataForTesting(player, { key = "value" })
		controller.service:SetArrivedTeleportDataForTesting(player, nil)

		expect(controller.service:HasArrivedValue(player, "key")).toEqual(false)

		controller:destroy()
	end)

	it("should reject injecting an override after the data has been read", function()
		local controller = setup()
		local player = controller.fakePlayer()

		controller.service:SetArrivedTeleportDataForTesting(player, { key = "value" })
		controller.service:GetArrivedTeleportData(player) -- consumes it

		expect(function()
			controller.service:SetArrivedTeleportDataForTesting(player, { key = "other" })
		end).toThrow("after it has been read")

		controller:destroy()
	end)
end)
