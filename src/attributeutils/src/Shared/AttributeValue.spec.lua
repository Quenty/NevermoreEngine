--!strict
--[[
	@class AttributeValue.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	folder: Folder,
	newAttributeValue: (attributeName: string, defaultValue: any) -> AttributeValue.AttributeValue<any>,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local folder = maid:Add(Instance.new("Folder"))

	local controller: Controller = {
		maid = maid,
		folder = folder,
		newAttributeValue = function(attributeName, defaultValue)
			return AttributeValue.new(folder, attributeName, defaultValue)
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AttributeValue.new()", function()
	it("writes the default value to the object", function()
		local controller = setup()

		controller.newAttributeValue("Version", "1.0.0")

		expect(controller.folder:GetAttribute("Version")).toBe("1.0.0")
	end)

	it("leaves an attribute that is already set", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "2.0.0")
		local attributeValue = controller.newAttributeValue("Version", "1.0.0")

		expect(controller.folder:GetAttribute("Version")).toBe("2.0.0")
		expect(attributeValue.Value).toBe("2.0.0")
	end)

	it("writes nothing when there is no default value", function()
		local controller = setup()

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

		expect(function()
			AttributeValue.new(controller.folder, nil :: any, "1.0.0")
		end).toThrow()
	end)
end)

describe("AttributeValue.Value", function()
	it("reads the attribute back", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		controller.folder:SetAttribute("Version", "2.0.0")

		expect(attributeValue.Value).toBe("2.0.0")
	end)

	it("writes the attribute", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		attributeValue.Value = "2.0.0"

		expect(controller.folder:GetAttribute("Version")).toBe("2.0.0")
		expect(attributeValue.Value).toBe("2.0.0")
	end)

	it("falls back to the default once the attribute is cleared", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		attributeValue.Value = nil

		expect(controller.folder:GetAttribute("Version")).toBe(nil)
		expect(attributeValue.Value).toBe("1.0.0")
	end)
end)

describe("AttributeValue.AttributeName", function()
	it("reports the attribute it is bound to", function()
		local controller = setup()

		expect(controller.newAttributeValue("Version", "1.0.0").AttributeName).toBe("Version")
	end)

	it("cannot be assigned to", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")

		expect(function()
			attributeValue.AttributeName = "Other"
		end).toThrow()
	end)
end)

describe("AttributeValue.Changed", function()
	it("fires when the attribute changes", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")

		local seen = {}
		controller.maid:GiveTask(attributeValue.Changed:Connect(function()
			table.insert(seen, attributeValue.Value)
		end))

		attributeValue.Value = "2.0.0"

		expect(seen).toEqual({ "2.0.0" })
	end)
end)

describe("AttributeValue members", function()
	it("throws when reading a member that does not exist", function()
		local controller = setup()

		local attributeValue: any = controller.newAttributeValue("Version", "1.0.0")

		expect(function()
			return attributeValue.NotAMember
		end).toThrow()
	end)

	it("throws when writing a member that does not exist", function()
		local controller = setup()

		local attributeValue: any = controller.newAttributeValue("Version", "1.0.0")

		expect(function()
			attributeValue.NotAMember = true
		end).toThrow()
	end)
end)

describe("AttributeValue:Observe()", function()
	it("fires the current value and every change", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local versions = RxTestUtils.collectList(controller.maid, attributeValue:Observe())

		attributeValue.Value = "2.0.0"

		expect(versions).toEqual({ "1.0.0", "2.0.0" })
	end)

	it("fires the default value once the attribute is cleared", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local versions = RxTestUtils.collectList(controller.maid, attributeValue:Observe())

		attributeValue.Value = nil

		expect(versions).toEqual({ "1.0.0", "1.0.0" })
	end)

	it("fires nil when there is no default value", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", nil)
		local versions = controller.maid:Add(ObservableSpy.new(attributeValue:Observe()))

		expect(#versions).toBe(1)
		expect(versions[1]).toBe(nil)
	end)
end)

describe("AttributeValue:ObserveBrio()", function()
	it("emits a brio for the current value", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local brios = RxTestUtils.collectList(controller.maid, attributeValue:ObserveBrio())

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe("1.0.0")
	end)

	it("kills the last brio when the value changes", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Version", "1.0.0")
		local brios = RxTestUtils.collectList(controller.maid, attributeValue:ObserveBrio())

		attributeValue.Value = "2.0.0"

		expect(#brios).toBe(2)
		expect(brios[1]:IsDead()).toBe(true)
		expect(brios[2]:GetValue()).toBe("2.0.0")
	end)

	it("skips values the condition rejects", function()
		local controller = setup()

		local attributeValue = controller.newAttributeValue("Count", 1)
		local brios = RxTestUtils.collectList(
			controller.maid,
			attributeValue:ObserveBrio(function(value)
				return value >= 3
			end)
		)

		expect(#brios).toBe(0)

		attributeValue.Value = 3

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe(3)
	end)
end)
