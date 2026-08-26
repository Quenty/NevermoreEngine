--!strict
--[[
	@class onSteppedFrame.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local onSteppedFrame = require("onSteppedFrame")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	bind: (() -> ()) -> RBXScriptConnection,
	destroy: () -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local connections: { RBXScriptConnection } = {}

	maid:GiveTask(function()
		for _, conn in connections do
			conn:Disconnect()
		end
	end)

	local controller: Controller = {
		bind = function(callback)
			local conn = onSteppedFrame(callback)
			table.insert(connections, conn)
			return conn
		end,

		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("onSteppedFrame", function()
	it("returns a live connection", function()
		local controller = setup()

		local conn = controller.bind(function() end)

		expect(typeof(conn)).toBe("RBXScriptConnection")
		expect(conn.Connected).toBe(true)

		controller.destroy()
	end)

	it("goes dead once disconnected", function()
		local controller = setup()

		local conn = controller.bind(function() end)
		conn:Disconnect()

		expect(conn.Connected).toBe(false)

		controller.destroy()
	end)

	it("tolerates a repeated disconnect", function()
		local controller = setup()

		local conn = controller.bind(function() end)

		expect(function()
			conn:Disconnect()
			conn:Disconnect()
		end).never.toThrow()

		controller.destroy()
	end)

	it("throws on a non-function", function()
		local controller = setup()

		expect(function()
			(onSteppedFrame :: any)("func")
		end).toThrow()

		controller.destroy()
	end)
end)
