--!strict
--[[
	@class JestUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("JestUtils.afterThis()", function()
	local order = {}

	it("leaves the tasks queued while the test is still running", function()
		JestUtils.afterThis(function()
			table.insert(order, "first")
		end)
		JestUtils.afterThis(function()
			table.insert(order, "second")
		end)

		expect(order).toEqual({})
	end)

	it("unwinds the queued tasks in reverse", function()
		expect(order).toEqual({ "second", "first" })
	end)

	it("rejects a value that is not a maid task", function()
		expect(function()
			JestUtils.afterThis(5)
		end).toThrow()
	end)
end)

describe("JestUtils.afterThis() with a maid task", function()
	local folder = Instance.new("Folder")
	folder.Parent = workspace

	local destroyed = false

	it("accepts an instance and a table with a Destroy method", function()
		JestUtils.afterThis(folder)
		JestUtils.afterThis({
			Destroy = function()
				destroyed = true
			end,
		})

		expect(folder.Parent).toBe(workspace)
		expect(destroyed).toBe(false)
	end)

	it("cleans them up once the test finishes", function()
		expect(folder.Parent).toBe(nil)
		expect(destroyed).toBe(true)
	end)
end)

describe("JestUtils.afterThis() cancellation", function()
	local order = {}

	it("returns a function that unqueues the task", function()
		JestUtils.afterThis(function()
			table.insert(order, "kept")
		end)

		local cancel = JestUtils.afterThis(function()
			table.insert(order, "cancelled")
		end)

		cancel()
		cancel()
	end)

	it("leaves the rest of the stack queued", function()
		expect(order).toEqual({ "kept" })
	end)
end)

describe("JestUtils.afterThis() cancelled by the maid that owns it", function()
	local order = {}

	it("hands back a maid task", function()
		local maid = Maid.new()
		maid:GiveTask(JestUtils.afterThis(function()
			table.insert(order, "cancelled")
		end))

		maid:DoCleaning()
	end)

	it("unqueues the task when the maid cleans up first", function()
		expect(order).toEqual({})
	end)
end)

describe("JestUtils.afterThis() while unwinding", function()
	local order = {}

	it("accepts a task queued from inside another task", function()
		JestUtils.afterThis(function()
			table.insert(order, "bottom")
		end)
		JestUtils.afterThis(function()
			table.insert(order, "top")

			JestUtils.afterThis(function()
				table.insert(order, "queued while unwinding")
			end)
		end)
	end)

	it("unwinds it before the rest of the stack", function()
		expect(order).toEqual({ "top", "queued while unwinding", "bottom" })
	end)
end)
