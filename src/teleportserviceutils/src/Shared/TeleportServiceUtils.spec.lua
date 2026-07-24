--!strict
--[[
	@class TeleportServiceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")
local TeleportServiceUtils = require("TeleportServiceUtils")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local mocks: { Player } = {}

local function newMock(userId: number): Player
	local player = PlayerMock.new({ UserId = userId })
	table.insert(mocks, player)
	return player
end

afterEach(function()
	for _, player in mocks do
		player:Destroy()
	end
	table.clear(mocks)
end)

describe("TeleportServiceUtils.teleport", function()
	it("records the teleport with via=Teleport and its data on a mock", function()
		local player = newMock(880001)
		TeleportServiceUtils.teleport(4567, player, { SlotId = "abc", Flag = true })

		local hop = PlayerMock.readLookup(player, "TeleportService.Teleport", 4567)
		expect(hop.via).toEqual("Teleport")
		expect(hop.teleportData.SlotId).toEqual("abc")
		expect(hop.teleportData.Flag).toEqual(true)
	end)

	it("records an empty data table when none is passed, so a read still reports the hop", function()
		local player = newMock(880002)
		TeleportServiceUtils.teleport(9999, player, nil)

		local hop = PlayerMock.readLookup(player, "TeleportService.Teleport", 9999)
		expect(hop).never.toEqual(nil)
		expect(hop.via).toEqual("Teleport")
	end)

	it("does not record a hop to a place that was never teleported to", function()
		local player = newMock(880003)
		TeleportServiceUtils.teleport(1111, player, {})

		expect(PlayerMock.readLookup(player, "TeleportService.Teleport", 2222)).toEqual(nil)
	end)

	it("overwrites a prior hop to the same place with the latest data", function()
		local player = newMock(880004)
		TeleportServiceUtils.teleport(333, player, { SlotId = "first" })
		TeleportServiceUtils.teleport(333, player, { SlotId = "second" })

		expect(PlayerMock.readLookup(player, "TeleportService.Teleport", 333).teleportData.SlotId).toEqual("second")
	end)

	it("errors on a non-number placeId", function()
		local player = newMock(880005)
		expect(function()
			TeleportServiceUtils.teleport("nope" :: any, player, {})
		end).toThrow()
	end)

	it("errors when given no player", function()
		expect(function()
			TeleportServiceUtils.teleport(123, nil :: any, {})
		end).toThrow()
	end)
end)

describe("TeleportServiceUtils.teleportToPlaceInstance", function()
	it("records via, instanceId, spawnName and data on a mock", function()
		local player = newMock(881001)
		TeleportServiceUtils.teleportToPlaceInstance(500, "job-9", player, "SpawnA", { SlotId = "x" })

		local hop = PlayerMock.readLookup(player, "TeleportService.Teleport", 500)
		expect(hop.via).toEqual("TeleportToPlaceInstance")
		expect(hop.instanceId).toEqual("job-9")
		expect(hop.spawnName).toEqual("SpawnA")
		expect(hop.teleportData.SlotId).toEqual("x")
	end)

	it("errors on a non-string instanceId", function()
		local player = newMock(881002)
		expect(function()
			TeleportServiceUtils.teleportToPlaceInstance(500, 123 :: any, player)
		end).toThrow()
	end)
end)

describe("TeleportServiceUtils.teleportAsync", function()
	it("records each mock in the batch with the options' teleport data, skipping the engine", function()
		local a = newMock(882001)
		local b = newMock(882002)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ SlotId = "shared" })

		local result = TeleportServiceUtils.teleportAsync(600, { a, b }, options)

		expect(result).toEqual(nil) -- an all-mock batch skips the engine
		expect(PlayerMock.readLookup(a, "TeleportService.Teleport", 600).via).toEqual("TeleportAsync")
		expect(PlayerMock.readLookup(a, "TeleportService.Teleport", 600).teleportData.SlotId).toEqual("shared")
		expect(PlayerMock.readLookup(b, "TeleportService.Teleport", 600).teleportData.SlotId).toEqual("shared")
	end)

	it("records a mock even when no options are passed", function()
		local player = newMock(882003)
		TeleportServiceUtils.teleportAsync(601, { player }, nil)

		expect(PlayerMock.readLookup(player, "TeleportService.Teleport", 601).via).toEqual("TeleportAsync")
	end)

	it("errors on non-table players", function()
		expect(function()
			TeleportServiceUtils.teleportAsync(600, "nope" :: any, nil)
		end).toThrow()
	end)

	it("errors on options that are not a TeleportOptions", function()
		local player = newMock(882004)
		expect(function()
			TeleportServiceUtils.teleportAsync(600, { player }, Instance.new("Folder") :: any)
		end).toThrow()
	end)
end)

describe("TeleportServiceUtils.promiseTeleport", function()
	it("is mock-aware: records mocks and resolves nil for an all-mock batch", function()
		local player = newMock(883001)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ SlotId = "z" })

		local result = TeleportServiceUtils.promiseTeleport(700, { player }, options):Wait()

		expect(result).toEqual(nil)
		local hop = PlayerMock.readLookup(player, "TeleportService.Teleport", 700)
		expect(hop.via).toEqual("TeleportAsync")
		expect(hop.teleportData.SlotId).toEqual("z")
	end)
end)

-- A real server consumer never passes a flat table -- it passes a TeleportDataEnvelopeUtils envelope
-- (shared slice + per-player slices keyed by stringified UserId). The mock records whatever
-- GetTeleportData returns, which the record then JSON round-trips -- exactly as a real teleport
-- serializes its data -- so these assert the envelope survives that trip and the standard reader still
-- recovers each arriving player's slice. The fragile part is the per-player map's numeric-string keys.
describe("TeleportServiceUtils teleport data (consumer envelope round-trip)", function()
	it("recovers the arriving player's merged slice from a recorded envelope", function()
		local userId = 884001
		local player = newMock(userId)

		local envelope = TeleportDataEnvelopeUtils.build(
			{ WorldIndex = 3, Reason = "journey" },
			{ [tostring(userId)] = { SlotId = "abc-123", Ephemeral = true, Trace = { Origin = "hub", Depth = 2 } } }
		)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(envelope)

		TeleportServiceUtils.teleportAsync(4242, { player }, options)

		local recorded = PlayerMock.readLookup(player, "TeleportService.Teleport", 4242)
		expect(TeleportDataEnvelopeUtils.readSlice(recorded.teleportData, userId)).toEqual({
			WorldIndex = 3,
			Reason = "journey",
			SlotId = "abc-123",
			Ephemeral = true,
			Trace = { Origin = "hub", Depth = 2 },
		})
	end)

	it("keeps per-player slices distinct after the record's JSON round-trip", function()
		local a = newMock(884101)
		local b = newMock(884102)

		local envelope = TeleportDataEnvelopeUtils.build(nil, {
			["884101"] = { SlotId = "for-a" },
			["884102"] = { SlotId = "for-b" },
		})
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(envelope)

		TeleportServiceUtils.teleportAsync(4243, { a, b }, options)

		local dataA = PlayerMock.readLookup(a, "TeleportService.Teleport", 4243).teleportData
		local dataB = PlayerMock.readLookup(b, "TeleportService.Teleport", 4243).teleportData
		expect(TeleportDataEnvelopeUtils.readSlice(dataA, 884101)).toEqual({ SlotId = "for-a" })
		expect(TeleportDataEnvelopeUtils.readSlice(dataB, 884102)).toEqual({ SlotId = "for-b" })
	end)
end)
