--!strict
--[[
	@class onRenderStepFrame.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local onRenderStepFrame = require("onRenderStepFrame")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	bind: (number, () -> ()) -> () -> (),
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local unbinds: { () -> () } = {}

	maid:GiveTask(function()
		for _, unbind in unbinds do
			unbind()
		end
	end)

	local controller: Controller = {
		bind = function(priority: number, callback: () -> ())
			local unbind = onRenderStepFrame(priority, callback)
			table.insert(unbinds, unbind)
			return unbind
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("onRenderStepFrame", function()
	it("returns an unbind function", function()
		local controller = setup()

		local unbind = controller.bind(Enum.RenderPriority.Last.Value, function() end)

		expect(type(unbind)).toBe("function")

		controller:Destroy()
	end)

	it("tolerates a repeated unbind", function()
		local controller = setup()

		local unbind = controller.bind(Enum.RenderPriority.Last.Value, function() end)

		expect(function()
			unbind()
			unbind()
		end).never.toThrow()

		controller:Destroy()
	end)

	it("binds each call under its own key", function()
		local controller = setup()

		local first = controller.bind(Enum.RenderPriority.Last.Value, function() end)
		local second = controller.bind(Enum.RenderPriority.Last.Value, function() end)

		expect(second).never.toBe(first)
		expect(function()
			first()
			second()
		end).never.toThrow()

		controller:Destroy()
	end)

	it("throws on a non-number priority", function()
		local controller = setup()

		expect(function()
			(onRenderStepFrame :: any)("high", function() end)
		end).toThrow()

		controller:Destroy()
	end)

	it("throws on a non-function callback", function()
		local controller = setup()

		expect(function()
			(onRenderStepFrame :: any)(100, "callback")
		end).toThrow()

		controller:Destroy()
	end)
end)
