--!strict
--[[
	@class ObservableSpy.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSpy = require("ObservableSpy")
local PromiseTestUtils = require("PromiseTestUtils")
local Rx = require("Rx")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	newSource: () -> (Observable.Observable<string?>, (value: string?) -> ()),
	newSpyWithNil: () -> ObservableSpy.ObservableSpy<string?>,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local function newSource(): (Observable.Observable<string?>, (value: string?) -> ())
		local subs: { any } = {}
		local observable = Observable.new(function(sub)
			table.insert(subs, sub)
			return
		end)

		local function fire(value: string?)
			for _, sub in subs do
				sub:Fire(value)
			end
		end

		return observable :: any, fire
	end

	local controller: Controller = {
		maid = maid,
		newSource = newSource,
		newSpyWithNil = function()
			local source, fire = newSource()
			local values = maid:Add(ObservableSpy.new(source))

			fire("a")
			fire(nil)
			fire("c")

			return values
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("ObservableSpy as a list", function()
	it("counts nil emissions in its length", function()
		local controller = setup()

		local values = controller.newSpyWithNil()

		expect(#values).toBe(3)
		expect(values:GetCount()).toBe(3)
	end)

	it("indexes each emission in order", function()
		local controller = setup()

		local values = controller.newSpyWithNil()

		expect(values[1]).toBe("a")
		expect(values[2]).toBe(nil)
		expect(values[3]).toBe("c")
		expect(values:GetLastValue()).toBe("c")
	end)

	it("exposes the values as a list", function()
		local controller = setup()

		local values = controller.newSpyWithNil()

		local expected: { string? } = { "a", nil, "c" }
		expect(values.Values).toEqual(expected)
		expect(values.Values).toEqual(values:GetValues())
	end)

	it("iterates every emission in order, including nil", function()
		local controller = setup()

		local values = controller.newSpyWithNil()

		local seen: { { index: number, value: string? } } = {}
		for index, value in values do
			table.insert(seen, { index = index :: number, value = value })
		end

		local expected: { { index: number, value: string? } } = {
			{ index = 1, value = "a" },
			{ index = 2, value = nil },
			{ index = 3, value = "c" },
		}
		expect(seen).toEqual(expected)
	end)

	it("throws when reading a member that does not exist", function()
		local controller = setup()

		local values: any = controller.newSpyWithNil()

		expect(function()
			return values.NotAMember
		end).toThrow()
	end)
end)

describe("ObservableSpy lifecycle", function()
	it("records completion", function()
		local controller = setup()

		local values = controller.maid:Add(ObservableSpy.new(Rx.of("a") :: any))

		expect(values:IsComplete()).toBe(true)
		expect(values:GetState()).toBe("complete")
		PromiseTestUtils.awaitFulfilled(values:PromiseOnComplete())
		PromiseTestUtils.awaitRejected(values:PromiseOnError())
	end)

	it("records failure", function()
		local controller = setup()

		local values = controller.maid:Add(ObservableSpy.new(Observable.new(function(sub)
			sub:Fail("boom")
			return
		end) :: any))

		expect(values:HasFailed()).toBe(true)
		expect(values:GetError()).toBe("boom")
		expect(PromiseTestUtils.awaitFulfilled(values:PromiseOnError())).toBe("boom")
		PromiseTestUtils.awaitRejected(values:PromiseOnComplete())
	end)

	it("keeps what it recorded after being destroyed", function()
		local controller = setup()

		local source, fire = controller.newSource()
		local values = controller.maid:Add(ObservableSpy.new(source))

		fire("a")
		values:Destroy()
		fire("b")

		expect(values.Values).toEqual({ "a" })
		expect(values:GetState()).toBe("destroyed")
	end)
end)
