--!nonstrict
--[=[
	Helpers for specs that register binders in a [ServiceBag] with tags unique to each spec.

	@class BinderTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Binder = require("Binder")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local BinderTestUtils = {}

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
	A constructor that does nothing but return an empty table.

	@return table
]=]
function BinderTestUtils.noopConstructor()
	return {}
end

--[=[
	Builds a controller that adds binders, initializes them through a [ServiceBag], and cleans up on `Destroy`.

	@return { ... }
]=]
function BinderTestUtils.setup()
	local maid = Maid.new()

	local serviceBag = ServiceBag.new()
	maid._serviceBag = serviceBag

	local container = Instance.new("Folder")
	container.Name = "BinderSpecContainer"
	container.Parent = workspace

	local instances = {}

	local function uniqueTag()
		return "BinderSpecTag_" .. HttpService:GenerateGUID(false)
	end

	local function addBinder(constructor, ...)
		return serviceBag:GetService(Binder.new(uniqueTag(), constructor, ...))
	end

	local function initServiceBag()
		serviceBag:Init()
		serviceBag:Start()
	end

	local function newInstance(parent, className)
		local inst = Instance.new(className or "Folder")
		inst.Parent = parent or container
		table.insert(instances, inst)
		return inst
	end

	local function bind(binder, inst: Instance): any
		binder:Tag(inst)
		return assert(binder:Get(inst), "Tagging did not bind the instance")
	end

	local function unbind(binder, inst: Instance)
		binder:Untag(inst)
		assert(binder:Get(inst) == nil, "Untagging did not unbind the instance")
	end

	local function destroyServiceBag()
		maid._serviceBag = nil
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
		initServiceBag = initServiceBag,
		newInstance = newInstance,
		bind = bind,
		unbind = unbind,
		destroyServiceBag = destroyServiceBag,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

return BinderTestUtils
