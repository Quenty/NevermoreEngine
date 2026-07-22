--!strict
--[[
	@class BoundParentTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local BoundParentTracker = require("BoundParentTracker")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function makeClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "BoundParentTrackerSpecClass"
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
	container.Name = "BoundParentTrackerSpecContainer"
	container.Parent = workspace

	local instances = {}
	local cleanups = {}
	local booted = false

	local binder = Binder.new(string.format("BoundParentTrackerSpecTag_%d", suffix), makeClass() :: any)

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

		local provider = BinderProvider.new(string.format("BoundParentTrackerSpecProvider_%d", suffix), function(self)
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

describe("BoundParentTracker.new()", function()
	it("throws without a binder or child", function()
		expect(function()
			BoundParentTracker.new(nil :: any, Instance.new("Folder"))
		end).toThrow()
	end)
end)

describe("BoundParentTracker tracking", function()
	it("exposes the bound class of the direct parent", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		controller.binder:Tag(parent)
		controller.boot()

		local tracker = controller.track(BoundParentTracker.new(controller.binder, child))
		expect(tracker.Class.Value).toEqual(controller.binder:Get(parent))

		controller.destroy()
	end)

	it("clears the value when the child is reparented off the bound parent", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		controller.binder:Tag(parent)
		controller.boot()

		local tracker = controller.track(BoundParentTracker.new(controller.binder, child))
		local class = controller.binder:Get(parent)
		expect(tracker.Class.Value).toEqual(class)

		child.Parent = controller.container
		expect(controller.awaitChange(tracker, class)).toBeNil()

		controller.destroy()
	end)

	it("clears the value when the parent's class is unbound", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		controller.binder:Tag(parent)
		controller.boot()

		local tracker = controller.track(BoundParentTracker.new(controller.binder, child))
		local class = controller.binder:Get(parent)
		expect(tracker.Class.Value).toEqual(class)

		controller.binder:Untag(parent)
		expect(controller.awaitChange(tracker, class)).toBeNil()

		controller.destroy()
	end)
end)
