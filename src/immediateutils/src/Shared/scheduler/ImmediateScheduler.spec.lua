--!strict
--[[
	@class ImmediateScheduler.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local ImmediateCoreUtils = require("ImmediateCoreUtils")
local ImmediateScheduler = require("ImmediateScheduler")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function makeRuntime()
	return ImmediateCoreUtils.createImmediateRuntime(ServiceBag.new(), function(_path: string)
		return nil
	end)
end

describe("ImmediateScheduler.RegisterSystem disposer", function()
	it("unregisters only while the same table is still registered", function()
		local scheduler = ImmediateScheduler.new()
		local firstDestroyed = 0
		local secondDestroyed = 0
		local first = {
			name = "alpha",
			system = function() end,
			Destroy = function()
				firstDestroyed += 1
			end,
		}
		local second = {
			name = "alpha",
			system = function() end,
			Destroy = function()
				secondDestroyed += 1
			end,
		}

		local disposeFirst = scheduler:RegisterSystem(first)
		scheduler:RegisterSystem(second)

		expect(firstDestroyed).toEqual(1)
		expect(secondDestroyed).toEqual(0)

		disposeFirst()

		expect(firstDestroyed).toEqual(1)
		expect(secondDestroyed).toEqual(0)

		scheduler:Destroy()
		expect(secondDestroyed).toEqual(1)
	end)
end)

describe("ImmediateScheduler.Destroy", function()
	it("completes without recursion and destroys registered systems once", function()
		local scheduler = ImmediateScheduler.new()
		local destroyed = 0
		scheduler:RegisterSystem({
			name = "alpha",
			system = function() end,
			Destroy = function()
				destroyed += 1
			end,
		})

		scheduler:Destroy()
		expect(destroyed).toEqual(1)
	end)

	it("can tick before destroy", function()
		local scheduler = ImmediateScheduler.new()
		local rt = makeRuntime()
		local ran = 0
		scheduler:RegisterSystem({
			name = "alpha",
			system = function()
				ran += 1
			end,
		})
		scheduler:Tick(rt)
		expect(ran).toEqual(1)
		scheduler:Destroy()
	end)
end)
