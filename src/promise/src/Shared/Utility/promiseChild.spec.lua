--!nonstrict
--[[
	@class promiseChild.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local promiseChild = require("promiseChild")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("promiseChild", function()
	it("resolves immediately when the child already exists", function()
		local parent = Instance.new("Folder")
		local child = Instance.new("Folder")
		child.Name = "Target"
		child.Parent = parent
		parent.Parent = Workspace

		local promise = promiseChild(parent, "Target")
		expect(promise:IsFulfilled()).toEqual(true)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual(child)

		parent:Destroy()
	end)

	it("resolves once a matching child is added", function()
		local parent = Instance.new("Folder")
		parent.Parent = Workspace

		local promise = promiseChild(parent, "Later")
		expect(promise:IsPending()).toEqual(true)

		local child = Instance.new("Folder")
		child.Name = "Later"
		child.Parent = parent

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual(child)

		parent:Destroy()
	end)

	it("rejects when the child never appears before the timeout", function()
		local parent = Instance.new("Folder")
		parent.Parent = Workspace

		local outcome, err = PromiseTestUtils.awaitOutcome(promiseChild(parent, "Missing", 0.05))
		expect(outcome).toEqual("rejected")
		expect(string.find(tostring(err), "Timed out", 1, true) ~= nil).toEqual(true)

		parent:Destroy()
	end)
end)
