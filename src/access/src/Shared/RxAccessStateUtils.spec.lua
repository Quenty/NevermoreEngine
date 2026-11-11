--!strict
--[[
	@class RxAccessStateUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local Observable = require("Observable")
local RxAccessStateUtils = require("RxAccessStateUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function controllable()
	local subs: { any } = {}

	local observable = Observable.new(function(sub)
		table.insert(subs, sub)

		return function()
			local index = table.find(subs, sub)
			if index then
				table.remove(subs, index)
			end
		end
	end)

	return observable, function(value: any)
		for _, sub in table.clone(subs) do
			sub:Fire(value)
		end
	end
end

describe("RxAccessStateUtils.ofStatic", function()
	it("never completes, so a share cannot drop its upstream", function()
		local maid = Maid.new()
		local completed = false

		maid:GiveTask(RxAccessStateUtils.ofStatic(true):Subscribe(nil, nil, function()
			completed = true
		end))

		expect(completed).toEqual(false)
		maid:DoCleaning()
	end)

	it("carries a nil, which no stock Rx constructor manages", function()
		local maid = Maid.new()
		local emissions = 0

		maid:GiveTask(RxAccessStateUtils.ofStatic(nil):Subscribe(function(value)
			emissions += 1
			expect(value).toEqual(nil)
		end))

		expect(emissions).toEqual(1)
		maid:DoCleaning()
	end)
end)

describe("RxAccessStateUtils.startUnresolved", function()
	it("emits before the source has said anything", function()
		local maid = Maid.new()
		local source, fire = controllable()
		local values = {}

		maid:GiveTask(source:Pipe({ RxAccessStateUtils.startUnresolved() }):Subscribe(function(value)
			table.insert(values, { value = value })
		end))

		expect(#values).toEqual(1)
		expect(values[1].value).toEqual(nil)

		fire(true)
		expect(#values).toEqual(2)
		expect(values[2].value).toEqual(true)

		maid:DoCleaning()
	end)
end)

describe("RxAccessStateUtils.completeOn", function()
	it("completes the stream when the notifier fires", function()
		-- Rx.takeUntil drops the subscription without completing, which leaves a consumer unable to tell a
		-- finished session from a quiet one.
		local maid = Maid.new()
		local source = controllable()
		local notifier, fireNotifier = controllable()
		local completed = false

		maid:GiveTask(source:Pipe({ RxAccessStateUtils.completeOn(notifier) }):Subscribe(nil, nil, function()
			completed = true
		end))

		expect(completed).toEqual(false)
		fireNotifier(true)
		expect(completed).toEqual(true)

		maid:DoCleaning()
	end)

	it("stops passing values through once the notifier has fired", function()
		local maid = Maid.new()
		local source, fireSource = controllable()
		local notifier, fireNotifier = controllable()
		local received = 0

		maid:GiveTask(source:Pipe({ RxAccessStateUtils.completeOn(notifier) }):Subscribe(function()
			received += 1
		end))

		fireSource(true)
		expect(received).toEqual(1)

		fireNotifier(true)
		fireSource(true)
		expect(received).toEqual(1)

		maid:DoCleaning()
	end)
end)
