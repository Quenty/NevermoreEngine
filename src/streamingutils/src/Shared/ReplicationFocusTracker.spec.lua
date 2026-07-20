--!strict
--[[
	@class ReplicationFocusTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local ReplicationFocusTracker = require("ReplicationFocusTracker")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type FakeSubject = { ReplicationFocus: BasePart? }

describe("ReplicationFocusTracker", function()
	it("creates a hidden part and assigns it as the subject's ReplicationFocus", function()
		local subject: FakeSubject = {}
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:SetPosition(Vector3.new(1, 2, 3))

		local part = subject.ReplicationFocus
		assert(part, "expected a focus part")
		expect(part:IsA("BasePart")).toEqual(true)
		expect(part.Position).toEqual(Vector3.new(1, 2, 3))
		expect(part.Anchored).toEqual(true)
		expect(part.CanCollide).toEqual(false)

		tracker:Destroy()
	end)

	it("reuses the same part across position updates", function()
		local subject: FakeSubject = {}
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:SetPosition(Vector3.new(1, 0, 0))
		local first = subject.ReplicationFocus
		assert(first, "expected a focus part")

		tracker:SetPosition(Vector3.new(5, 0, 0))

		expect(subject.ReplicationFocus).toBe(first)
		expect(first.Position).toEqual(Vector3.new(5, 0, 0))

		tracker:Destroy()
	end)

	it("reports active state", function()
		local subject: FakeSubject = {}
		local tracker = ReplicationFocusTracker.new(subject :: any)

		expect(tracker:IsActive()).toEqual(false)
		tracker:SetPosition(Vector3.new(0, 0, 0))
		expect(tracker:IsActive()).toEqual(true)

		tracker:Destroy()
	end)

	it("clears the ReplicationFocus and destroys the part on Destroy", function()
		local subject: FakeSubject = {}
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:SetPosition(Vector3.new(1, 2, 3))
		local part = subject.ReplicationFocus
		assert(part, "expected a focus part")

		tracker:Destroy()

		expect(subject.ReplicationFocus).toEqual(nil)
		-- Destroyed parts are reparented to nil.
		expect(part.Parent).toEqual(nil)
	end)

	it("does nothing to a subject that was never positioned", function()
		local subject: FakeSubject = {}
		local tracker = ReplicationFocusTracker.new(subject :: any)

		tracker:Destroy()

		expect(subject.ReplicationFocus).toEqual(nil)
	end)
end)
