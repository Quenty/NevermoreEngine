--!strict
--[[
	@class InfluxDBWriteBuffer.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBWriteBuffer = require("InfluxDBWriteBuffer")
local InfluxDBWriteOptionUtils = require("InfluxDBWriteOptionUtils")
local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Records each flush so tests can assert what was handed to the flush handler and when.
local function newRecordingBuffer(options: InfluxDBWriteOptionUtils.InfluxDBWriteOptions)
	local flushes: { { string } } = {}
	local buffer = InfluxDBWriteBuffer.new(options, function(entries)
		table.insert(flushes, entries)
		return Promise.resolved()
	end)

	return buffer, flushes
end

-- A large flush interval keeps the time-based flush from firing during a test; Destroy cancels it.
local function options(overrides: { [string]: number })
	return InfluxDBWriteOptionUtils.createWriteOptions({
		batchSize = overrides.batchSize or 1000,
		maxBatchBytes = overrides.maxBatchBytes or 50_000_000,
		flushIntervalSeconds = overrides.flushIntervalSeconds or 9999,
	})
end

describe("InfluxDBWriteBuffer.Add", function()
	it("should not flush before the batch size is reached", function()
		local buffer, flushes = newRecordingBuffer(options({ batchSize = 3 }))

		buffer:Add("a")
		buffer:Add("b")

		expect(#flushes).toEqual(0)

		buffer:Destroy()
	end)

	it("should flush once the batch size is reached", function()
		local buffer, flushes = newRecordingBuffer(options({ batchSize = 2 }))

		buffer:Add("a")
		buffer:Add("b")

		expect(#flushes).toEqual(1)
		expect(flushes[1]).toEqual({ "a", "b" })

		buffer:Destroy()
	end)

	it("should preserve entry order across a flush", function()
		local buffer, flushes = newRecordingBuffer(options({ batchSize = 3 }))

		buffer:Add("first")
		buffer:Add("second")
		buffer:Add("third")

		expect(flushes[1]).toEqual({ "first", "second", "third" })

		buffer:Destroy()
	end)

	it("should reset after a flush so a later flush is empty", function()
		local buffer, flushes = newRecordingBuffer(options({ batchSize = 2 }))

		buffer:Add("a")
		buffer:Add("b")
		expect(#flushes).toEqual(1)

		-- Nothing buffered now, so an explicit flush must not re-send the batch.
		local promise = buffer:PromiseFlush()
		expect(PromiseTestUtils.awaitSettled(promise)).toEqual(true)
		expect(#flushes).toEqual(1)

		buffer:Destroy()
	end)

	it("should flush when the byte ceiling is exceeded", function()
		local buffer, flushes = newRecordingBuffer(options({ maxBatchBytes = 10 }))

		-- 12 bytes + 1 newline separator clears the 10-byte ceiling on its own.
		buffer:Add("abcdefghijkl")

		expect(#flushes).toEqual(1)
		expect(flushes[1]).toEqual({ "abcdefghijkl" })

		buffer:Destroy()
	end)

	it("should throw on a non-string entry", function()
		local buffer = newRecordingBuffer(options({}))

		expect(function()
			buffer:Add(5 :: any)
		end).toThrow("Bad entry")

		buffer:Destroy()
	end)
end)

describe("InfluxDBWriteBuffer.PromiseFlush", function()
	it("should flush pending entries below the batch size", function()
		local buffer, flushes = newRecordingBuffer(options({ batchSize = 100 }))

		buffer:Add("a")
		buffer:Add("b")
		expect(#flushes).toEqual(0)

		local promise = buffer:PromiseFlush()
		expect(PromiseTestUtils.awaitSettled(promise)).toEqual(true)
		expect(flushes[1]).toEqual({ "a", "b" })

		buffer:Destroy()
	end)

	it("should resolve without calling the handler when empty", function()
		local buffer, flushes = newRecordingBuffer(options({}))

		local promise = buffer:PromiseFlush()
		expect(PromiseTestUtils.awaitSettled(promise)).toEqual(true)
		expect(#flushes).toEqual(0)

		buffer:Destroy()
	end)
end)

describe("InfluxDBWriteBuffer.new", function()
	it("should throw without a flush handler", function()
		expect(function()
			InfluxDBWriteBuffer.new(options({}), nil :: any)
		end).toThrow("No promiseHandleFlush")
	end)
end)
