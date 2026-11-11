--!strict
--[[
	@class ReplicationFocusTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local ReplicationFocusTracker = require("ReplicationFocusTracker")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type FakeSubject = {
	focuses: { BasePart },
	AddReplicationFocus: (FakeSubject, BasePart) -> (),
	RemoveReplicationFocus: (FakeSubject, BasePart) -> (),
}

local function newFakeSubject(): FakeSubject
	local focuses: { BasePart } = {}

	return {
		focuses = focuses,
		AddReplicationFocus = function(_self, part)
			table.insert(focuses, part)
		end,
		RemoveReplicationFocus = function(_self, part)
			local index = table.find(focuses, part)
			if index then
				table.remove(focuses, index)
			end
		end,
	}
end

describe("ReplicationFocusTracker", function()
	it("creates a hidden part and adds it as a replication focus", function()
		local subject = newFakeSubject()
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:SetPosition(Vector3.new(1, 2, 3))

		local part = subject.focuses[1]
		assert(part, "expected a focus part")
		expect(part:IsA("BasePart")).toEqual(true)
		expect(part.Position).toEqual(Vector3.new(1, 2, 3))
		expect(part.Anchored).toEqual(true)
		expect(part.CanCollide).toEqual(false)

		tracker:Destroy()
	end)

	it("reuses the same part across position updates", function()
		local subject = newFakeSubject()
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:SetPosition(Vector3.new(1, 0, 0))
		local first = subject.focuses[1]
		assert(first, "expected a focus part")

		tracker:SetPosition(Vector3.new(5, 0, 0))

		expect(#subject.focuses).toEqual(1)
		expect(subject.focuses[1]).toBe(first)
		expect(first.Position).toEqual(Vector3.new(5, 0, 0))

		tracker:Destroy()
	end)

	it("reports active state", function()
		local subject = newFakeSubject()
		local tracker = ReplicationFocusTracker.new(subject :: any)

		expect(tracker:IsActive()).toEqual(false)
		tracker:SetPosition(Vector3.new(0, 0, 0))
		expect(tracker:IsActive()).toEqual(true)

		tracker:Destroy()
	end)

	it("removes the replication focus and destroys the part on Destroy", function()
		local subject = newFakeSubject()
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:SetPosition(Vector3.new(1, 2, 3))
		local part = subject.focuses[1]
		assert(part, "expected a focus part")

		tracker:Destroy()

		expect(#subject.focuses).toEqual(0)
		-- Destroyed parts are reparented to nil.
		expect(part.Parent).toEqual(nil)
	end)

	it("does nothing to a subject that was never positioned", function()
		local subject = newFakeSubject()
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:Destroy()

		expect(#subject.focuses).toEqual(0)
	end)

	it("adds and removes the focus through the PlayerMock seam", function()
		local player = PlayerMock.new()
		local tracker = ReplicationFocusTracker.new(player)

		tracker:SetPosition(Vector3.new(1, 2, 3))

		local focuses = PlayerMock.getReplicationFocuses(player)
		expect(#focuses).toEqual(1)
		expect(focuses[1].Position).toEqual(Vector3.new(1, 2, 3))

		tracker:Destroy()

		expect(#PlayerMock.getReplicationFocuses(player)).toEqual(0)

		player:Destroy()
	end)
end)
