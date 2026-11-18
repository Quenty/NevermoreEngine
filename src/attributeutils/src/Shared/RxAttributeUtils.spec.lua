--!strict
--[[
	@class RxAttributeUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local RxAttributeUtils = require("RxAttributeUtils")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	folder: Folder,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local folder = maid:Add(Instance.new("Folder"))

	local controller: Controller = {
		maid = maid,
		folder = folder,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxAttributeUtils.observeAttribute()", function()
	it("fires the current value and every change", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")
		local versions =
			RxTestUtils.collectList(controller.maid, RxAttributeUtils.observeAttribute(controller.folder, "Version"))

		controller.folder:SetAttribute("Version", "2.0.0")

		expect(versions).toEqual({ "1.0.0", "2.0.0" })
	end)

	it("fires the default value while the attribute is unset", function()
		local controller = setup()

		local versions = RxTestUtils.collectList(
			controller.maid,
			RxAttributeUtils.observeAttribute(controller.folder, "Version", "1.0.0")
		)

		controller.folder:SetAttribute("Version", "2.0.0")
		controller.folder:SetAttribute("Version", nil)

		expect(versions).toEqual({ "1.0.0", "2.0.0", "1.0.0" })
	end)

	it("rejects an object that is not an instance", function()
		expect(function()
			RxAttributeUtils.observeAttribute(nil :: any, "Version")
		end).toThrow()
	end)
end)

describe("RxAttributeUtils.observeAttributeKeys()", function()
	it("fires every key that is already set", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")
		controller.folder:SetAttribute("Enabled", true)

		local keys = RxTestUtils.collectSet(controller.maid, RxAttributeUtils.observeAttributeKeys(controller.folder))

		expect(keys).toEqual({ Version = true, Enabled = true })
	end)

	it("fires keys as they are added", function()
		local controller = setup()

		local keys = RxTestUtils.collectSet(controller.maid, RxAttributeUtils.observeAttributeKeys(controller.folder))

		expect(keys).toEqual({})

		controller.folder:SetAttribute("Version", "1.0.0")

		expect(keys).toEqual({ Version = true })
	end)
end)

describe("RxAttributeUtils.observeAttributeKeysBrio()", function()
	it("emits a live brio for every key that is set", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")

		local brios =
			RxTestUtils.collectList(controller.maid, RxAttributeUtils.observeAttributeKeysBrio(controller.folder))

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe("Version")
		expect(brios[1]:IsDead()).toBe(false)
	end)

	it("kills the brio once the attribute is removed", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")

		local brios =
			RxTestUtils.collectList(controller.maid, RxAttributeUtils.observeAttributeKeysBrio(controller.folder))

		controller.folder:SetAttribute("Version", nil)

		expect(#brios).toBe(1)
		expect(brios[1]:IsDead()).toBe(true)
	end)

	it("keeps the same brio while the key only changes value", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")

		local brios =
			RxTestUtils.collectList(controller.maid, RxAttributeUtils.observeAttributeKeysBrio(controller.folder))

		controller.folder:SetAttribute("Version", "2.0.0")

		expect(#brios).toBe(1)
		expect(brios[1]:IsDead()).toBe(false)
	end)
end)

describe("RxAttributeUtils.observeAttributeBrio()", function()
	it("emits a brio for the current value", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")

		local brios = RxTestUtils.collectList(
			controller.maid,
			RxAttributeUtils.observeAttributeBrio(controller.folder, "Version")
		)

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe("1.0.0")
	end)

	it("replaces the brio when the value changes", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")

		local brios = RxTestUtils.collectList(
			controller.maid,
			RxAttributeUtils.observeAttributeBrio(controller.folder, "Version")
		)

		controller.folder:SetAttribute("Version", "2.0.0")

		expect(#brios).toBe(2)
		expect(brios[1]:IsDead()).toBe(true)
		expect(brios[2]:GetValue()).toBe("2.0.0")
	end)

	it("does not emit again for the same value", function()
		local controller = setup()

		controller.folder:SetAttribute("Version", "1.0.0")

		local brios = RxTestUtils.collectList(
			controller.maid,
			RxAttributeUtils.observeAttributeBrio(controller.folder, "Version")
		)

		controller.folder:SetAttribute("Version", "1.0.0")

		expect(#brios).toBe(1)
		expect(brios[1]:IsDead()).toBe(false)
	end)

	it("skips values the condition rejects", function()
		local controller = setup()

		controller.folder:SetAttribute("Count", 1)

		local brios = RxTestUtils.collectList(
			controller.maid,
			RxAttributeUtils.observeAttributeBrio(controller.folder, "Count", function(value)
				return value >= 3
			end)
		)

		expect(#brios).toBe(0)

		controller.folder:SetAttribute("Count", 3)

		expect(#brios).toBe(1)
		expect(brios[1]:GetValue()).toBe(3)
	end)
end)
