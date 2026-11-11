--!strict
--[[
	@class TeleportDataBuilder.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local TeleportDataBuilder = require("TeleportDataBuilder")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function fakePlayer(userId: number): Player
	return ({ UserId = userId } :: any) :: Player
end

local function newBuilder(): TeleportDataBuilder.TeleportDataBuilder
	return TeleportDataBuilder.new(function(player: Player): number
		return (player :: any).UserId
	end)
end

local function sliceFor(built: { [string]: any }, userId: number): TeleportDataEnvelopeUtils.TeleportDataSlice?
	return TeleportDataEnvelopeUtils.readSlice(built, userId)
end

-- Builds and awaits the (async-only) envelope. `:Wait()` returns the built table and rethrows a
-- rejection, so the size-guard `toThrow` assertions keep working through it.
local function buildAsync(builder: any, players: { Player }, baseData: { [string]: any }?): any
	local promise = builder:PromiseBuildTeleportData(players, baseData)
	assert(PromiseTestUtils.awaitSettled(promise, 10), "PromiseBuildTeleportData hung")
	return promise:Wait()
end

describe("TeleportDataBuilder.new", function()
	it("defaults the UserId resolver to player.UserId", function()
		local builder = TeleportDataBuilder.new()
		builder:RegisterPerPlayerTeleportDataProvider(function()
			return { slot = "a" }
		end)

		local built = buildAsync(builder, { fakePlayer(111) })
		expect(sliceFor(built, 111)).toEqual({ slot = "a" })
	end)
end)

describe("TeleportDataBuilder shared data", function()
	it("carries nothing with no providers and no base data", function()
		expect(buildAsync(newBuilder(), {})).toEqual({})
	end)

	it("delivers base data to any player", function()
		local built = buildAsync(newBuilder(), {}, { a = 1, b = "two" })
		expect(sliceFor(built, 111)).toEqual({ a = 1, b = "two" })
	end)

	it("merges shared providers together", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)
		builder:RegisterTeleportDataProvider(function()
			return { b = 2 }
		end)

		expect(sliceFor(buildAsync(builder, {}), 111)).toEqual({ a = 1, b = 2 })
	end)

	it("lets base data win over a shared provider key", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			return { shared = "provider" }
		end)

		expect(sliceFor(buildAsync(builder, {}, { shared = "caller" }), 111)).toEqual({ shared = "caller" })
	end)

	it("ignores a shared provider that returns nil", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			return nil
		end)
		builder:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)

		expect(sliceFor(buildAsync(builder, {}), 111)).toEqual({ a = 1 })
	end)

	it("stops merging a shared provider after it is unregistered", function()
		local builder = newBuilder()
		local unregister = builder:RegisterTeleportDataProvider(function()
			return { a = 1 }
		end)
		expect(sliceFor(buildAsync(builder, {}), 111)).toEqual({ a = 1 })

		unregister()
		expect(buildAsync(builder, {})).toEqual({})
	end)
end)

describe("TeleportDataBuilder per-player data", function()
	it("carries a single player's own slice", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(function(player)
			return { slot = "slot-" .. tostring((player :: any).UserId) }
		end)

		local built = buildAsync(builder, { fakePlayer(111) })
		expect(sliceFor(built, 111)).toEqual({ slot = "slot-111" })
		expect(sliceFor(built, 222)).toBeNil()
	end)

	it("gives each player of a group teleport only their own slice", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(function(player)
			return { userId = (player :: any).UserId }
		end)

		local built = buildAsync(builder, { fakePlayer(111), fakePlayer(222) })
		expect(sliceFor(built, 111)).toEqual({ userId = 111 })
		expect(sliceFor(built, 222)).toEqual({ userId = 222 })
	end)

	it("merges the shared slice under each player's slice", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			return { mode = "hard" }
		end)
		builder:RegisterPerPlayerTeleportDataProvider(function()
			return { slot = "a" }
		end)

		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }), 111)).toEqual({ mode = "hard", slot = "a" })
	end)

	it("lets a per-player key win over shared and base data (most specific)", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			return { v = "shared" }
		end)
		builder:RegisterPerPlayerTeleportDataProvider(function()
			return { v = "player" }
		end)

		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }, { v = "base" }), 111)).toEqual({ v = "player" })
	end)

	it("does not create a slice for a player whose providers contribute nothing", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(function()
			return nil
		end)

		expect(buildAsync(builder, { fakePlayer(111) })).toEqual({})
	end)

	it("calls the provider once per player with the full player list", function()
		local builder = newBuilder()
		local players = { fakePlayer(111), fakePlayer(222) }
		local seen = {}
		local receivedList
		builder:RegisterPerPlayerTeleportDataProvider(function(player, givenPlayers)
			table.insert(seen, player)
			receivedList = givenPlayers
			return nil
		end)

		buildAsync(builder, players)
		expect(seen[1]).toBe(players[1])
		expect(seen[2]).toBe(players[2])
		expect(receivedList).toBe(players)
	end)

	it("stops calling a per-player provider after it is unregistered", function()
		local builder = newBuilder()
		local unregister = builder:RegisterPerPlayerTeleportDataProvider(function()
			return { slot = "a" }
		end)
		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }), 111)).toEqual({ slot = "a" })

		unregister()
		expect(buildAsync(builder, { fakePlayer(111) })).toEqual({})
	end)
end)

describe("TeleportDataBuilder size guard", function()
	it("throws when the built data exceeds the size cap", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			return { blob = string.rep("x", TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES + 1024) }
		end)

		expect(function()
			buildAsync(builder, {})
		end).toThrow()
	end)

	it("throws when a provider returns un-encodable teleport data", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			local cyclic = {}
			cyclic.self = cyclic
			return cyclic
		end)

		expect(function()
			buildAsync(builder, {})
		end).toThrow()
	end)
end)

describe("TeleportDataBuilder.PromiseBuildTeleportData", function()
	local function asyncProvider(value: any)
		return function()
			return Promise.resolved():Then(function()
				return value
			end)
		end
	end

	it("carries a synchronous provider slice", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(function()
			return { mode = "hard" }
		end)
		builder:RegisterPerPlayerTeleportDataProvider(function(player)
			return { slot = "slot-" .. tostring((player :: any).UserId) }
		end)

		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }), 111)).toEqual({ mode = "hard", slot = "slot-111" })
	end)

	it("awaits an async per-player provider", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(asyncProvider({ slot = "async" }))

		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }), 111)).toEqual({ slot = "async" })
	end)

	it("awaits an async shared provider", function()
		local builder = newBuilder()
		builder:RegisterTeleportDataProvider(asyncProvider({ a = 1 }))

		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }), 111)).toEqual({ a = 1 })
	end)

	it("mixes sync and async providers under one player", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(function()
			return { sync = 1 }
		end)
		builder:RegisterPerPlayerTeleportDataProvider(asyncProvider({ async = 2 }))

		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }), 111)).toEqual({ sync = 1, async = 2 })
	end)

	it("ignores an async provider that resolves nil", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(asyncProvider(nil))
		builder:RegisterPerPlayerTeleportDataProvider(function()
			return { a = 1 }
		end)

		expect(sliceFor(buildAsync(builder, { fakePlayer(111) }), 111)).toEqual({ a = 1 })
	end)

	it("gives each player of a group teleport their own async slice", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(function(player)
			return Promise.resolved():Then(function()
				return { userId = (player :: any).UserId }
			end)
		end)

		local built = buildAsync(builder, { fakePlayer(111), fakePlayer(222) })
		expect(sliceFor(built, 111)).toEqual({ userId = 111 })
		expect(sliceFor(built, 222)).toEqual({ userId = 222 })
	end)

	it("rejects the build when an async provider rejects", function()
		local builder = newBuilder()
		builder:RegisterPerPlayerTeleportDataProvider(function()
			return Promise.rejected("boom")
		end)

		local promise = builder:PromiseBuildTeleportData({ fakePlayer(111) })
		assert(PromiseTestUtils.awaitSettled(promise, 10), "PromiseBuildTeleportData hung")
		expect((promise:Yield())).toEqual(false)
	end)
end)
