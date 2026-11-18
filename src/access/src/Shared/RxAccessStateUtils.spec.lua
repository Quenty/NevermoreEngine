--!strict
--[[
	@class RxAccessStateUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local Rx = require("Rx")
local RxAccessStateUtils = require("RxAccessStateUtils")
local Signal = require("Signal")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	newSignal: () -> Signal.Signal<any>,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		maid = maid,
		newSignal = function()
			return maid:Add(Signal.new())
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxAccessStateUtils.ofStatic", function()
	it("never completes, so a share cannot drop its upstream", function()
		local controller = setup()

		local values = controller.maid:Add(ObservableSpy.new(RxAccessStateUtils.ofStatic(true)))

		expect(values:IsComplete()).toEqual(false)

		controller:Destroy()
	end)

	it("carries a nil, which no stock Rx constructor manages", function()
		local controller = setup()

		local values = controller.maid:Add(ObservableSpy.new(RxAccessStateUtils.ofStatic(nil)))

		expect(#values).toEqual(1)
		expect(values[1]).toEqual(nil)

		controller:Destroy()
	end)
end)

describe("RxAccessStateUtils.startUnresolved", function()
	it("emits before the source has said anything", function()
		local controller = setup()
		local source = controller.newSignal()

		local observable = Rx.fromSignal(source):Pipe({ RxAccessStateUtils.startUnresolved() }) :: any
		local values = controller.maid:Add(ObservableSpy.new(observable))

		expect(#values).toEqual(1)
		expect(values[1]).toEqual(nil)

		source:Fire(true)

		expect(#values).toEqual(2)
		expect(values[2]).toEqual(true)

		controller:Destroy()
	end)
end)

describe("RxAccessStateUtils.completeOn", function()
	it("completes the stream when the notifier fires", function()
		local controller = setup()
		local source = controller.newSignal()
		local notifier = controller.newSignal()

		local observable = Rx.fromSignal(source):Pipe({ RxAccessStateUtils.completeOn(Rx.fromSignal(notifier)) }) :: any
		local values = controller.maid:Add(ObservableSpy.new(observable))

		expect(values:IsComplete()).toEqual(false)

		notifier:Fire(true)

		expect(values:IsComplete()).toEqual(true)

		controller:Destroy()
	end)

	it("stops passing values through once the notifier has fired", function()
		local controller = setup()
		local source = controller.newSignal()
		local notifier = controller.newSignal()

		local observable = Rx.fromSignal(source):Pipe({ RxAccessStateUtils.completeOn(Rx.fromSignal(notifier)) }) :: any
		local values = controller.maid:Add(ObservableSpy.new(observable))

		source:Fire(true)

		expect(#values).toEqual(1)

		notifier:Fire(true)
		source:Fire(true)

		expect(#values).toEqual(1)

		controller:Destroy()
	end)
end)
