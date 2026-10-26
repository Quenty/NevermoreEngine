--!strict
--[[
	@class MessageBuffer.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MessageBuffer = require("MessageBuffer")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function pushBodies(buffer: MessageBuffer.MessageBuffer, bodies: { string })
	for index, body in bodies do
		buffer:Push({ level = "Print", body = body, timestamp = index })
	end
end

local function getBodies(entries: { MessageBuffer.LogEntry }): { string }
	local bodies = {}
	for _, entry in entries do
		table.insert(bodies, entry.body)
	end
	return bodies
end

describe("MessageBuffer.new()", function()
	it("should default to a capacity of 1000", function()
		local buffer = MessageBuffer.new()

		expect(buffer:get().bufferCapacity).toEqual(1000)
		expect(buffer:GetCount()).toEqual(0)
	end)
end)

describe("MessageBuffer:get()", function()
	it("should return entries oldest first for either direction", function()
		local buffer = MessageBuffer.new(10)
		pushBodies(buffer, { "a", "b", "c", "d" })

		expect(getBodies(buffer:get("head", 2).entries)).toEqual({ "a", "b" })
		expect(getBodies(buffer:get("tail", 2).entries)).toEqual({ "c", "d" })
	end)

	it("should default to every entry from the tail", function()
		local buffer = MessageBuffer.new(10)
		pushBodies(buffer, { "a", "b", "c" })

		expect(getBodies(buffer:get().entries)).toEqual({ "a", "b", "c" })
	end)

	it("should clamp a count larger than the buffer", function()
		local buffer = MessageBuffer.new(10)
		pushBodies(buffer, { "a", "b" })

		expect(getBodies(buffer:get("head", 50).entries)).toEqual({ "a", "b" })
		expect(getBodies(buffer:get("tail", 50).entries)).toEqual({ "a", "b" })
	end)

	it("should return nothing for a count of zero", function()
		local buffer = MessageBuffer.new(10)
		pushBodies(buffer, { "a", "b" })

		expect(buffer:get("head", 0).entries).toEqual({})
		expect(buffer:get("tail", 0).entries).toEqual({})
	end)

	it("should report the stored count and capacity", function()
		local buffer = MessageBuffer.new(5)
		pushBodies(buffer, { "a", "b", "c" })

		local snapshot = buffer:get("tail", 1)

		expect(snapshot.total).toEqual(3)
		expect(snapshot.bufferCapacity).toEqual(5)
	end)
end)

describe("MessageBuffer:Push()", function()
	it("should overwrite the oldest entries once full", function()
		local buffer = MessageBuffer.new(3)
		pushBodies(buffer, { "a", "b", "c", "d", "e" })

		expect(buffer:GetCount()).toEqual(3)
		expect(getBodies(buffer:get().entries)).toEqual({ "c", "d", "e" })
	end)

	it("should keep chronological order after wrapping many times", function()
		local buffer = MessageBuffer.new(4)
		local bodies = {}
		for index = 1, 23 do
			table.insert(bodies, tostring(index))
		end
		pushBodies(buffer, bodies)

		expect(getBodies(buffer:get().entries)).toEqual({ "20", "21", "22", "23" })
	end)
end)

describe("MessageBuffer:Clear()", function()
	it("should remove every entry and accept new ones", function()
		local buffer = MessageBuffer.new(3)
		pushBodies(buffer, { "a", "b", "c", "d" })

		buffer:Clear()

		expect(buffer:GetCount()).toEqual(0)
		expect(buffer:get().entries).toEqual({})

		pushBodies(buffer, { "x" })

		expect(getBodies(buffer:get().entries)).toEqual({ "x" })
	end)
end)
