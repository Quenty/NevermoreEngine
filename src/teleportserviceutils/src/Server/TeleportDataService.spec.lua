--!strict
--[[
	Coverage for TeleportDataService's per-player data assembly and arrived-data surface -- the parts
	reachable on a headless cloud test server (which has no joined players, so both the UserId keying
	and arrived data are exercised through test seams rather than a real teleport).

	@class TeleportDataService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")
local TeleportDataService = require("TeleportDataService")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Controller pattern (see docs/testing/testing.md): the maid owns the ServiceBag and every fake
-- player folder, so a batch run leaves nothing running in a later package's window.
local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local service = (serviceBag:GetService(TeleportDataService) :: any) :: TeleportDataService.TeleportDataService
	serviceBag:Init()

	-- Fake players (Folders) have no real UserId, so key envelope slices off an attribute instead.
	local anyService = service :: any
	anyService._getUserId = function(_self, player: Instance): any
		return player:GetAttribute("UserId")
	end

	return {
		service = service,
		-- A Folder is an Instance, so it satisfies the `typeof(player) == "Instance"` guards and can
		-- stand in for a Player as long as arrived data is injected (never hitting GetJoinData).
		fakePlayer = function(userId: number?): Player
			local player = maid:Add(Instance.new("Folder"))
			if userId ~= nil then
				player:SetAttribute("UserId", userId)
			end
			return (player :: any) :: Player
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

-- Reads the slice a player would arrive with from freshly built teleport data, exercising the same
-- envelope shape a real teleport round-trips.
local function sliceFor(built: { [string]: any }, userId: number): TeleportDataEnvelopeUtils.TeleportDataSlice?
	return TeleportDataEnvelopeUtils.readSlice(built, userId)
end

describe("TeleportDataService.BuildTeleportData shared data", function()
	it("should carry nothing with no providers and no base data", function()
		local controller = setup()

		expect(controller.service:BuildTeleportData({})).toEqual({})

		controller:destroy()
	end)

	it("should deliver base data to any player", function()
		local controller = setup()

		local built = controller.service:BuildTeleportData({}, { a = 1, b = "two" })
		expect(sliceFor(built, 111)).toEqual({ a = 1, b = "two" })

		controller:destroy()
	end)

	it("should merge shared providers together", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)
		controller.service:RegisterTeleportDataProvider(function()
			return { b = 2 }
		end)

		expect(sliceFor(controller.service:BuildTeleportData({}), 111)).toEqual({ a = 1, b = 2 })

		controller:destroy()
	end)

	it("should let base data win over a shared provider key", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return { shared = "provider" }
		end)

		local built = controller.service:BuildTeleportData({}, { shared = "caller" })
		expect(sliceFor(built, 111)).toEqual({ shared = "caller" })

		controller:destroy()
	end)

	it("should ignore a shared provider that returns nil", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return nil
		end)
		controller.service:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)

		expect(sliceFor(controller.service:BuildTeleportData({}), 111)).toEqual({ a = 1 })

		controller:destroy()
	end)

	it("should stop merging a shared provider after it is unregistered", function()
		local controller = setup()

		local unregister = controller.service:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)
		expect(sliceFor(controller.service:BuildTeleportData({}), 111)).toEqual({ a = 1 })

		unregister()
		expect(controller.service:BuildTeleportData({})).toEqual({})

		controller:destroy()
	end)
end)

describe("TeleportDataService.BuildTeleportData per-player data", function()
	it("should carry a single player's own slice", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:RegisterPerPlayerTeleportDataProvider(function(givenPlayer)
			return { slot = "slot-" .. tostring(givenPlayer:GetAttribute("UserId")) }
		end)

		local built = controller.service:BuildTeleportData({ player })
		expect(sliceFor(built, 111)).toEqual({ slot = "slot-111" })
		-- Another player is not carried, and reads nothing from this player's teleport.
		expect(sliceFor(built, 222)).toBeNil()

		controller:destroy()
	end)

	it("should give each player of a group teleport only their own slice", function()
		local controller = setup()
		local playerA = controller.fakePlayer(111)
		local playerB = controller.fakePlayer(222)

		controller.service:RegisterPerPlayerTeleportDataProvider(function(givenPlayer)
			return { userId = givenPlayer:GetAttribute("UserId") }
		end)

		local built = controller.service:BuildTeleportData({ playerA, playerB })
		expect(sliceFor(built, 111)).toEqual({ userId = 111 })
		expect(sliceFor(built, 222)).toEqual({ userId = 222 })

		controller:destroy()
	end)

	it("should merge the shared slice under each player's slice", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:RegisterTeleportDataProvider(function()
			return { mode = "hard" }
		end)
		controller.service:RegisterPerPlayerTeleportDataProvider(function()
			return { slot = "a" }
		end)

		expect(sliceFor(controller.service:BuildTeleportData({ player }), 111)).toEqual({
			mode = "hard",
			slot = "a",
		})

		controller:destroy()
	end)

	it("should let a per-player key win over shared and base data (most specific)", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:RegisterTeleportDataProvider(function()
			return { v = "shared" }
		end)
		controller.service:RegisterPerPlayerTeleportDataProvider(function()
			return { v = "player" }
		end)

		local built = controller.service:BuildTeleportData({ player }, { v = "base" })
		expect(sliceFor(built, 111)).toEqual({ v = "player" })

		controller:destroy()
	end)

	it("should not create a slice for a player whose providers contribute nothing", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		controller.service:RegisterPerPlayerTeleportDataProvider(function()
			return nil
		end)

		expect(controller.service:BuildTeleportData({ player })).toEqual({})

		controller:destroy()
	end)

	it("should call the provider once per player with the full player list", function()
		local controller = setup()
		local players = { controller.fakePlayer(111), controller.fakePlayer(222) }
		local seen = {}
		local receivedList
		controller.service:RegisterPerPlayerTeleportDataProvider(function(player, givenPlayers)
			table.insert(seen, player)
			receivedList = givenPlayers
			return nil
		end)

		controller.service:BuildTeleportData(players)
		expect(seen[1]).toBe(players[1])
		expect(seen[2]).toBe(players[2])
		expect(receivedList).toBe(players)

		controller:destroy()
	end)
end)

describe("TeleportDataService.BuildTeleportData size guard", function()
	it("should throw when the built data exceeds the size cap", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			return { blob = string.rep("x", TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES + 1024) }
		end)

		expect(function()
			controller.service:BuildTeleportData({})
		end).toThrow()

		controller:destroy()
	end)

	it("should throw when a provider returns un-encodable teleport data", function()
		local controller = setup()

		controller.service:RegisterTeleportDataProvider(function()
			local cyclic = {}
			cyclic.self = cyclic
			return cyclic
		end)

		expect(function()
			controller.service:BuildTeleportData({})
		end).toThrow()

		controller:destroy()
	end)
end)

describe("TeleportDataService arrived data", function()
	it("should read an injected legacy (flat) arrived value", function()
		local controller = setup()
		local player = controller.fakePlayer()

		controller.service:SetArrivedTeleportDataForTesting(player, { key = "value" })

		expect(controller.service:GetArrivedTeleportData(player)).toEqual({ key = "value" })
		expect(controller.service:GetArrivedValue(player, "key")).toEqual("value")
		expect(controller.service:HasArrivedValue(player, "key")).toEqual(true)

		controller:destroy()
	end)

	it("should unwrap each arriving player's own slice from a shared envelope", function()
		local controller = setup()
		local playerA = controller.fakePlayer(111)
		local playerB = controller.fakePlayer(222)

		controller.service:RegisterPerPlayerTeleportDataProvider(function(player)
			return { userId = player:GetAttribute("UserId") }
		end)

		-- Both players arrive carrying the same envelope (as they would from one group teleport).
		local envelope = controller.service:BuildTeleportData({ playerA, playerB })
		controller.service:SetArrivedTeleportDataForTesting(playerA, envelope)
		controller.service:SetArrivedTeleportDataForTesting(playerB, envelope)

		expect(controller.service:GetArrivedValue(playerA, "userId")).toEqual(111)
		expect(controller.service:GetArrivedValue(playerB, "userId")).toEqual(222)

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
