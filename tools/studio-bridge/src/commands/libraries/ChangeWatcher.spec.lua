--!strict
--[[
	@class ChangeWatcher.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ChangeWatcher = require("ChangeWatcher")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function makeValues(count: number): (Folder, { NumberValue })
	local folder = Instance.new("Folder")
	local values = {}
	for index = 1, count do
		local value = Instance.new("NumberValue")
		value.Name = `Value{index}`
		value.Parent = folder
		values[index] = value
	end
	return folder, values
end

local function newWatcher(members: { Instance }): any
	return ChangeWatcher.new({ membershipRoots = {}, initialMembers = members })
end

describe("ChangeWatcher", function()
	it("should have no rows when ItemChanged fires for a value set to what it was", function()
		local folder, values = makeValues(1)
		local watcher = newWatcher(values)
		watcher:Start()

		watcher:_markChanged(values[1], "Value")
		watcher:_markChanged(values[1], "NotAProperty")
		watcher:Step(0.1, 1)

		expect(watcher:HasRows()).toEqual(false)
		local starts, rows = watcher:TakeRows(0.1, 1)
		expect(#starts).toEqual(0)
		expect(#rows).toEqual(0)

		watcher:Destroy()
		folder:Destroy()
	end)

	it("should have rows once a value changes", function()
		local folder, values = makeValues(1)
		local watcher = newWatcher(values)
		watcher:Start()

		values[1].Value = 3
		watcher:_markChanged(values[1], "Value")
		watcher:Step(0.1, 1)

		expect(watcher:HasRows()).toEqual(true)
		local _, rows = watcher:TakeRows(0.1, 1)
		expect(#rows).toEqual(1)
		expect(rows[1].value).toEqual(3)

		watcher:Destroy()
		folder:Destroy()
	end)

	it("should not roll up on changes that change nothing", function()
		local folder, values = makeValues(ChangeWatcher.ROLLUP_THRESHOLD + 50)
		local watcher = newWatcher(values)
		watcher:Start()

		for _, value in values do
			watcher:_markChanged(value, "NotAProperty")
		end
		values[1].Value = 5
		watcher:_markChanged(values[1], "Value")
		watcher:Step(0.1, 1)

		local _, rows = watcher:TakeRows(0.1, 1)
		expect(#rows).toEqual(1)
		expect(rows[1].kind).toEqual("value")
		expect(rows[1].value).toEqual(5)

		watcher:Destroy()
		folder:Destroy()
	end)

	it("should leave out BrickColor when Color changed in the same frame", function()
		local part = Instance.new("Part")
		local watcher = newWatcher({ part })
		watcher:Start()

		part.Color = Color3.new(1, 0, 0)
		watcher:_markChanged(part, "BrickColor")
		watcher:_markChanged(part, "Color")
		watcher:Step(0.1, 1)

		local _, rows = watcher:TakeRows(0.1, 1)
		local properties = {}
		for _, row in rows do
			properties[string.match(row.property, "^[^%.]+")] = true
		end
		expect(properties).toEqual({ Color = true })

		watcher:Destroy()
		part:Destroy()
	end)

	it("should keep BrickColor when Color did not change", function()
		local part = Instance.new("Part")
		local watcher = newWatcher({ part })
		watcher:Start()

		part.BrickColor = BrickColor.new("Bright red")
		watcher:_markChanged(part, "BrickColor")
		watcher:Step(0.1, 1)

		local _, rows = watcher:TakeRows(0.1, 1)
		expect(#rows).toEqual(1)
		expect(rows[1].property).toEqual("BrickColor")

		watcher:Destroy()
		part:Destroy()
	end)
end)
