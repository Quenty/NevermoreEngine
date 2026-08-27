--!strict
--[[
	@class AttributeUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local CancelToken = require("CancelToken")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	return {
		folder = maid:Add(Instance.new("Folder")),
		newCancelSource = function()
			local cancel: (() -> ())?
			local token = CancelToken.new(function(doCancel)
				cancel = doCancel
			end)

			return token, assert(cancel, "No cancel")
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("AttributeUtils.isValidAttributeType()", function()
	it("accepts types Roblox can store in an attribute", function()
		expect(AttributeUtils.isValidAttributeType("string")).toBe(true)
		expect(AttributeUtils.isValidAttributeType("number")).toBe(true)
		expect(AttributeUtils.isValidAttributeType("boolean")).toBe(true)
		expect(AttributeUtils.isValidAttributeType("Vector3")).toBe(true)
	end)

	it("rejects types Roblox cannot store in an attribute", function()
		expect(AttributeUtils.isValidAttributeType("table")).toBe(false)
		expect(AttributeUtils.isValidAttributeType("function")).toBe(false)
		expect(AttributeUtils.isValidAttributeType("Instance")).toBe(false)
	end)
end)

describe("AttributeUtils.initAttribute()", function()
	it("writes the default when the attribute is unset", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		expect(AttributeUtils.initAttribute(controller.folder, "Version", "1.0.0")).toBe("1.0.0")
		expect(controller.folder:GetAttribute("Version")).toBe("1.0.0")
	end)

	it("keeps a value that is already set", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.folder:SetAttribute("Version", "2.0.0")

		expect(AttributeUtils.initAttribute(controller.folder, "Version", "1.0.0")).toBe("2.0.0")
		expect(controller.folder:GetAttribute("Version")).toBe("2.0.0")
	end)

	it("keeps a value of false", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.folder:SetAttribute("Enabled", false)

		expect(AttributeUtils.initAttribute(controller.folder, "Enabled", true)).toBe(false)
	end)
end)

describe("AttributeUtils.getAttribute()", function()
	it("returns the default when the attribute is unset", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		expect(AttributeUtils.getAttribute(controller.folder, "Version", "1.0.0")).toBe("1.0.0")
		expect(controller.folder:GetAttribute("Version")).toBe(nil)
	end)

	it("returns the attribute when it is set", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.folder:SetAttribute("Version", "2.0.0")

		expect(AttributeUtils.getAttribute(controller.folder, "Version", "1.0.0")).toBe("2.0.0")
	end)

	it("returns a value of false instead of the default", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.folder:SetAttribute("Enabled", false)

		expect(AttributeUtils.getAttribute(controller.folder, "Enabled", true)).toBe(false)
	end)
end)

describe("AttributeUtils.removeAllAttributes()", function()
	it("removes every attribute", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.folder:SetAttribute("Version", "1.0.0")
		controller.folder:SetAttribute("Enabled", false)

		AttributeUtils.removeAllAttributes(controller.folder)

		expect(next(controller.folder:GetAttributes())).toBe(nil)
	end)

	it("leaves an instance without attributes alone", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		AttributeUtils.removeAllAttributes(controller.folder)

		expect(next(controller.folder:GetAttributes())).toBe(nil)
	end)
end)

describe("AttributeUtils.promiseAttribute()", function()
	it("resolves immediately when the attribute is already set", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.folder:SetAttribute("Version", "1.0.0")

		local promise = AttributeUtils.promiseAttribute(controller.folder, "Version")
		JestUtils.afterThis(promise)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toBe("resolved")
		expect(value).toBe("1.0.0")
	end)

	it("resolves once the attribute is set", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local promise = AttributeUtils.promiseAttribute(controller.folder, "Version")
		JestUtils.afterThis(promise)

		expect(promise:IsPending()).toBe(true)

		controller.folder:SetAttribute("Version", "1.0.0")

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toBe("resolved")
		expect(value).toBe("1.0.0")
	end)

	it("waits for a value the predicate accepts", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local promise = AttributeUtils.promiseAttribute(controller.folder, "Count", function(value)
			return type(value) == "number" and value >= 3
		end)
		JestUtils.afterThis(promise)

		controller.folder:SetAttribute("Count", 1)
		task.wait()

		expect(promise:IsPending()).toBe(true)

		controller.folder:SetAttribute("Count", 3)

		local outcome, value = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toBe("resolved")
		expect(value).toBe(3)
	end)

	it("rejects when the cancel token cancels", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local token, cancel = controller.newCancelSource()

		local promise = AttributeUtils.promiseAttribute(controller.folder, "Version", nil, token)
		JestUtils.afterThis(promise)

		cancel()

		local outcome = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toBe("rejected")
	end)

	it("rejects a predicate that is not a function", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		expect(function()
			AttributeUtils.promiseAttribute(controller.folder, "Version", 5 :: any)
		end).toThrow()
	end)
end)
