--!strict
--[[
	Pure coverage for the per-player teleport-data envelope and the size guard. Keyed by plain
	numbers, so no Player is needed (a headless cloud test server has none).

	@class TeleportDataEnvelopeUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("TeleportDataEnvelopeUtils.build / readSlice round-trip", function()
	it("omits empty sections, producing an empty envelope for no data", function()
		expect(TeleportDataEnvelopeUtils.build(nil, nil)).toEqual({})
		expect(TeleportDataEnvelopeUtils.build({}, {})).toEqual({})
	end)

	it("delivers a shared slice to any player", function()
		local envelope = TeleportDataEnvelopeUtils.build({ mode = "hard" }, nil)

		expect(TeleportDataEnvelopeUtils.readSlice(envelope, 111)).toEqual({ mode = "hard" })
		expect(TeleportDataEnvelopeUtils.readSlice(envelope, 222)).toEqual({ mode = "hard" })
	end)

	it("delivers each player only their own slice", function()
		local envelope = TeleportDataEnvelopeUtils.build(nil, {
			["111"] = { slot = "a" },
			["222"] = { slot = "b" },
		})

		expect(TeleportDataEnvelopeUtils.readSlice(envelope, 111)).toEqual({ slot = "a" })
		expect(TeleportDataEnvelopeUtils.readSlice(envelope, 222)).toEqual({ slot = "b" })
	end)

	it("merges the shared slice under the player's slice, per-player winning on conflict", function()
		local envelope = TeleportDataEnvelopeUtils.build({ x = "shared", keep = 1 }, {
			["111"] = { x = "player" },
		})

		expect(TeleportDataEnvelopeUtils.readSlice(envelope, 111)).toEqual({ x = "player", keep = 1 })
	end)

	it("looks a player's slice up by stringified UserId", function()
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "a" } })

		expect(TeleportDataEnvelopeUtils.readSlice(envelope, 111)).toEqual({ slot = "a" })
		expect(TeleportDataEnvelopeUtils.readSlice(envelope, "111")).toEqual({ slot = "a" })
	end)

	it("returns nil when the player carried no slice and there is no shared data", function()
		local envelope = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "a" } })

		expect(TeleportDataEnvelopeUtils.readSlice(envelope, 999)).toBeNil()
	end)
end)

describe("TeleportDataEnvelopeUtils.readMergedSlice", function()
	it("returns nil when neither band carried anything", function()
		expect(TeleportDataEnvelopeUtils.readMergedSlice(nil, nil, 111)).toBeNil()
		expect(TeleportDataEnvelopeUtils.readMergedSlice({}, {}, 111)).toBeNil()
	end)

	it("returns the trusted band alone when there is no non-trusted band", function()
		local trusted = TeleportDataEnvelopeUtils.build({ mode = "hard" }, nil)

		expect(TeleportDataEnvelopeUtils.readMergedSlice(trusted, nil, 111)).toEqual({ mode = "hard" })
	end)

	it("returns the non-trusted band alone when there is no trusted band", function()
		local nonTrusted = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "a" } })

		expect(TeleportDataEnvelopeUtils.readMergedSlice(nil, nonTrusted, 111)).toEqual({ slot = "a" })
	end)

	it("unions disjoint keys from both bands", function()
		local trusted = TeleportDataEnvelopeUtils.build({ region = "us" }, nil)
		local nonTrusted = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "a" } })

		expect(TeleportDataEnvelopeUtils.readMergedSlice(trusted, nonTrusted, 111)).toEqual({
			region = "us",
			slot = "a",
		})
	end)

	it("lets the trusted band win on a key conflict (client can never override the server)", function()
		local trusted = TeleportDataEnvelopeUtils.build({ slot = "server-slot" }, nil)
		local nonTrusted = TeleportDataEnvelopeUtils.build(nil, { ["111"] = { slot = "client-slot" } })

		expect(TeleportDataEnvelopeUtils.readMergedSlice(trusted, nonTrusted, 111)).toEqual({
			slot = "server-slot",
		})
	end)

	it("merges only each player's own non-trusted slice by UserId", function()
		local nonTrusted = TeleportDataEnvelopeUtils.build(nil, {
			["111"] = { slot = "mine" },
			["222"] = { slot = "theirs" },
		})

		expect(TeleportDataEnvelopeUtils.readMergedSlice(nil, nonTrusted, 111)).toEqual({ slot = "mine" })
		expect(TeleportDataEnvelopeUtils.readMergedSlice(nil, nonTrusted, 222)).toEqual({ slot = "theirs" })
	end)

	it("merges legacy flat bands as-is", function()
		expect(TeleportDataEnvelopeUtils.readMergedSlice({ a = 1 }, { a = 2, b = 3 }, 111)).toEqual({
			a = 1,
			b = 3,
		})
	end)
end)

describe("TeleportDataEnvelopeUtils.isEnvelope", function()
	it("recognizes an envelope by its reserved sections", function()
		expect(TeleportDataEnvelopeUtils.isEnvelope(TeleportDataEnvelopeUtils.build({ a = 1 }, nil))).toBe(true)
		expect(TeleportDataEnvelopeUtils.isEnvelope(TeleportDataEnvelopeUtils.build(nil, { ["1"] = { a = 1 } }))).toBe(
			true
		)
	end)

	it("treats a flat table and non-tables as not an envelope", function()
		expect(TeleportDataEnvelopeUtils.isEnvelope({ slot = "a" })).toBe(false)
		expect(TeleportDataEnvelopeUtils.isEnvelope({})).toBe(false)
		expect(TeleportDataEnvelopeUtils.isEnvelope(nil)).toBe(false)
		expect(TeleportDataEnvelopeUtils.isEnvelope("nope")).toBe(false)
	end)
end)

describe("TeleportDataEnvelopeUtils.readSlice legacy compatibility", function()
	it("returns a flat (non-envelope) table as the player's slice", function()
		expect(TeleportDataEnvelopeUtils.readSlice({ IncomingSaveSlotId = "slot-1" }, 111)).toEqual({
			IncomingSaveSlotId = "slot-1",
		})
	end)

	it("returns nil for non-table arrived data", function()
		expect(TeleportDataEnvelopeUtils.readSlice(nil, 111)).toBeNil()
		expect(TeleportDataEnvelopeUtils.readSlice("nope", 111)).toBeNil()
	end)
end)

describe("TeleportDataEnvelopeUtils.measureBytes", function()
	it("grows with the size of the data", function()
		local small = TeleportDataEnvelopeUtils.measureBytes({ a = 1 })
		local large = TeleportDataEnvelopeUtils.measureBytes({ a = string.rep("x", 1000) })

		expect(small).toBeGreaterThan(0)
		expect(large).toBeGreaterThan(small)
	end)

	it("throws on data that cannot be encoded", function()
		local cyclic = {}
		cyclic.self = cyclic

		expect(function()
			TeleportDataEnvelopeUtils.measureBytes(cyclic)
		end).toThrow()
	end)
end)

describe("TeleportDataEnvelopeUtils.classifySize", function()
	it("classifies small data as ok", function()
		local result = TeleportDataEnvelopeUtils.classifySize({ slot = "a" })

		expect(result.level).toBe("ok")
		expect(result.bytes).toBeGreaterThan(0)
	end)

	it("classifies data approaching the cap as warn", function()
		local justOverWarn = TeleportDataEnvelopeUtils.WARN_TELEPORT_DATA_BYTES + 1024
		local result = TeleportDataEnvelopeUtils.classifySize({ blob = string.rep("x", justOverWarn) })

		expect(result.level).toBe("warn")
	end)

	it("classifies data past the cap as over", function()
		local overMax = TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES + 1024
		local result = TeleportDataEnvelopeUtils.classifySize({ blob = string.rep("x", overMax) })

		expect(result.level).toBe("over")
		expect(result.bytes).toBeGreaterThan(TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES)
	end)
end)
