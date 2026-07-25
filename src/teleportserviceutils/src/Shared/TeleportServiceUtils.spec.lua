--!strict
--[[
	@class TeleportServiceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
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

-- The hop the mock recorded for this destination, or nil if none has been made since the last clear.
local function readHop(player: Player, placeId: number): any
	return PlayerMock.readLookup(player, "TeleportService.Teleport", placeId)
end

-- Forgets the recorded hop, so the next one is observable as a fresh record rather than an
-- indistinguishable overwrite -- how a test sees that a retry actually teleported again.
local function clearHop(player: Player, placeId: number): ()
	PlayerMock.writeLookup(player, "TeleportService.Teleport", placeId, nil)
end

-- Stands in for TeleportService refusing the hop. The message must differ from the previous refusal
-- of the same teleport: the backing attribute only reports a change (see the domain's note in
-- PlayerMock), and a repeat would go unnoticed rather than counting as a second refusal.
local function refuse(player: Player, placeId: number, message: string): ()
	PlayerMock.writeLookup(player, "TeleportService.TeleportInitFailed", placeId, { message = message })
end

local function awaitHop(player: Player, placeId: number): any
	PromiseTestUtils.awaitValue(function()
		return readHop(player, placeId) ~= nil
	end)
	return readHop(player, placeId)
end

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

describe("TeleportServiceUtils.promiseTeleportClient", function()
	it("teleports on the spot, carrying the config's teleport data", function()
		local player = newMock(885001)

		TeleportServiceUtils.promiseTeleportClient(800, player, { teleportData = { SlotId = "abc" } })

		local hop = readHop(player, 800)
		expect(hop.via).toEqual("Teleport")
		expect(hop.teleportData.SlotId).toEqual("abc")
	end)

	it("teleports with no data at all when no config is given", function()
		local player = newMock(885002)

		TeleportServiceUtils.promiseTeleportClient(801, player)

		expect(readHop(player, 801).via).toEqual("Teleport")
	end)

	it("stays pending, because a teleport that works ends with the player gone", function()
		local player = newMock(885003)

		local promise = TeleportServiceUtils.promiseTeleportClient(802, player)

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
	end)

	it("teleports again after the engine refuses, carrying the same data", function()
		local player = newMock(885004)

		local promise = TeleportServiceUtils.promiseTeleportClient(803, player, {
			teleportData = { SlotId = "retry-me" },
			retryWait = 0,
		})

		clearHop(player, 803)
		refuse(player, 803, "server full")

		expect(awaitHop(player, 803).teleportData.SlotId).toEqual("retry-me")
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
	end)

	it("keeps retrying until the attempts are spent, then rejects naming the last refusal", function()
		local player = newMock(885005)

		local promise = TeleportServiceUtils.promiseTeleportClient(804, player, { maxAttempts = 3, retryWait = 0 })

		-- Two refusals are absorbed by retries; the third finds no attempts left.
		refuse(player, 804, "refusal 1")
		clearHop(player, 804)
		awaitHop(player, 804)
		refuse(player, 804, "refusal 2")
		clearHop(player, 804)
		awaitHop(player, 804)
		refuse(player, 804, "refusal 3")

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(err).toContain("refusal 3")
		expect(err).toContain("3 attempt(s)")
		expect(err).toContain("804")
	end)

	it("gives up on the first refusal when the config allows a single attempt", function()
		local player = newMock(885006)

		local promise = TeleportServiceUtils.promiseTeleportClient(805, player, { maxAttempts = 1, retryWait = 0 })

		clearHop(player, 805)
		refuse(player, 805, "nope")

		local outcome = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(readHop(player, 805)).toEqual(nil) -- no retry was ever attempted
	end)

	it("waits the configured backoff before trying again", function()
		local player = newMock(885007)

		local promise = TeleportServiceUtils.promiseTeleportClient(806, player, { retryWait = 0.5 })

		clearHop(player, 806)
		refuse(player, 806, "not yet")

		task.wait(0.1)
		expect(readHop(player, 806)).toEqual(nil) -- still inside the backoff

		expect(awaitHop(player, 806).via).toEqual("Teleport")

		promise:Destroy()
	end)

	it("ignores a refusal aimed at another player's teleport", function()
		local player = newMock(885008)
		local other = newMock(885009)

		local promise = TeleportServiceUtils.promiseTeleportClient(807, player, { maxAttempts = 1, retryWait = 0 })

		clearHop(player, 807)
		refuse(other, 807, "someone else's problem")

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)
		expect(readHop(player, 807)).toEqual(nil)

		promise:Destroy()
	end)

	it("ignores a refusal of a hop to a different place", function()
		local player = newMock(885010)

		local promise = TeleportServiceUtils.promiseTeleportClient(808, player, { maxAttempts = 1, retryWait = 0 })

		refuse(player, 999, "a different destination")

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)

		promise:Destroy()
	end)

	it("rejects with nothing when cancelled, so a caller can tell teardown from a failure", function()
		local player = newMock(885011)

		local outcome, err = "pending", nil :: any
		local promise = TeleportServiceUtils.promiseTeleportClient(809, player)
		promise:Then(function()
			outcome = "resolved"
		end, function(...)
			outcome, err = "rejected", ...
		end)

		promise:Destroy()

		expect(outcome).toEqual("rejected")
		expect(err).toEqual(nil)
	end)

	it("stops retrying once cancelled, including a backoff already counting down", function()
		local player = newMock(885012)

		local promise = TeleportServiceUtils.promiseTeleportClient(810, player, { retryWait = 0.1 })

		refuse(player, 810, "will retry")
		promise:Destroy()
		clearHop(player, 810)

		-- Well past the backoff: the retry the refusal scheduled must not teleport a player whose
		-- teleport was cancelled out from under it.
		task.wait(0.3)
		expect(readHop(player, 810)).toEqual(nil)
	end)

	it("ignores a refusal that lands after it has already given up", function()
		local player = newMock(885013)

		local promise = TeleportServiceUtils.promiseTeleportClient(811, player, { maxAttempts = 1, retryWait = 0 })

		refuse(player, 811, "first")
		local outcome = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")

		clearHop(player, 811)
		refuse(player, 811, "second")

		task.wait(0.1)
		expect(readHop(player, 811)).toEqual(nil)
	end)

	it("errors on a bad placeId, player, or config", function()
		local player = newMock(885014)

		expect(function()
			TeleportServiceUtils.promiseTeleportClient("nope" :: any, player)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, nil :: any)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, "nope" :: any)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, { maxAttempts = 0 })
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, { retryWait = -1 })
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, { teleportData = "nope" :: any })
		end).toThrow()
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
