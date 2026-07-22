--!strict
--[[
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
		local controller = setup()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		controller.binder:Tag(grandparent)
		controller.boot()

		local tracker = controller.track(BoundAncestorTracker.new(controller.binder, child))
		expect(tracker.Class.Value).toEqual(controller.binder:Get(grandparent))

		controller.destroy()
	end)

	it("has no value when no ancestor is bound", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		controller.boot()

		local tracker = controller.track(BoundAncestorTracker.new(controller.binder, child))
		expect(tracker.Class.Value).toBeNil()

		controller.destroy()
	end)

	it("updates when an ancestor becomes bound", function()
		local controller = setup()

		-- The tracker resolves ancestors above the child's direct parent, so bind the grandparent.
		local ancestor = controller.newInstance()
		local parent = controller.newInstance(ancestor)
		local child = controller.newInstance(parent)
		controller.boot()

		local tracker = controller.track(BoundAncestorTracker.new(controller.binder, child))
		expect(tracker.Class.Value).toBeNil()

		controller.binder:Tag(ancestor)
		local value = controller.awaitChange(tracker, nil)
		expect(value).toEqual(controller.binder:Get(ancestor))

		controller.destroy()
	end)

	it("clears the value when the child leaves the bound ancestry", function()
		local controller = setup()

		local ancestor = controller.newInstance()
		local parent = controller.newInstance(ancestor)
		local child = controller.newInstance(parent)
		controller.binder:Tag(ancestor)
		controller.boot()

		local tracker = controller.track(BoundAncestorTracker.new(controller.binder, child))
		local class = controller.binder:Get(ancestor)
		expect(tracker.Class.Value).toEqual(class)

		child.Parent = controller.container
		expect(controller.awaitChange(tracker, class)).toBeNil()

		controller.destroy()
	end)
end)
