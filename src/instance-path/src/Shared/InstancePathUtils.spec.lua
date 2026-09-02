--!strict
--[[
	@class InstancePathUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InstancePathUtils = require("InstancePathUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function makeChild(parent: Instance, className: string, name: string): Instance
	local child = Instance.new(className :: any)
	child.Name = name
	child.Parent = parent
	return child
end

describe("InstancePathUtils.isInstancePath(instancePath)", function()
	it("should return true for a string", function()
		expect(InstancePathUtils.isInstancePath("a")).toEqual(true)
	end)

	it("should return true for an empty string", function()
		expect(InstancePathUtils.isInstancePath("")).toEqual(true)
	end)

	it("should return false for a non-string", function()
		expect(InstancePathUtils.isInstancePath(5)).toEqual(false)
		expect(InstancePathUtils.isInstancePath(nil)).toEqual(false)
		expect(InstancePathUtils.isInstancePath({})).toEqual(false)
	end)
end)

describe("InstancePathUtils.toPathTable(instancePath)", function()
	it("should split a dotted path into a table", function()
		expect(InstancePathUtils.toPathTable("a.b.c")).toEqual({ "a", "b", "c" })
	end)

	it("should return a single-element table for a simple path", function()
		expect(InstancePathUtils.toPathTable("master")).toEqual({ "master" })
	end)

	it("should pass a path table through", function()
		expect(InstancePathUtils.toPathTable({ "a", "b", "c" })).toEqual({ "a", "b", "c" })
	end)

	it("should copy a path table so the caller's own table is never mutated", function()
		local pathTable = { "a", "b", "c" }
		local result = InstancePathUtils.toPathTable(pathTable)
		table.remove(result)

		expect(result).never.toBe(pathTable)
		expect(pathTable).toEqual({ "a", "b", "c" })
	end)

	it("should throw for neither form of a path", function()
		expect(function()
			InstancePathUtils.toPathTable(5 :: any)
		end).toThrow()
	end)
end)

describe("InstancePathUtils.fromPathTable(pathTable)", function()
	it("should join names with dots", function()
		expect(InstancePathUtils.fromPathTable({ "a", "b", "c" })).toEqual("a.b.c")
	end)

	it("should round-trip with toPathTable", function()
		local instancePath: InstancePathUtils.InstancePath = "a.b.c"
		local pathTable: InstancePathUtils.InstancePathTable = InstancePathUtils.toPathTable(instancePath)

		expect(InstancePathUtils.fromPathTable(pathTable)).toEqual(instancePath)
	end)

	it("should pass a dotted path through", function()
		expect(InstancePathUtils.fromPathTable("a.b.c")).toEqual("a.b.c")
	end)

	it("should throw for neither form of a path", function()
		expect(function()
			InstancePathUtils.fromPathTable(5 :: any)
		end).toThrow()
	end)
end)

describe("InstancePathUtils.isInstancePathTableLike(instancePath)", function()
	it("should be true for a dotted path", function()
		expect(InstancePathUtils.isInstancePathTableLike("a.b")).toBe(true)
	end)

	it("should be true for a path table", function()
		expect(InstancePathUtils.isInstancePathTableLike({ "a", "b" })).toBe(true)
	end)

	it("should be false for neither form of a path", function()
		expect(InstancePathUtils.isInstancePathTableLike(5)).toBe(false)
		expect(InstancePathUtils.isInstancePathTableLike(nil)).toBe(false)
	end)
end)

describe("InstancePathUtils.getParentPath(instancePath)", function()
	it("should drop the last segment", function()
		expect(InstancePathUtils.getParentPath("Quenty.default")).toEqual("Quenty")
	end)

	it("should keep every segment but the last for a deep path", function()
		expect(InstancePathUtils.getParentPath("a.b.c")).toEqual("a.b")
	end)

	it("should return nil for a single-segment path", function()
		expect(InstancePathUtils.getParentPath("default")).toEqual(nil)
	end)

	it("should throw for a non-string", function()
		expect(function()
			InstancePathUtils.getParentPath(5 :: any)
		end).toThrow()
	end)
end)

describe("InstancePathUtils.getName(instancePath)", function()
	it("should return the last segment", function()
		expect(InstancePathUtils.getName("Quenty.default")).toEqual("default")
	end)

	it("should return the whole path for a single-segment path", function()
		expect(InstancePathUtils.getName("default")).toEqual("default")
	end)

	it("should recompose with getParentPath", function()
		local instancePath = "a.b.c"
		local parentPath = InstancePathUtils.getParentPath(instancePath) :: string

		expect(parentPath .. "." .. InstancePathUtils.getName(instancePath)).toEqual(instancePath)
	end)

	it("should throw for a non-string", function()
		expect(function()
			InstancePathUtils.getName(5 :: any)
		end).toThrow()
	end)
end)

describe("InstancePathUtils.getPathTo(root, instance)", function()
	it("should return the name of a direct child", function()
		local root = Instance.new("Folder")
		local child = makeChild(root, "SoundGroup", "Master")

		expect(InstancePathUtils.getPathTo(root, child)).toEqual("Master")
	end)

	it("should return the full path of a nested descendant", function()
		local root = Instance.new("Folder")
		local master = makeChild(root, "SoundGroup", "Master")
		local music = makeChild(master, "SoundGroup", "Music")

		expect(InstancePathUtils.getPathTo(root, music)).toEqual("Master.Music")
	end)

	it("should round-trip with findInstance", function()
		local root = Instance.new("Folder")
		local master = makeChild(root, "SoundGroup", "Master")
		local music = makeChild(master, "SoundGroup", "Music")

		local instancePath = InstancePathUtils.getPathTo(root, music) :: string

		expect(InstancePathUtils.findInstance(root, instancePath, "SoundGroup")).toEqual(music)
	end)

	it("should return nil for the root itself", function()
		local root = Instance.new("Folder")

		expect(InstancePathUtils.getPathTo(root, root)).toEqual(nil)
	end)

	it("should return nil for an instance outside the root", function()
		local root = Instance.new("Folder")
		local other = Instance.new("Folder")
		local child = makeChild(other, "SoundGroup", "Master")

		expect(InstancePathUtils.getPathTo(root, child)).toEqual(nil)
	end)

	it("should return nil for an ancestor of the root", function()
		local grandparent = Instance.new("Folder")
		local root = makeChild(grandparent, "Folder", "Root")

		expect(InstancePathUtils.getPathTo(root, grandparent)).toEqual(nil)
	end)

	it("should throw for a bad instance", function()
		expect(function()
			InstancePathUtils.getPathTo(Instance.new("Folder"), nil :: any)
		end).toThrow()
	end)
end)

describe("InstancePathUtils.findInstance(root, instancePath, className)", function()
	it("should find a direct child", function()
		local root = Instance.new("Folder")
		local child = makeChild(root, "SoundGroup", "Master")

		expect(InstancePathUtils.findInstance(root, "Master", "SoundGroup")).toEqual(child)
	end)

	it("should find a nested descendant", function()
		local root = Instance.new("Folder")
		local master = makeChild(root, "SoundGroup", "Master")
		local music = makeChild(master, "SoundGroup", "Music")

		expect(InstancePathUtils.findInstance(root, "Master.Music", "SoundGroup")).toEqual(music)
	end)

	it("should return nil when a segment is missing", function()
		local root = Instance.new("Folder")
		makeChild(root, "SoundGroup", "Master")

		expect(InstancePathUtils.findInstance(root, "Master.Music", "SoundGroup")).toEqual(nil)
	end)

	it("should return nil when a segment has the wrong class", function()
		local root = Instance.new("Folder")
		local master = makeChild(root, "SoundGroup", "Master")
		makeChild(master, "Folder", "Music")

		expect(InstancePathUtils.findInstance(root, "Master.Music", "SoundGroup")).toEqual(nil)
	end)

	it("should match any class when no className is given", function()
		local root = Instance.new("Folder")
		local master = makeChild(root, "SoundGroup", "Master")
		local music = makeChild(master, "Folder", "Music")

		expect(InstancePathUtils.findInstance(root, "Master.Music")).toEqual(music)
	end)

	it("should return the first match when no className is given", function()
		local root = Instance.new("Folder")
		local first = makeChild(root, "Folder", "Master")
		makeChild(root, "SoundGroup", "Master")

		expect(InstancePathUtils.findInstance(root, "Master")).toEqual(first)
	end)

	it("should accept a base class name", function()
		local root = Instance.new("Folder")
		local part = makeChild(root, "Part", "Target")

		expect(InstancePathUtils.findInstance(root, "Target", "BasePart")).toEqual(part)
	end)

	it("should skip a same-named child of the wrong class", function()
		local root = Instance.new("Folder")
		makeChild(root, "Folder", "Master")
		local soundGroup = makeChild(root, "SoundGroup", "Master")

		expect(InstancePathUtils.findInstance(root, "Master", "SoundGroup")).toEqual(soundGroup)
	end)

	it("should never return the root itself", function()
		local root = Instance.new("Folder")
		root.Name = "Master"

		expect(InstancePathUtils.findInstance(root, "Master", "Folder")).toEqual(nil)
	end)

	it("should throw for a bad root", function()
		expect(function()
			InstancePathUtils.findInstance(nil :: any, "Master", "SoundGroup")
		end).toThrow()
	end)

	it("should throw for a bad instancePath", function()
		expect(function()
			InstancePathUtils.findInstance(Instance.new("Folder"), 5 :: any, "SoundGroup")
		end).toThrow()
	end)
end)

describe("InstancePathUtils.findOrCreateInstance(root, instancePath, className, onCreate)", function()
	it("should create a direct child", function()
		local root = Instance.new("Folder")

		local created = InstancePathUtils.findOrCreateInstance(root, "Master", "SoundGroup")

		expect(created.Name).toEqual("Master")
		expect(created.ClassName).toEqual("SoundGroup")
		expect(created.Parent).toEqual(root)
	end)

	it("should create every missing segment of the path", function()
		local root = Instance.new("Folder")

		local created = InstancePathUtils.findOrCreateInstance(root, "Master.Music", "SoundGroup")
		local parent = created.Parent :: Instance

		expect(created.Name).toEqual("Music")
		expect(parent.Name).toEqual("Master")
		expect(parent.Parent).toEqual(root)
	end)

	it("should reuse existing instances instead of creating duplicates", function()
		local root = Instance.new("Folder")
		local master = makeChild(root, "SoundGroup", "Master")

		local created = InstancePathUtils.findOrCreateInstance(root, "Master.Music", "SoundGroup")

		expect(created.Parent).toEqual(master)
		expect(#root:GetChildren()).toEqual(1)
	end)

	it("should be idempotent across repeated calls", function()
		local root = Instance.new("Folder")

		local first = InstancePathUtils.findOrCreateInstance(root, "Master.Music", "SoundGroup")
		local second = InstancePathUtils.findOrCreateInstance(root, "Master.Music", "SoundGroup")

		expect(second).toEqual(first)
		expect(#root:GetChildren()).toEqual(1)
	end)

	it("should create alongside a same-named child of another class", function()
		local root = Instance.new("Folder")
		local folder = makeChild(root, "Folder", "Master")

		local created = InstancePathUtils.findOrCreateInstance(root, "Master", "SoundGroup")

		expect(created).never.toEqual(folder)
		expect(created.ClassName).toEqual("SoundGroup")
		expect(#root:GetChildren()).toEqual(2)
	end)

	it("should invoke onCreate for each newly constructed instance", function()
		local root = Instance.new("Folder")
		local names = {}

		InstancePathUtils.findOrCreateInstance(root, "Master.Music", "SoundGroup", function(instance)
			table.insert(names, instance.Name)
		end)

		expect(names).toEqual({ "Master", "Music" })
	end)

	it("should not invoke onCreate for instances that already exist", function()
		local root = Instance.new("Folder")
		makeChild(root, "SoundGroup", "Master")
		local names = {}

		InstancePathUtils.findOrCreateInstance(root, "Master.Music", "SoundGroup", function(instance)
			table.insert(names, instance.Name)
		end)

		expect(names).toEqual({ "Music" })
	end)

	it("should invoke onCreate before parenting", function()
		local root = Instance.new("Folder")
		local parentAtCreate: Instance? = root

		InstancePathUtils.findOrCreateInstance(root, "Master", "SoundGroup", function(instance)
			parentAtCreate = instance.Parent
		end)

		expect(parentAtCreate).toEqual(nil)
	end)

	it("should throw for a bad className", function()
		expect(function()
			InstancePathUtils.findOrCreateInstance(Instance.new("Folder"), "Master", nil :: any)
		end).toThrow()
	end)

	it("should throw for a bad onCreate", function()
		expect(function()
			InstancePathUtils.findOrCreateInstance(Instance.new("Folder"), "Master", "SoundGroup", 5 :: any)
		end).toThrow()
	end)
end)
