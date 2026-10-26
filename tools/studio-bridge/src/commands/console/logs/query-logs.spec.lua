--!strict
--[[
	@class query-logs.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local Jest = require("Jest")
local MessageBuffer = require("MessageBuffer")
local QueryLogsAction = require("query-logs")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(entries: { { level: string, body: string } }): any
	local router = ActionRouter.new()
	local logBuffer = MessageBuffer.new(100)
	for index, entry in entries do
		logBuffer:Push({ level = entry.level, body = entry.body, timestamp = index })
	end

	QueryLogsAction.register(router, nil, logBuffer)

	return {
		query = function(payload: { [string]: any }): any
			local response = router:Dispatch({ type = "queryLogs", sessionId = "session-1", payload = payload })
			assert(response, "No response")
			return response
		end,
	}
end

local function getBodies(response: any): { string }
	local bodies = {}
	for _, entry in response.payload.entries do
		table.insert(bodies, entry.body)
	end
	return bodies
end

local MIXED_ENTRIES = {
	{ level = "Print", body = "one" },
	{ level = "Warning", body = "two" },
	{ level = "Error", body = "three" },
	{ level = "Print", body = "[StudioBridge] internal" },
	{ level = "Print", body = "four" },
}

describe("queryLogs", function()
	it("should answer logsResult with the buffer's total and capacity", function()
		local controller = setup(MIXED_ENTRIES)

		local response = controller.query({})

		expect(response.type).toEqual("logsResult")
		expect(response.payload.total).toEqual(5)
		expect(response.payload.bufferCapacity).toEqual(100)
	end)

	it("should return the newest entries by default, oldest first", function()
		local controller = setup(MIXED_ENTRIES)

		expect(getBodies(controller.query({ count = 2 }))).toEqual({ "three", "four" })
	end)

	it("should return the oldest entries for head", function()
		local controller = setup(MIXED_ENTRIES)

		expect(getBodies(controller.query({ direction = "head", count = 2 }))).toEqual({ "one", "two" })
	end)

	it("should keep only the requested levels", function()
		local controller = setup(MIXED_ENTRIES)

		expect(getBodies(controller.query({ levels = { "Warning", "Error" } }))).toEqual({ "two", "three" })
	end)

	it("should leave out [StudioBridge] messages unless asked", function()
		local controller = setup(MIXED_ENTRIES)

		expect(getBodies(controller.query({}))).toEqual({ "one", "two", "three", "four" })
		expect(getBodies(controller.query({ includeInternal = true }))).toEqual({
			"one",
			"two",
			"three",
			"[StudioBridge] internal",
			"four",
		})
	end)

	it("should count after filtering", function()
		local controller = setup(MIXED_ENTRIES)

		expect(getBodies(controller.query({ levels = { "Print" }, count = 1 }))).toEqual({ "four" })
	end)

	it("should return no entries for an empty buffer", function()
		local controller = setup({})

		local response = controller.query({})

		expect(response.payload.entries).toEqual({})
		expect(response.payload.total).toEqual(0)
	end)
end)
