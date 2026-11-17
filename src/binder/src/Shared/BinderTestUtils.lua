--!nonstrict
--[=[
	Helpers for specs that boot binders through a [ServiceBag] with tags unique to each spec.

	@class BinderTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local BinderTestUtils = {}

local specCounter = 0

--[=[
	Returns a bound class that records its instance and whether it was destroyed.

	@return TrackingClass
]=]
function BinderTestUtils.makeTrackingClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "TrackingClass"

	function Class.new(inst)
		local self = setmetatable({}, Class)
		self.instance = inst
		self.destroyed = false
		return self
	end

	function Class:Destroy()
		self.destroyed = true
	end

	return Class
end

--[=[
	Yields until the instance is no longer bound.

	@param binder Binder
	@param inst Instance
]=]
function BinderTestUtils.awaitUnbound(binder, inst)
	if binder:Get(inst) ~= nil then
		binder:GetClassRemovedSignal():Wait()
	end
end

--[=[
	A constructor that does nothing but return an empty table.

	@return table
]=]
function BinderTestUtils.noopConstructor()
	return {}
end

--[=[
	Builds a controller that adds binders, boots them through a [ServiceBag], and cleans up on `Destroy`.

	@return { ... }
]=]
function BinderTestUtils.setup()
	specCounter += 1
	local suffix = specCounter

	local maid = Maid.new()

	local serviceBag = ServiceBag.new()
	local serviceBagDestroyed = false

	local container = Instance.new("Folder")
	container.Name = "BinderSpecContainer"
	container.Parent = workspace

	local instances = {}
	local pendingBinders = {}
	local extraTagCounter = 0
	local booted = false

	local function uniqueTag()
		extraTagCounter += 1
		return string.format("BinderSpecTag_%d_%d", suffix, extraTagCounter)
	end

	local function addBinder(constructor, ...)
		assert(not booted, "Cannot add a binder after boot()")
		local binder = Binder.new(uniqueTag(), constructor, ...)
		table.insert(pendingBinders, binder)
		return binder
	end

	local function boot()
		assert(not booted, "Already booted")
		booted = true

		local binders = pendingBinders
		local provider = BinderProvider.new(string.format("BinderSpecProvider_%d", suffix), function(self)
			for _, binder in binders do
				self:Add(binder)
			end
		end)

		serviceBag:GetService(provider)
		serviceBag:Init()
		serviceBag:Start()
	end

	local function newInstance(parent, className)
		local inst = Instance.new(className or "Folder")
		inst.Parent = parent or container
		table.insert(instances, inst)
		return inst
	end

	local function destroyServiceBag()
		if not serviceBagDestroyed then
			serviceBagDestroyed = true
			serviceBag:Destroy()
		end
	end

	maid:GiveTask(function()
		destroyServiceBag()
		for _, inst in instances do
			pcall(function()
				inst:Destroy()
			end)
		end
		container:Destroy()
	end)

	local controller = {
		container = container,
		maid = maid,
		uniqueTag = uniqueTag,
		addBinder = addBinder,
		boot = boot,
		newInstance = newInstance,
		destroyServiceBag = destroyServiceBag,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

return BinderTestUtils
