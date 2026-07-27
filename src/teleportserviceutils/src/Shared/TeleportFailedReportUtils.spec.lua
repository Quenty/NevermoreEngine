--!strict
--[[
	@class TeleportFailedReportUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TeleportFailedReportUtils = require("TeleportFailedReportUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Every result the engine can report, so a test over all of them cannot silently miss one.
local ALL_RESULTS: { Enum.TeleportResult } = Enum.TeleportResult:GetEnumItems()

local IN_FLIGHT: { Enum.TeleportResult } = {
	Enum.TeleportResult.Success,
	Enum.TeleportResult.IsTeleporting,
}

local RETRYABLE: { Enum.TeleportResult } = {
	Enum.TeleportResult.Failure,
	Enum.TeleportResult.GameFull,
	Enum.TeleportResult.GameEnded,
}

local TERMINAL: { Enum.TeleportResult } = {
	Enum.TeleportResult.GameNotFound,
	Enum.TeleportResult.Unauthorized,
	Enum.TeleportResult.Flooded,
}

local function contains(results: { Enum.TeleportResult }, result: Enum.TeleportResult): boolean
	return table.find(results, result) ~= nil
end

describe("TeleportFailedReportUtils.new", function()
	it("keeps the whole of what the engine said", function()
		local report = TeleportFailedReportUtils.new(700, Enum.TeleportResult.GameFull, "server full")

		expect(report.placeId).toEqual(700)
		expect(report.result).toEqual(Enum.TeleportResult.GameFull)
		expect(report.message).toEqual("server full")
	end)

	it("renders itself, for a consumer that only wants a message", function()
		local report = TeleportFailedReportUtils.new(701, Enum.TeleportResult.Unauthorized, "not allowed")

		expect(tostring(report)).toContain("701")
		expect(tostring(report)).toContain("Unauthorized")
		expect(tostring(report)).toContain("not allowed")
	end)

	it("errors on a bad placeId, result, or message", function()
		expect(function()
			TeleportFailedReportUtils.new("nope" :: any, Enum.TeleportResult.Failure, "message")
		end).toThrow()
		expect(function()
			TeleportFailedReportUtils.new(702, "nope" :: any, "message")
		end).toThrow()
		expect(function()
			TeleportFailedReportUtils.new(702, Enum.TeleportResult.Failure, nil :: any)
		end).toThrow()
	end)
end)

describe("TeleportFailedReportUtils.isReport", function()
	it("tells a report from the empty rejection a cancelled teleport makes", function()
		expect(TeleportFailedReportUtils.isReport(TeleportFailedReportUtils.new(703, Enum.TeleportResult.Failure, "x"))).toEqual(
			true
		)
		expect(TeleportFailedReportUtils.isReport(nil)).toEqual(false)
		expect(TeleportFailedReportUtils.isReport("a string rejection")).toEqual(false)
		expect(TeleportFailedReportUtils.isReport({ message = "no result" })).toEqual(false)
	end)
end)

describe("TeleportFailedReportUtils classification", function()
	it("accounts for every result the engine can report", function()
		-- Guards the tables above against a result nobody classified: a new enum item, or one of these
		-- lists drifting. An unclassified result would silently fall through to "terminal".
		expect(#ALL_RESULTS).toEqual(#IN_FLIGHT + #RETRYABLE + #TERMINAL)
	end)

	it("treats Success and IsTeleporting as the hop still running, never as a refusal", function()
		for _, result in ALL_RESULTS do
			local report = TeleportFailedReportUtils.new(704, result, "message")

			expect({ result = result.Name, inFlight = TeleportFailedReportUtils.isInFlight(report) }).toEqual({
				result = result.Name,
				inFlight = contains(IN_FLIGHT, result),
			})
		end
	end)

	it("retries only refusals another request could clear", function()
		for _, result in ALL_RESULTS do
			local report = TeleportFailedReportUtils.new(705, result, "message")

			expect({ result = result.Name, retry = TeleportFailedReportUtils.shouldRetry(report) }).toEqual({
				result = result.Name,
				retry = contains(RETRYABLE, result),
			})
		end
	end)

	it("never retries Flooded or IsTeleporting, the two results another request makes worse", function()
		for _, result in { Enum.TeleportResult.Flooded, Enum.TeleportResult.IsTeleporting } do
			local report = TeleportFailedReportUtils.new(706, result, "message")

			expect(TeleportFailedReportUtils.shouldRetry(report)).toEqual(false)
		end
	end)
end)
