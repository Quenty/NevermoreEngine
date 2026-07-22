--!nonstrict
--[=[
	Shared harness for the Binder specs. [BinderTestUtils.setup] boots binders the way production code
	boots them: registered on a [BinderProvider] that is Init/Start'd through a [ServiceBag] and torn
	down through `serviceBag:Destroy()`. Adornees are parented into a workspace container because
	CollectionService.GetInstanceAddedSignal only fires for instances that live in the DataModel.

	Tags are global and the test place is shared across a batch run, so every binder gets a distinct
	tag from a single module-level counter -- shared across every spec file that requires this module,
	so tags never collide between files -- and each controller cleans up after itself via `destroy()`.

	@class BinderTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local ServiceBag = require("ServiceBag")

local BinderTestUtils = {}

local specCounter = 0

--[=[
	A minimal bound class that records its instance and whether it was destroyed. It deliberately does
	NOT retain its constructor varargs: the ServiceBag is injected as a constructor arg, and its object
	graph contains Quenty Signals whose strict __index makes jest's deep-equality traversal throw.
	Keeping the class free of them lets toEqual compare instances safely.

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
	Returns once `inst` is no longer bound. CollectionService tag removal is synchronous here, so the
	class is usually already gone by the time we check; the guarded wait also covers a deferred case.

	@param binder Binder
	@param inst Instance
]=]
function BinderTestUtils.awaitUnbound(binder, inst)
	if binder:Get(inst) ~= nil then
		binder:GetClassRemovedSignal():Wait()
	end
end

--[=[
	A no-op constructor that still returns a value, so Binder's generic bound type stays inhabited.

	@return table
]=]
function BinderTestUtils.noopConstructor()
	return {}
end

--[=[
	Builds the controller the Binder specs share. Register binders with `addBinder`, boot them all at
	once through a ServiceBag with `boot`, create adornees with `newInstance`, and tear everything down
	with `destroy` (or just the service bag with `destroyServiceBag`).

	Fields: `container`.
	Builders: `addBinder(constructor, ...)` -> Binder, `newInstance(parent?, className?)` -> Instance.
	Lifecycle: `boot()`, `destroyServiceBag()`, `destroy()`.
	Helpers: `uniqueTag()` -> string.

	@return { ... }
]=]
function BinderTestUtils.setup()
	specCounter += 1
	local suffix = specCounter

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

	return {
		container = container,
		uniqueTag = uniqueTag,
		addBinder = addBinder,
		boot = boot,
		newInstance = newInstance,
		destroyServiceBag = destroyServiceBag,
		destroy = function()
			destroyServiceBag()
			for _, inst in instances do
				pcall(function()
					inst:Destroy()
				end)
			end
			container:Destroy()
		end,
	}
end

return BinderTestUtils
