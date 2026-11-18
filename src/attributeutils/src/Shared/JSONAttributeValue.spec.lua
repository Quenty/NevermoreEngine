--!strict
--[[
	@class JSONAttributeValue.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local JSONAttributeValue = require("JSONAttributeValue")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	folder: Folder,
	newJSONValue: (attributeName: string, defaultValue: any) -> JSONAttributeValue.JSONAttributeValue<any>,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local folder = maid:Add(Instance.new("Folder"))

	local controller: Controller = {
		maid = maid,
		folder = folder,
		newJSONValue = function(attributeName, defaultValue)
			return JSONAttributeValue.new(folder, attributeName, defaultValue)
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("JSONAttributeValue.new()", function()
	it("encodes the default value onto the object", function()
		local controller = setup()

		controller.newJSONValue("Facts", { "a", "b" })

		expect(controller.folder:GetAttribute("Facts")).toBe('["a","b"]')
	end)

	it("writes nothing when there is no default value", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", nil)

		expect(controller.folder:GetAttribute("Facts")).toBe(nil)
		expect(jsonValue.Value).toBe(nil)
	end)
end)

describe("JSONAttributeValue.Value", function()
	it("round trips a dictionary", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", {})
		jsonValue.Value = { enabled = true, count = 3 }

		expect(jsonValue.Value).toEqual({ enabled = true, count = 3 })
	end)

	it("round trips a list", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", {})
		jsonValue.Value = { "a", "b" }

		expect(jsonValue.Value).toEqual({ "a", "b" })
	end)

	it("decodes what another writer stored", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", {})
		controller.folder:SetAttribute("Facts", '{"enabled":true}')

		expect(jsonValue.Value).toEqual({ enabled = true })
	end)

	it("falls back to the default once the attribute is cleared", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", { "a" })
		controller.folder:SetAttribute("Facts", nil)

		expect(jsonValue.Value).toEqual({ "a" })
	end)

	it("clears the attribute when written a value it cannot encode", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", { "a" })
		jsonValue.Value = 5

		expect(controller.folder:GetAttribute("Facts")).toBe(nil)
	end)

	it("reads nil when the attribute is not a string", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", nil)
		controller.folder:SetAttribute("Facts", 5)

		expect(jsonValue.Value).toBe(nil)
	end)
end)

describe("JSONAttributeValue:Observe()", function()
	it("fires the decoded value and every change", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", { "a" })
		local facts = RxTestUtils.collectList(controller.maid, jsonValue:Observe())

		jsonValue.Value = { "a", "b" }

		expect(facts).toEqual({ { "a" }, { "a", "b" } })
	end)

	it("fires the default value once the attribute is cleared", function()
		local controller = setup()

		local jsonValue = controller.newJSONValue("Facts", { "a" })
		local facts = RxTestUtils.collectList(controller.maid, jsonValue:Observe())

		controller.folder:SetAttribute("Facts", nil)

		expect(facts).toEqual({ { "a" }, { "a" } })
	end)
end)
