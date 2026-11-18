--!strict
--[[
	@class RxPartBoundingBoxUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local RxPartBoundingBoxUtils = require("RxPartBoundingBoxUtils")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newPart: (cframe: CFrame?) -> BasePart,
	maid: Maid.Maid,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newPart = function(cframe)
			local part = Instance.new("Part")
			part.Anchored = true
			part.CFrame = cframe or CFrame.new()
			maid:GiveTask(part)
			return part
		end,

		maid = maid,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxPartBoundingBoxUtils.observePartCFrame", function()
	it("rejects an adornee that is not a part", function()
		local controller = setup()

		expect(function()
			RxPartBoundingBoxUtils.observePartCFrame(Instance.new("Folder") :: any)
		end).toThrow()

		controller:Destroy()
	end)

	it("emits the current cframe on subscribe", function()
		local controller = setup()

		local part = controller.newPart(CFrame.new(1, 2, 3))
		local cframes = controller.maid:Add(ObservableSpy.new(RxPartBoundingBoxUtils.observePartCFrame(part)))

		expect(#cframes).toBe(1)
		expect(cframes[1]).toEqual(CFrame.new(1, 2, 3))

		controller:Destroy()
	end)

	it("emits when the part moves", function()
		local controller = setup()

		local part = controller.newPart(CFrame.new())
		local cframes = controller.maid:Add(ObservableSpy.new(RxPartBoundingBoxUtils.observePartCFrame(part)))

		part.CFrame = CFrame.new(0, 40, 0)

		expect(#cframes).toBe(2)
		expect(cframes[2]).toEqual(CFrame.new(0, 40, 0))

		controller:Destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()

		local part = controller.newPart(CFrame.new())

		local cframes = controller.maid:Add(ObservableSpy.new(RxPartBoundingBoxUtils.observePartCFrame(part)))
		cframes:Destroy()

		part.CFrame = CFrame.new(0, 40, 0)
		StepUtils.deferWait()

		expect(#cframes).toBe(1)

		controller:Destroy()
	end)
end)
