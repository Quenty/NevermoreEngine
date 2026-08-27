--!strict
--[[
	@class AttributeValue.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()
	local folder = maid:Add(Instance.new("Folder"))

	return {
		folder = folder,
		newAttributeValue = function(attributeName: string, defaultValue: any)
			return AttributeValue.new(folder, attributeName, defaultValue)
		end,
		observeInto = function(observable: any)
			local values = {}
			maid:GiveTask(observable:Subscribe(function(value)
				table.insert(values, value)
			end))

			return values
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

describe("AttributeValue.new()", function()
	it("writes the default value to the object", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.newAttributeValue("Version", "1.0.0")

		expect(controller.folder:GetAttribute("Version")).toBe("1.0.0")
	end)

	it("leaves an attribute that is already set", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		controller.folder:SetAttribute("Version", "2.0.0")
		local attributeValue = controller.newAttributeValue("Version", "1.0.0")

		expect(controller.folder:GetAttribute("Version")).toBe("2.0.0")
		expect(attributeValue.Value).toBe("2.0.0")
	end)

	it("writes nothing when there is no default value", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", nil)

		expect(controller.folder:GetAttribute("Version")).toBe(nil)
		expect(attributeValue.Value).toBe(nil)
	end)

	it("rejects an object that is not an instance", function()
		expect(function()
			AttributeValue.new(nil :: any, "Version", "1.0.0")
		end).toThrow()
	end)

	it("rejects an attribute name that is not a string", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		expect(function()
			AttributeValue.new(controller.folder, nil :: any, "1.0.0")
		end).toThrow()
	end)
end)

describe("AttributeValue.Value", function()
	it("reads the attribute back", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		controller.folder:SetAttribute("Version", "2.0.0")

		expect(attributeValue.Value).toBe("2.0.0")
	end)

	it("writes the attribute", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		attributeValue.Value = "2.0.0"

		expect(controller.folder:GetAttribute("Version")).toBe("2.0.0")
		expect(attributeValue.Value).toBe("2.0.0")
	end)

	it("falls back to the default once the attribute is cleared", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		attributeValue.Value = nil

		expect(controller.folder:GetAttribute("Version")).toBe(nil)
		expect(attributeValue.Value).toBe("1.0.0")
	end)
end)

describe("AttributeValue.AttributeName", function()
	it("reports the attribute it is bound to", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		expect(controller.newAttributeValue("Version", "1.0.0").AttributeName).toBe("Version")
	end)

	it("cannot be assigned to", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")

		expect(function()
			attributeValue.AttributeName = "Other"
		end).toThrow()
	end)
end)

describe("AttributeValue.Changed", function()
	it("fires when the attribute changes", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")

		local seen = {}
		JestUtils.afterThis(attributeValue.Changed:Connect(function()
			table.insert(seen, attributeValue.Value)
		end))

		attributeValue.Value = "2.0.0"
		task.wait()

		expect(seen).toEqual({ "2.0.0" })
	end)
end)

describe("AttributeValue members", function()
	it("throws when reading a member that does not exist", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue: any = controller.newAttributeValue("Version", "1.0.0")

		expect(function()
			return attributeValue.NotAMember
		end).toThrow()
	end)

	it("throws when writing a member that does not exist", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue: any = controller.newAttributeValue("Version", "1.0.0")

		expect(function()
			attributeValue.NotAMember = true
		end).toThrow()
	end)
end)

describe("AttributeValue:Observe()", function()
	it("fires the current value and every change", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local values = controller.observeInto(attributeValue:Observe())

		attributeValue.Value = "2.0.0"
		task.wait()

		expect(values).toEqual({ "1.0.0", "2.0.0" })
	end)

	it("fires the default value once the attribute is cleared", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local values = controller.observeInto(attributeValue:Observe())

		attributeValue.Value = nil
		task.wait()

		expect(values).toEqual({ "1.0.0", "1.0.0" })
	end)

	it("fires nil when there is no default value", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", nil)

		local fireCount = 0
		local lastValue: any = "unset"
		JestUtils.afterThis(attributeValue:Observe():Subscribe(function(value)
			fireCount += 1
			lastValue = value
		end))

		expect(fireCount).toBe(1)
		expect(lastValue).toBe(nil)
	end)
end)

describe("AttributeValue:ObserveBrio()", function()
	it("emits a brio for the current value", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local brios = controller.observeInto(attributeValue:ObserveBrio())

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe("1.0.0")
	end)

	it("kills the last brio when the value changes", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local brios = controller.observeInto(attributeValue:ObserveBrio())

		attributeValue.Value = "2.0.0"
		task.wait()

		expect(#brios).toBe(2)
		expect(brios[1]:IsDead()).toBe(true)
		expect(brios[2]:GetValue()).toBe("2.0.0")
	end)

	it("skips values the condition rejects", function()
		local controller = setup()
		JestUtils.afterThis(controller.destroy)

		local attributeValue = controller.newAttributeValue("Count", 1)
		local brios = controller.observeInto(attributeValue:ObserveBrio(function(value)
			return value >= 3
		end))

		expect(#brios).toBe(0)

		attributeValue.Value = 3
		task.wait()

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe(3)
	end)
end)
