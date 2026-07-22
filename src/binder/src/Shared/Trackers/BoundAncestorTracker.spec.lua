--!strict
--[[
	Coverage for BoundAncestorTracker, which exposes the bound class of a child's nearest bound
	ancestor.

	The binder is booted through a ServiceBag; the tracker is a plain BaseObject constructed
	directly. Instances live under a workspace container so ancestry and CollectionService signals
	fire. Ancestry changes and late binds are awaited event-driven via the tracker's Class.Changed
	signal rather than a fixed sleep.

	@class BoundAncestorTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local BoundAncestorTracker = require("BoundAncestorTracker")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function makeClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "BoundAncestorTrackerSpecClass"
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
	container.Name = "BoundAncestorTrackerSpecContainer"
	container.Parent = workspace

	local instances = {}
	local cleanups = {}
	local booted = false

	local binder = Binder.new(string.format("BoundAncestorTrackerSpecTag_%d", suffix), makeClass() :: any)

	local function newInstance(parent: Instance?): Instance
		local inst = Instance.new("Folder")
		inst.Parent = parent or container
		table.insert(instances, inst)
		return inst
	end

	local function track(item: any): any
		table.insert(cleanups, item)
		return item
	end

	local function boot()
		assert(not booted, "Already booted")
		booted = true

		local provider = BinderProvider.new(string.format("BoundAncestorTrackerSpecProvider_%d", suffix), function(self)
			self:Add(binder)
		end)
		serviceBag:GetService(provider)
		serviceBag:Init()
		serviceBag:Start()
	end

	local function awaitChange(tracker, previous)
		if tracker.Class.Value == previous then
			tracker.Class.Changed:Wait()
		end
		return tracker.Class.Value
	end

	return {
		container = container,
		binder = binder,
		newInstance = newInstance,
		track = track,
		boot = boot,
		awaitChange = awaitChange,
		destroy = function()
			for _, item in cleanups do
				pcall(function()
					item:Destroy()
				end)
			end
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

describe("BoundAncestorTracker tracking", function()
	it("exposes the nearest bound ancestor's class", function()
		local env = setup()

		local grandparent = env.newInstance()
		local parent = env.newInstance(grandparent)
		local child = env.newInstance(parent)
		env.binder:Tag(grandparent)
		env.boot()

		local tracker = env.track(BoundAncestorTracker.new(env.binder, child))
		expect(tracker.Class.Value).toEqual(env.binder:Get(grandparent))

		env.destroy()
	end)

	it("has no value when no ancestor is bound", function()
		local env = setup()

		local parent = env.newInstance()
		local child = env.newInstance(parent)
		env.boot()

		local tracker = env.track(BoundAncestorTracker.new(env.binder, child))
		expect(tracker.Class.Value).toBeNil()

		env.destroy()
	end)

	it("updates when an ancestor becomes bound", function()
		local env = setup()

		-- The tracker resolves ancestors above the child's direct parent, so bind the grandparent.
		local ancestor = env.newInstance()
		local parent = env.newInstance(ancestor)
		local child = env.newInstance(parent)
		env.boot()

		local tracker = env.track(BoundAncestorTracker.new(env.binder, child))
		expect(tracker.Class.Value).toBeNil()

		env.binder:Tag(ancestor)
		local value = env.awaitChange(tracker, nil)
		expect(value).toEqual(env.binder:Get(ancestor))

		env.destroy()
	end)

	it("clears the value when the child leaves the bound ancestry", function()
		local env = setup()

		local ancestor = env.newInstance()
		local parent = env.newInstance(ancestor)
		local child = env.newInstance(parent)
		env.binder:Tag(ancestor)
		env.boot()

		local tracker = env.track(BoundAncestorTracker.new(env.binder, child))
		local class = env.binder:Get(ancestor)
		expect(tracker.Class.Value).toEqual(class)

		child.Parent = env.container
		expect(env.awaitChange(tracker, class)).toBeNil()

		env.destroy()
	end)
end)
