--!strict
--[[
	@class Binder.Loading.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local Signal = require("Signal")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("Binder load abandonment", function()
	it("does not bind a class when the instance is removed while the constructor yields", function()
		local controller = BinderTestUtils.setup()

		local entered = Signal.new()
		local resume = Signal.new()
		local constructed = 0

		local binder = controller.addBinder(function(inst)
			constructed += 1
			entered:Fire()
			resume:Wait()
			return { instance = inst }
		end)
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)

		-- The constructor may run synchronously on Tag or be deferred; wait until it has entered.
		if constructed == 0 then
			entered:Wait()
		end

		expect(constructed).toEqual(1)
		expect(binder:Get(inst)).toBeNil()

		binder:Untag(inst)
		resume:Fire()

		expect(binder:Get(inst)).toBeNil()
		expect(constructed).toEqual(1)

		controller:Destroy()
	end)

	it("does not construct for an instance destroyed before its added signal runs", function()
		local controller = BinderTestUtils.setup()

		local strays = 0
		local binder = controller.addBinder(function(inst)
			if not inst:IsDescendantOf(game) then
				strays += 1
			end
			return {}
		end)
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)
		inst:Destroy()
		task.wait()

		expect(strays).toEqual(0)
		expect(binder:Get(inst)).toBeNil()

		controller:Destroy()
	end)
end)
