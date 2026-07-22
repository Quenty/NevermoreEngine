--!strict
--[[
	@class BoundChildCollection.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local BoundChildCollection = require("BoundChildCollection")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function makeClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "BoundChildCollectionSpecClass"
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
	container.Name = "BoundChildCollectionSpecContainer"
	container.Parent = workspace

	local instances = {}
	local cleanups = {}
	local booted = false

	local binder = Binder.new(string.format("BoundChildCollectionSpecTag_%d", suffix), makeClass() :: any)

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

		local provider = BinderProvider.new(string.format("BoundChildCollectionSpecProvider_%d", suffix), function(self)
			self:Add(binder)
		end)
		serviceBag:GetService(provider)
		serviceBag:Init()
		serviceBag:Start()
	end

	return {
		container = container,
		binder = binder,
		newInstance = newInstance,
		track = track,
		boot = boot,
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

describe("BoundChildCollection construction", function()
	it("counts children bound before construction without firing ClassAdded", function()
		local controller = setup()

		local parent = controller.newInstance()
		local childA = controller.newInstance(parent)
		local childB = controller.newInstance(parent)
		controller.newInstance(parent) -- unbound child

		controller.binder:Tag(childA)
		controller.binder:Tag(childB)
		controller.boot()

		local fired = 0
		local collection = controller.track(BoundChildCollection.new(controller.binder, parent))
		collection.ClassAdded:Connect(function()
			fired += 1
		end)

		expect(collection:GetSize()).toEqual(2)
		expect(fired).toEqual(0)
		expect(#collection:GetClasses()).toEqual(2)
		expect(collection:HasClass(controller.binder:Get(childA))).toEqual(true)

		controller.destroy()
	end)
end)

describe("BoundChildCollection dynamic updates", function()
	it("fires ClassAdded when a bound child is reparented in", function()
		local controller = setup()

		local parent = controller.newInstance()
		controller.boot()

		local collection = controller.track(BoundChildCollection.new(controller.binder, parent))

		local child = controller.newInstance()
		controller.binder:Tag(child)
		local ok, class = controller.binder:Promise(child):Yield()
		assert(ok, "child never bound")

		local addedClass
		local conn = collection.ClassAdded:Connect(function(c)
			addedClass = c
		end)

		child.Parent = parent
		if collection:GetSize() == 0 then
			collection.ClassAdded:Wait()
		end
		conn:Disconnect()

		expect(addedClass).toEqual(class)
		expect(collection:GetSize()).toEqual(1)

		controller.destroy()
	end)

	it("fires ClassRemoved when a tracked child is reparented out", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		controller.binder:Tag(child)
		controller.boot()

		local collection = controller.track(BoundChildCollection.new(controller.binder, parent))
		expect(collection:GetSize()).toEqual(1)

		local removedClass
		local conn = collection.ClassRemoved:Connect(function(c)
			removedClass = c
		end)

		local class = controller.binder:Get(child)
		child.Parent = controller.container
		if collection:GetSize() == 1 then
			collection.ClassRemoved:Wait()
		end
		conn:Disconnect()

		expect(removedClass).toEqual(class)
		expect(collection:GetSize()).toEqual(0)

		controller.destroy()
	end)

	it("fires ClassRemoved when a tracked child is unbound", function()
		local controller = setup()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		controller.binder:Tag(child)
		controller.boot()

		local collection = controller.track(BoundChildCollection.new(controller.binder, parent))
		expect(collection:GetSize()).toEqual(1)

		local conn = collection.ClassRemoved:Connect(function() end)
		controller.binder:Untag(child)
		if collection:GetSize() == 1 then
			collection.ClassRemoved:Wait()
		end
		conn:Disconnect()

		expect(collection:GetSize()).toEqual(0)

		controller.destroy()
	end)
end)
