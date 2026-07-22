--!strict
--[[
	@class BinderGroup.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderGroup = require("BinderGroup")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local tagCounter = 0

local function setup()
	local binders: { any } = {}

	local function newBinder(): Binder.Binder<any>
		tagCounter += 1
		local binder = Binder.new(string.format("BinderGroupSpecTag_%d", tagCounter), function()
			return {}
		end)
		table.insert(binders, binder)
		return binder
	end

	return {
		newBinder = newBinder,
		destroy = function()
			for _, binder in binders do
				pcall(function()
					binder:Destroy()
				end)
			end
		end,
	}
end

describe("BinderGroup.new()", function()
	it("constructs with an initial list of binders", function()
		local controller = setup()

		local binderA = controller.newBinder()
		local binderB = controller.newBinder()
		local group = BinderGroup.new({ binderA, binderB })

		expect(#group:GetBinders()).toEqual(2)

		controller.destroy()
	end)

	it("constructs empty", function()
		local group = BinderGroup.new({})
		expect(#group:GetBinders()).toEqual(0)
	end)
end)

describe("BinderGroup:Add()", function()
	it("adds a binder and exposes it via GetBinders", function()
		local controller = setup()

		local group = BinderGroup.new({})
		local binder = controller.newBinder()
		group:Add(binder)

		expect(group:GetBinders()[1]).toEqual(binder)

		controller.destroy()
	end)

	it("fires BinderAdded with the added binder", function()
		local controller = setup()

		local group = BinderGroup.new({})
		local fired
		group.BinderAdded:Connect(function(binder)
			fired = binder
		end)

		local binder = controller.newBinder()
		group:Add(binder)

		expect(fired).toEqual(binder)

		controller.destroy()
	end)

	it("throws when the value is not a binder", function()
		local group = BinderGroup.new({})
		expect(function()
			group:Add({} :: any)
		end).toThrow()
	end)
end)

describe("BinderGroup constructor validation", function()
	it("accepts binders whose constructor passes validation", function()
		local controller = setup()

		local validated = {}
		local group = BinderGroup.new({}, function(constructor)
			table.insert(validated, constructor)
			return true
		end)

		local binder = controller.newBinder()
		group:Add(binder)

		expect(validated[1]).toEqual(binder:GetConstructor())

		controller.destroy()
	end)

	it("throws when the constructor fails validation", function()
		local controller = setup()

		local group = BinderGroup.new({}, function()
			return false
		end)

		local binder = controller.newBinder()
		expect(function()
			group:Add(binder)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("BinderGroup:AddList()", function()
	it("adds each binder in the list", function()
		local controller = setup()

		local group = BinderGroup.new({})
		group:AddList({ controller.newBinder(), controller.newBinder() })

		expect(#group:GetBinders()).toEqual(2)

		controller.destroy()
	end)

	it("throws on a non-table argument", function()
		local group = BinderGroup.new({})
		expect(function()
			group:AddList(5 :: any)
		end).toThrow()
	end)
end)
