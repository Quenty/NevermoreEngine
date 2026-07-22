--!strict
--[[
	@class BinderUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local BinderUtils = require("BinderUtils")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function makeClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "BinderUtilsSpecClass"
	function Class.new(inst)
		return setmetatable({ instance = inst }, Class)
	end
	function Class:Destroy() end
	return Class
end

local function setup()
	specCounter += 1
	local suffix = specCounter

	local serviceBag = ServiceBag.new()
	local container = Instance.new("Folder")
	container.Name = "BinderUtilsSpecContainer"
	container.Parent = workspace

	local instances = {}
	local pendingBinders: { any } = {}
	local tagCounter = 0
	local booted = false

	local function newBinder(): Binder.Binder<any>
		assert(not booted, "Cannot add a binder after boot()")
		tagCounter += 1
		local binder = Binder.new(string.format("BinderUtilsSpecTag_%d_%d", suffix, tagCounter), makeClass() :: any)
		table.insert(pendingBinders, binder)
		return binder
	end

	local function newInstance(parent: Instance?, className: string?): Instance
		local inst = Instance.new(className or "Folder")
		inst.Parent = parent or container
		table.insert(instances, inst)
		return inst
	end

	local function boot()
		assert(not booted, "Already booted")
		booted = true

		local binders = pendingBinders
		local provider = BinderProvider.new(string.format("BinderUtilsSpecProvider_%d", suffix), function(self)
			for _, binder in binders do
				self:Add(binder)
			end
		end)
		serviceBag:GetService(provider)
		serviceBag:Init()
		serviceBag:Start()
	end

	return {
		container = container,
		newBinder = newBinder,
		newInstance = newInstance,
		boot = boot,
		destroy = function()
			serviceBag:Destroy()
			for _, inst in instances do
				pcall(function()
					inst:Destroy()
				end)
			end
			container:Destroy()
		end,
	}
end

describe("BinderUtils.findFirstAncestor()", function()
	it("returns the nearest bound ancestor, skipping the child itself", function()
		local controller = setup()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)

		local binder = controller.newBinder()
		binder:Tag(grandparent)
		binder:Tag(child) -- child is bound too, but must be skipped
		controller.boot()

		expect(BinderUtils.findFirstAncestor(binder, child)).toEqual(binder:Get(grandparent))

		controller.destroy()
	end)

	it("returns nil when no ancestor is bound", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local binder = controller.newBinder()
		controller.boot()

		expect(BinderUtils.findFirstAncestor(binder, child)).toBeNil()

		controller.destroy()
	end)

	it("throws for a non-instance child", function()
		local controller = setup()

		local binder = controller.newBinder()
		controller.boot()
		expect(function()
			BinderUtils.findFirstAncestor(binder, 5 :: any)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("BinderUtils.findFirstChild()", function()
	it("returns the first bound child", function()
		local controller = setup()

		local parent = controller.newInstance()
		local unboundChild = controller.newInstance(parent)
		local boundChild = controller.newInstance(parent)

		local binder = controller.newBinder()
		binder:Tag(boundChild)
		controller.boot()

		expect(BinderUtils.findFirstChild(binder, parent)).toEqual(binder:Get(boundChild))
		expect(binder:Get(unboundChild)).toBeNil()

		controller.destroy()
	end)

	it("returns nil when no child is bound", function()
		local controller = setup()

		local parent = controller.newInstance()
		controller.newInstance(parent)
		local binder = controller.newBinder()
		controller.boot()

		expect(BinderUtils.findFirstChild(binder, parent)).toBeNil()

		controller.destroy()
	end)
end)

describe("BinderUtils.getChildren()", function()
	it("returns every bound child", function()
		local controller = setup()

		local parent = controller.newInstance()
		local childA = controller.newInstance(parent)
		local childB = controller.newInstance(parent)
		controller.newInstance(parent) -- unbound

		local binder = controller.newBinder()
		binder:Tag(childA)
		binder:Tag(childB)
		controller.boot()

		expect(#BinderUtils.getChildren(binder, parent)).toEqual(2)

		controller.destroy()
	end)

	it("does not include bound descendants deeper than one level", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local grandchild = controller.newInstance(child)

		local binder = controller.newBinder()
		binder:Tag(grandchild)
		controller.boot()

		expect(#BinderUtils.getChildren(binder, parent)).toEqual(0)

		controller.destroy()
	end)
end)

describe("BinderUtils.getDescendants()", function()
	it("returns bound instances at any depth", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local grandchild = controller.newInstance(child)

		local binder = controller.newBinder()
		binder:Tag(child)
		binder:Tag(grandchild)
		controller.boot()

		expect(#BinderUtils.getDescendants(binder, parent)).toEqual(2)

		controller.destroy()
	end)
end)

describe("BinderUtils.mapBinderListToTable()", function()
	it("keys binders by their tag", function()
		local controller = setup()

		local binderA = controller.newBinder()
		local binderB = controller.newBinder()
		controller.boot()

		local map = BinderUtils.mapBinderListToTable({ binderA, binderB })
		expect(map[binderA:GetTag()]).toEqual(binderA)
		expect(map[binderB:GetTag()]).toEqual(binderB)

		controller.destroy()
	end)
end)

describe("BinderUtils.getMappedFromList()", function()
	it("resolves bound values across an instance list by tag", function()
		local controller = setup()

		local instA = controller.newInstance()
		local instB = controller.newInstance()
		local binderA = controller.newBinder()
		local binderB = controller.newBinder()
		binderA:Tag(instA)
		binderB:Tag(instB)
		controller.boot()

		local tagsMap = BinderUtils.mapBinderListToTable({ binderA, binderB })
		local objects = BinderUtils.getMappedFromList(tagsMap, { instA, instB, controller.newInstance() })

		expect(#objects).toEqual(2)

		controller.destroy()
	end)
end)

describe("BinderUtils.getChildrenOfBinders()", function()
	it("returns children bound by any binder in the list", function()
		local controller = setup()

		local parent = controller.newInstance()
		local childA = controller.newInstance(parent)
		local childB = controller.newInstance(parent)

		local binderA = controller.newBinder()
		local binderB = controller.newBinder()
		binderA:Tag(childA)
		binderB:Tag(childB)
		controller.boot()

		expect(#BinderUtils.getChildrenOfBinders({ binderA, binderB }, parent)).toEqual(2)

		controller.destroy()
	end)
end)

describe("BinderUtils.getLinkedChildren()", function()
	it("resolves bound targets of matching ObjectValue links", function()
		local controller = setup()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		local binder = controller.newBinder()
		binder:Tag(target)

		local link = controller.newInstance(parent, "ObjectValue") :: ObjectValue
		link.Name = "Link"
		link.Value = target
		controller.boot()

		local objects = BinderUtils.getLinkedChildren(binder, "Link", parent)
		expect(#objects).toEqual(1)
		expect(objects[1]).toEqual(binder:Get(target))

		controller.destroy()
	end)

	it("ignores links whose name does not match", function()
		local controller = setup()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		local binder = controller.newBinder()
		binder:Tag(target)

		local link = controller.newInstance(parent, "ObjectValue") :: ObjectValue
		link.Name = "OtherLink"
		link.Value = target
		controller.boot()

		expect(#BinderUtils.getLinkedChildren(binder, "Link", parent)).toEqual(0)

		controller.destroy()
	end)

	it("deduplicates when two links point to the same bound target", function()
		local controller = setup()

		local parent = controller.newInstance()
		local target = controller.newInstance()
		local binder = controller.newBinder()
		binder:Tag(target)

		for _ = 1, 2 do
			local link = controller.newInstance(parent, "ObjectValue") :: ObjectValue
			link.Name = "Link"
			link.Value = target
		end
		controller.boot()

		expect(#BinderUtils.getLinkedChildren(binder, "Link", parent)).toEqual(1)

		controller.destroy()
	end)
end)
