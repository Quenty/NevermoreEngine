--!strict
--[[
	Coverage for BinderUtils lookup helpers.

	Binders are booted through a ServiceBag (as production code does) and instances are tagged
	BEFORE the service bag starts, so they bind synchronously and :Get() resolves without waiting.
	Instances live in a workspace container so the binders' added signals fire. Each test tears
	down its service bag and instances because the test place is shared across a batch run.

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

	-- Tags each instance with the binder, then boots everything through the service bag so the
	-- instances bind synchronously.
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
		local env = setup()

		local grandparent = env.newInstance()
		local parent = env.newInstance(grandparent)
		local child = env.newInstance(parent)

		local binder = env.newBinder()
		binder:Tag(grandparent)
		binder:Tag(child) -- child is bound too, but must be skipped
		env.boot()

		expect(BinderUtils.findFirstAncestor(binder, child)).toEqual(binder:Get(grandparent))

		env.destroy()
	end)

	it("returns nil when no ancestor is bound", function()
		local env = setup()

		local parent = env.newInstance()
		local child = env.newInstance(parent)
		local binder = env.newBinder()
		env.boot()

		expect(BinderUtils.findFirstAncestor(binder, child)).toBeNil()

		env.destroy()
	end)

	it("throws for a non-instance child", function()
		local env = setup()

		local binder = env.newBinder()
		env.boot()
		expect(function()
			BinderUtils.findFirstAncestor(binder, 5 :: any)
		end).toThrow()

		env.destroy()
	end)
end)

describe("BinderUtils.findFirstChild()", function()
	it("returns the first bound child", function()
		local env = setup()

		local parent = env.newInstance()
		local unboundChild = env.newInstance(parent)
		local boundChild = env.newInstance(parent)

		local binder = env.newBinder()
		binder:Tag(boundChild)
		env.boot()

		expect(BinderUtils.findFirstChild(binder, parent)).toEqual(binder:Get(boundChild))
		expect(binder:Get(unboundChild)).toBeNil()

		env.destroy()
	end)

	it("returns nil when no child is bound", function()
		local env = setup()

		local parent = env.newInstance()
		env.newInstance(parent)
		local binder = env.newBinder()
		env.boot()

		expect(BinderUtils.findFirstChild(binder, parent)).toBeNil()

		env.destroy()
	end)
end)

describe("BinderUtils.getChildren()", function()
	it("returns every bound child", function()
		local env = setup()

		local parent = env.newInstance()
		local childA = env.newInstance(parent)
		local childB = env.newInstance(parent)
		env.newInstance(parent) -- unbound

		local binder = env.newBinder()
		binder:Tag(childA)
		binder:Tag(childB)
		env.boot()

		expect(#BinderUtils.getChildren(binder, parent)).toEqual(2)

		env.destroy()
	end)

	it("does not include bound descendants deeper than one level", function()
		local env = setup()

		local parent = env.newInstance()
		local child = env.newInstance(parent)
		local grandchild = env.newInstance(child)

		local binder = env.newBinder()
		binder:Tag(grandchild)
		env.boot()

		expect(#BinderUtils.getChildren(binder, parent)).toEqual(0)

		env.destroy()
	end)
end)

describe("BinderUtils.getDescendants()", function()
	it("returns bound instances at any depth", function()
		local env = setup()

		local parent = env.newInstance()
		local child = env.newInstance(parent)
		local grandchild = env.newInstance(child)

		local binder = env.newBinder()
		binder:Tag(child)
		binder:Tag(grandchild)
		env.boot()

		expect(#BinderUtils.getDescendants(binder, parent)).toEqual(2)

		env.destroy()
	end)
end)

describe("BinderUtils.mapBinderListToTable()", function()
	it("keys binders by their tag", function()
		local env = setup()

		local binderA = env.newBinder()
		local binderB = env.newBinder()
		env.boot()

		local map = BinderUtils.mapBinderListToTable({ binderA, binderB })
		expect(map[binderA:GetTag()]).toEqual(binderA)
		expect(map[binderB:GetTag()]).toEqual(binderB)

		env.destroy()
	end)
end)

describe("BinderUtils.getMappedFromList()", function()
	it("resolves bound values across an instance list by tag", function()
		local env = setup()

		local instA = env.newInstance()
		local instB = env.newInstance()
		local binderA = env.newBinder()
		local binderB = env.newBinder()
		binderA:Tag(instA)
		binderB:Tag(instB)
		env.boot()

		local tagsMap = BinderUtils.mapBinderListToTable({ binderA, binderB })
		local objects = BinderUtils.getMappedFromList(tagsMap, { instA, instB, env.newInstance() })

		expect(#objects).toEqual(2)

		env.destroy()
	end)
end)

describe("BinderUtils.getChildrenOfBinders()", function()
	it("returns children bound by any binder in the list", function()
		local env = setup()

		local parent = env.newInstance()
		local childA = env.newInstance(parent)
		local childB = env.newInstance(parent)

		local binderA = env.newBinder()
		local binderB = env.newBinder()
		binderA:Tag(childA)
		binderB:Tag(childB)
		env.boot()

		expect(#BinderUtils.getChildrenOfBinders({ binderA, binderB }, parent)).toEqual(2)

		env.destroy()
	end)
end)

describe("BinderUtils.getLinkedChildren()", function()
	it("resolves bound targets of matching ObjectValue links", function()
		local env = setup()

		local parent = env.newInstance()
		local target = env.newInstance()
		local binder = env.newBinder()
		binder:Tag(target)

		local link = env.newInstance(parent, "ObjectValue") :: ObjectValue
		link.Name = "Link"
		link.Value = target
		env.boot()

		local objects = BinderUtils.getLinkedChildren(binder, "Link", parent)
		expect(#objects).toEqual(1)
		expect(objects[1]).toEqual(binder:Get(target))

		env.destroy()
	end)

	it("ignores links whose name does not match", function()
		local env = setup()

		local parent = env.newInstance()
		local target = env.newInstance()
		local binder = env.newBinder()
		binder:Tag(target)

		local link = env.newInstance(parent, "ObjectValue") :: ObjectValue
		link.Name = "OtherLink"
		link.Value = target
		env.boot()

		expect(#BinderUtils.getLinkedChildren(binder, "Link", parent)).toEqual(0)

		env.destroy()
	end)

	it("deduplicates when two links point to the same bound target", function()
		local env = setup()

		local parent = env.newInstance()
		local target = env.newInstance()
		local binder = env.newBinder()
		binder:Tag(target)

		for _ = 1, 2 do
			local link = env.newInstance(parent, "ObjectValue") :: ObjectValue
			link.Name = "Link"
			link.Value = target
		end
		env.boot()

		expect(#BinderUtils.getLinkedChildren(binder, "Link", parent)).toEqual(1)

		env.destroy()
	end)
end)
