--!nonstrict
--[[
	@class promisePropertyValue.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local promisePropertyValue = require("promisePropertyValue")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("promisePropertyValue", function()
	it("resolves immediately when the property is already truthy", function()
		local folder = Instance.new("Folder")
		folder.Name = "HasAName"
		folder.Parent = Workspace

		local promise = promisePropertyValue(folder, "Name")
		expect(promise:IsFulfilled()).toEqual(true)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual("HasAName")

		folder:Destroy()
	end)

	it("resolves once a falsy property becomes truthy", function()
		local objectValue = Instance.new("ObjectValue")
		objectValue.Parent = Workspace
		expect(objectValue.Value).toEqual(nil)

		local promise = promisePropertyValue(objectValue, "Value")
		expect(promise:IsPending()).toEqual(true)

		local target = Instance.new("Folder")
		target.Parent = Workspace
		objectValue.Value = target

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("resolved")
		expect(value).toEqual(target)

		objectValue:Destroy()
		target:Destroy()
	end)
end)
