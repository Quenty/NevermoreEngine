--!strict
--[[
	@class EncodedAttributeValue.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local EncodedAttributeValue = require("EncodedAttributeValue")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function encode(value: number): string?
	return if value == nil then nil else tostring(value)
end

local function decode(value: string?): number
	return (if type(value) == "string" then tonumber(value) else nil) :: any
end

type Controller = {
	maid: Maid.Maid,
	folder: Folder,
	newEncodedValue: (
		attributeName: string,
		defaultValue: number?
	) -> EncodedAttributeValue.EncodedAttributeValue<string?, number>,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local folder = maid:Add(Instance.new("Folder"))

	local controller: Controller = {
		maid = maid,
		folder = folder,
		newEncodedValue = function(attributeName, defaultValue)
			return EncodedAttributeValue.new(folder, attributeName, encode, decode, defaultValue)
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("EncodedAttributeValue.new()", function()
	it("encodes the default value onto the object", function()
		local controller = setup()

		controller.newEncodedValue("Count", 5)

		expect(controller.folder:GetAttribute("Count")).toBe("5")
	end)

	it("leaves an attribute that is already set", function()
		local controller = setup()

		controller.folder:SetAttribute("Count", "7")
		local encodedValue = controller.newEncodedValue("Count", 5)

		expect(controller.folder:GetAttribute("Count")).toBe("7")
		expect(encodedValue.Value).toBe(7)
	end)

	it("writes nothing when there is no default value", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", nil)

		expect(controller.folder:GetAttribute("Count")).toBe(nil)
		expect(encodedValue.Value).toBe(nil)
	end)

	it("rejects an encode that is not a function", function()
		local controller = setup()

		expect(function()
			EncodedAttributeValue.new(controller.folder, "Count", nil :: any, decode, 5)
		end).toThrow()
	end)

	it("rejects a decode that is not a function", function()
		local controller = setup()

		expect(function()
			EncodedAttributeValue.new(controller.folder, "Count", encode, nil :: any, 5)
		end).toThrow()
	end)
end)

describe("EncodedAttributeValue.Value", function()
	it("decodes what is stored on the object", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		controller.folder:SetAttribute("Count", "7")

		expect(encodedValue.Value).toBe(7)
	end)

	it("encodes what is written to it", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		encodedValue.Value = 7

		expect(controller.folder:GetAttribute("Count")).toBe("7")
		expect(encodedValue.Value).toBe(7)
	end)

	it("falls back to the default once the attribute is cleared", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		encodedValue.Value = nil :: any

		expect(controller.folder:GetAttribute("Count")).toBe(nil)
		expect(encodedValue.Value).toBe(5)
	end)
end)

describe("EncodedAttributeValue.AttributeName", function()
	it("reports the attribute it is bound to", function()
		local controller = setup()

		expect(controller.newEncodedValue("Count", 5).AttributeName).toBe("Count")
	end)

	it("cannot be assigned to", function()
		local controller = setup()

		local encodedValue: any = controller.newEncodedValue("Count", 5)

		expect(function()
			encodedValue.AttributeName = "Other"
		end).toThrow()
	end)
end)

describe("EncodedAttributeValue.Changed", function()
	it("fires when the attribute changes", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)

		local seen = {}
		controller.maid:GiveTask(encodedValue.Changed:Connect(function()
			table.insert(seen, encodedValue.Value)
		end))

		encodedValue.Value = 7

		expect(seen).toEqual({ 7 })
	end)
end)

describe("EncodedAttributeValue members", function()
	it("throws when reading a member that does not exist", function()
		local controller = setup()

		local encodedValue: any = controller.newEncodedValue("Count", 5)

		expect(function()
			return encodedValue.NotAMember
		end).toThrow()
	end)

	it("throws when writing a member that does not exist", function()
		local controller = setup()

		local encodedValue: any = controller.newEncodedValue("Count", 5)

		expect(function()
			encodedValue.NotAMember = true
		end).toThrow()
	end)
end)

describe("EncodedAttributeValue:Observe()", function()
	it("fires the decoded value and every change", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		local counts = RxTestUtils.collectList(controller.maid, encodedValue:Observe())

		encodedValue.Value = 7

		expect(counts).toEqual({ 5, 7 })
	end)

	it("fires the default value once the attribute is cleared", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		local counts = RxTestUtils.collectList(controller.maid, encodedValue:Observe())

		encodedValue.Value = nil :: any

		expect(counts).toEqual({ 5, 5 })
	end)

	it("fires nil when there is no default value", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", nil)
		local counts = controller.maid:Add(ObservableSpy.new(encodedValue:Observe()))

		expect(#counts).toBe(1)
		expect(counts[1]).toBe(nil)
	end)
end)

describe("EncodedAttributeValue:ObserveBrio()", function()
	it("emits a brio with the decoded value", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		local brios = RxTestUtils.collectList(controller.maid, encodedValue:ObserveBrio())

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe(5)
	end)

	it("kills the last brio when the value changes", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		local brios = RxTestUtils.collectList(controller.maid, encodedValue:ObserveBrio())

		encodedValue.Value = 7

		expect(#brios).toBe(2)
		expect(brios[1]:IsDead()).toBe(true)
		expect(brios[2]:GetValue()).toBe(7)
	end)

	it("skips encoded values the condition rejects", function()
		local controller = setup()

		local encodedValue = controller.newEncodedValue("Count", 5)
		local brios = RxTestUtils.collectList(
			controller.maid,
			encodedValue:ObserveBrio(function(value)
				return value == "7"
			end)
		)

		expect(#brios).toBe(0)

		encodedValue.Value = 7

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe(7)
	end)
end)
