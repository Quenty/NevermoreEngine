--!strict
--[=[
	Bind class to Roblox Instance

	```lua
	-- Setup a class!
	local MyClass = {}
	MyClass.__index = MyClass

	function MyClass.new(robloxInstance)
		print("New tagged instance of ", robloxInstance)
		return setmetatable({}, MyClass)
	end

	function MyClass:Destroy()
		print("Cleaning up")
		setmetatable(self, nil)
	end

	-- bind to every instance with tag of "TagName"!
	local binder = Binder.new("TagName", MyClass)
	binder:Start() -- listens for new instances and connects events
	```

	@class Binder
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Brio = require("Brio")
local Maid = require("Maid")
local MaidTaskUtils = require("MaidTaskUtils")
local Observable = require("Observable")
local Promise = require("Promise")
local Signal = require("Signal")
local _CancelToken = require("CancelToken")

local Binder = {}
Binder.__index = Binder
Binder.ClassName = "Binder"

export type ConstructorCallback<T> = (Instance) -> T

export type ClassDefinition<T> = {
	new: ConstructorCallback<T>,
}

export type ProviderDefition<T> = {
	Create: ConstructorCallback<T>,
}

export type BinderConstructor<T> = ClassDefinition<T> | ProviderDefition<T> | ConstructorCallback<T>

export type Binder<T> = typeof(setmetatable(
	{} :: {
		ServiceName: string,

		_tagName: string,
		_defaultClassType: string,
		_args: { any },
		_constructor: BinderConstructor<T>,

		_started: boolean,
		_initialized: boolean,
		_pendingInstSet: { [Instance]: true },
		_instToClass: { [Instance]: T },
		_allClassSet: { [T]: true },
		_maid: Maid.Maid,
		_listeners: { [Instance]: { [any]: true } },
		_classAddedSignal: Signal.Signal<T, Instance>?,
		_classRemovingSignal: Signal.Signal<T, Instance>?,
		_classRemovedSignal: Signal.Signal<T, Instance>?,
	},
	{} :: typeof({ __index = Binder })
))

--[=[
	Constructor for a binder
	@type BinderContructor (Instance, ...: any) -> T | { new: (Instance, ...: any) } | { Create(self, Instance, ...: any) }
	@within Binder
]=]

--[=[
	Constructs a new binder object.

	```lua
	local binder = Binder.new("Bird", function(inst)
		print("Wow, a new bird!", inst)

		return {
			Destroy = function()
				print("Uh oh, the bird is gone!")
			end;
		}
	end)
	binder:Start()
	```
	@param tagName string -- Name of the tag to bind to. This uses CollectionService's tag system
	@param constructor BinderContructor
	@param ... any -- Variable arguments that will be passed into the constructor
	@return Binder<T>
]=]
function Binder.new<T>(tagName: string, constructor: BinderConstructor<T>, ...): Binder<T>
	assert(type(tagName) == "string", "Bad tagName")

	local self: Binder<T> = setmetatable({} :: any, Binder)

	self._tagName = assert(tagName, "Bad argument 'tagName', expected string")
	self._constructor = assert(constructor, "Bad argument 'constructor', expected table or function")
	self._defaultClassType = "Folder"
	self.ServiceName = self._tagName .. "Binder"

	if Binder.isBinder(self._constructor) then
		error("Cannot make a binder that constructs another binder")
	end

	if select("#", ...) > 0 then
		self._args = { ... }
	end

	return self
end

--[=[
	Retrieves whether or not the given value is a binder.

	@param value any
	@return boolean true or false, whether or not it is a value
]=]
function Binder.isBinder(value: any): boolean
	return type(value) == "table"
		and type(value.Start) == "function"
		and type(value.GetTag) == "function"
		and type(value.GetConstructor) == "function"
		and type(value.ObserveInstance) == "function"
		and type(value.GetClassAddedSignal) == "function"
		and type(value.GetClassRemovingSignal) == "function"
		and type(value.GetClassRemovedSignal) == "function"
		and type(value.GetAll) == "function"
		and type(value.GetAllSet) == "function"
		and type(value.Bind) == "function"
		and type(value.Unbind) == "function"
		and type(value.BindClient) == "function"
		and type(value.UnbindClient) == "function"
		and type(value.Get) == "function"
		and type(value.Promise) == "function"
		and type(value.Destroy) == "function"
end

--[=[
	Initializes the Binder. Designed to be done via ServiceBag.

	@param ... any
]=]
function Binder:Init(...)
	if self._initialized then
		return
	end

	self._initialized = true
	self._maid = Maid.new()

	self._instToClass = {} -- [inst] = class
	self._allClassSet = {} -- [class] = true
	self._pendingInstSet = {} -- [inst] = true

	self._listeners = {} -- [inst] = callback

	if select("#", ...) > 0 then
		if not self._args then
			self._args = { ... }
		elseif not self:_argsMatch(...) then
			warn("[Binder.Init] - Non-matching args from :Init() and .new()")
		end
	elseif not self._args then
		-- Binder.new() would have captured args if we had them
		self._args = {}
	end

	self._maid._warning = task.delay(5, function()
		warn(string.format("Binder %q is not loaded. Call :Start() on it!", self._tagName))
	end)
end

function Binder:_argsMatch(...)
	if #self._args ~= select("#", ...) then
		return false
	end

	for index, value in { ... } do
		if self._args[index] ~= value then
			return false
		end
	end

	return true
end

--[=[
	Listens for new instances and connects to the GetInstanceAddedSignal() and removed signal!
]=]
function Binder.Start<T>(self: Binder<T>)
	if not self._initialized then
		self:Init()
	end

	if self._started then
		return
	end
	self._maid._warning = nil
	self._started = true

	for _, inst in CollectionService:GetTagged(self._tagName) do
		task.spawn(self._add, self, inst)
	end

	self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(self._tagName):Connect(function(inst)
		self:_add(inst)
	end))
	self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(self._tagName):Connect(function(inst)
		self:_remove(inst)
	end))
end

--[=[
	Returns the tag name that the binder has.
	@return string
]=]
function Binder.GetTag<T>(self: Binder<T>): string
	return self._tagName
end

--[=[
	Returns whatever was set for the construtor. Used for meta-analysis of
	the binder, such as extracting if parameters are allowed.

	@return BinderContructor
]=]
function Binder.GetConstructor<T>(self: Binder<T>): BinderConstructor<T>
	return self._constructor
end

--[=[
	Observes the current value of the instance

	@param instance Instance
	@return Observable<T?>
]=]
function Binder:Observe(instance: Instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(self:ObserveInstance(instance, function(...)
			sub:Fire(...)
		end))
		sub:Fire(self:Get(instance))

		return maid
	end)
end

--[=[
	Observes all entries in the binder

	@return Observable<Brio<T>>
]=]
function Binder.ObserveAllBrio<T>(self: Binder<T>): Observable.Observable<Brio.Brio<T>>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleNewClass(class: T)
			local brio = Brio.new(class)
			maid[class :: any] = brio

			sub:Fire(brio)
		end

		maid:GiveTask(self:GetClassAddedSignal():Connect(handleNewClass))

		for _, item in self:GetAll() do
			if not sub:IsPending() then
				break
			end

			handleNewClass(item)
		end

		if sub:IsPending() then
			maid:GiveTask(self:GetClassRemovingSignal():Connect(function(class)
				maid[class :: any] = nil
			end))
		end

		return maid
	end) :: any
end

--[=[
	Observes a bound class on a given instance.

	@param instance Instance
	@return Observable<Brio<T>>
]=]
function Binder.ObserveBrio<T>(self: Binder<T>, instance: Instance): Observable.Observable<Brio.Brio<T>>
	assert(typeof(instance) == "Instance", "Bad instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleClassChanged(class)
			if class then
				local brio = Brio.new(class)
				maid._lastBrio = brio

				sub:Fire(brio)
			else
				maid._lastBrio = nil
			end
		end

		maid:GiveTask(self:ObserveInstance(instance, handleClassChanged))
		handleClassChanged(self:Get(instance))

		return maid
	end) :: any
end

--[=[
	Fired when added, and then after removal, but before destroy!

	:::info
	This is before [Rx] so it doesn't follow the same Rx pattern. See [Binder.Observe] for
	an [Rx] compatible interface.
	:::

	@param inst Instance
	@param callback function
	@return function -- Cleanup function
]=]
function Binder.ObserveInstance<T>(self: Binder<T>, inst: Instance, callback: (T?) -> ()): () -> ()
	assert(typeof(inst) == "Instance", "Bad inst")
	assert(type(callback) == "function", "Bad callback")

	self._listeners[inst] = self._listeners[inst] or {}
	self._listeners[inst][callback] = true

	return function()
		if not self._listeners[inst] then
			return
		end

		self._listeners[inst][callback] = nil
		if not next(self._listeners[inst]) then
			self._listeners[inst] = nil
		end
	end
end

--[=[
	Returns a new signal that will fire whenever a class is bound to the binder

	```lua
	local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

	birdBinder:GetClassAddedSignal():Connect(function(bird)
		bird:Squack() -- Make the bird squack when it's first spawned
	end)

	-- Load all birds
	birdBinder:Start()
	```

	@return Signal<T>
]=]
function Binder.GetClassAddedSignal<T>(self: Binder<T>): Signal.Signal<T, Instance>
	if self._classAddedSignal then
		return self._classAddedSignal
	end

	self._classAddedSignal = self._maid:Add(Signal.new() :: any) -- :fire(class, inst)

	return self._classAddedSignal :: any
end

--[=[
	Returns a new signal that will fire whenever a class is removing from the binder.

	@return Signal<T>
	]=]
function Binder.GetClassRemovingSignal<T>(self: Binder<T>): Signal.Signal<T, Instance>
	if self._classRemovingSignal then
		return self._classRemovingSignal
	end

	self._classRemovingSignal = self._maid:Add(Signal.new() :: any) -- :fire(class, inst)

	return self._classRemovingSignal :: any
end

--[=[
	Returns a new signal that will fire whenever a class is removed from the binder.

	@return Signal<T>
]=]
function Binder.GetClassRemovedSignal<T>(self: Binder<T>): Signal.Signal<T, Instance>
	if self._classRemovedSignal then
		return self._classRemovedSignal
	end

	self._classRemovedSignal = self._maid:Add(Signal.new() :: any) -- :fire(class, inst)

	return self._classRemovedSignal :: any
end

--[=[
	Returns all of the classes in a new table.

	```lua
	local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

	-- Update every bird every frame
	RunService.Stepped:Connect(function()
		for _, bird in birdBinder:GetAll() do
			bird:Update()
		end
	end)

	birdBinder:Start()
	```

	@return {T}
]=]
function Binder.GetAll<T>(self: Binder<T>): { T }
	local all = {}
	for class, _ in self._allClassSet do
		all[#all + 1] = class
	end
	return all
end

--[=[
	Faster method to get all items in a binder

	```lua
	local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

	-- Update every bird every frame
	RunService.Stepped:Connect(function()
		for bird, _ in pairs(birdBinder:GetAllSet()) do
			bird:Update()
		end
	end)

	birdBinder:Start()
	```

	:::warning
	Do not mutate this set directly
	:::

	@return { [T]: true }
]=]
function Binder.GetAllSet<T>(self: Binder<T>): { [T]: true }
	return self._allClassSet
end

--[=[
	Binds an instance to this binder using collection service and attempts
	to return it if it's bound properly. See BinderUtils.promiseBoundClass() for a safe
	way to retrieve it.

	:::warning
	Do not assume that a bound object will be retrieved
	:::

	@server
	@param inst Instance -- Instance to check
	@return T? -- Bound class
]=]
function Binder.Bind<T>(self: Binder<T>, inst: Instance): T?
	if RunService:IsClient() then
		warn(
			string.format(
				"[Binder.Bind] - Bindings '%s' done on the client! Will be disrupted upon server replication! %s",
				self._tagName,
				debug.traceback()
			)
		)
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

--[=[
	Tags the instance with the tag for the binder

	@param inst Instance
]=]
function Binder.Tag<T>(self: Binder<T>, inst: Instance)
	assert(typeof(inst) == "Instance", "Bad inst")

	CollectionService:AddTag(inst, self._tagName)
end

--[=[
	Returns true if the instance has a tag

	@param inst Instance
]=]
function Binder.HasTag<T>(self: Binder<T>, inst: Instance): boolean
	assert(typeof(inst) == "Instance", "Bad inst")

	return CollectionService:HasTag(inst, self._tagName)
end

--[=[
	Untags the instance with the tag for the binder

	@param inst Instance
]=]
function Binder.Untag<T>(self: Binder<T>, inst: Instance)
	assert(typeof(inst) == "Instance", "Bad inst")

	CollectionService:RemoveTag(inst, self._tagName)
end

--[=[
	Unbinds the instance by removing the tag.

	@server
	@param inst Instance -- Instance to unbind
]=]
function Binder.Unbind<T>(self: Binder<T>, inst: Instance)
	assert(typeof(inst) == "Instance", "Bad inst'")

	if RunService:IsClient() then
		warn(
			string.format(
				"[Binder.Bind] - Unbinding '%s' done on the client! Might be disrupted upon server replication! %s",
				self._tagName,
				debug.traceback()
			)
		)
	end

	CollectionService:RemoveTag(inst, self._tagName)
end

--[=[
 See :Bind(). Acknowledges the risk of doing this on the client.

 Using this acknowledges that we're intentionally binding on a safe client object,
 i.e. one without replication. If another tag is changed on this instance, this tag will be lost/changed.

 @client
 @param inst Instance -- Instance to bind
 @return T? -- Bound class (potentially)
]=]
function Binder.BindClient<T>(self: Binder<T>, inst: Instance)
	if not RunService:IsClient() then
		warn(
			string.format("[Binder.BindClient] - Bindings '%s' done on the server! Will be replicated!", self._tagName)
		)
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

--[=[
	See Unbind(), acknowledges risk of doing this on the client.

	@client
	@param inst Instance -- Instance to unbind
]=]
function Binder.UnbindClient<T>(self: Binder<T>, inst: Instance)
	assert(typeof(inst) == "Instance", "Bad inst")
	CollectionService:RemoveTag(inst, self._tagName)
end

--[=[
	Returns a instance of the class that is bound to the instance given.

	@param inst Instance -- Instance to check
	@return T?
]=]
function Binder.Get<T>(self: Binder<T>, inst: Instance): T?
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")
	return self._instToClass[inst]
end

--[=[
	Returns a promise which will resolve when the instance is bound.

	@param inst Instance -- Instance to check
	@param cancelToken CancelToken?
	@return Promise<T>
]=]
function Binder.Promise<T>(self: Binder<T>, inst: Instance, cancelToken: _CancelToken.CancelToken?): Promise.Promise<T>
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")

	local class = self:Get(inst)
	if class then
		return Promise.resolved(class)
	end

	local maid = Maid.new()
	local promise = Promise.new()

	if cancelToken then
		cancelToken:ErrorIfCancelled()
		maid:GivePromise(cancelToken.PromiseCancelled):Then(function()
			promise:Reject()
		end)
	end

	maid:GiveTask(self:ObserveInstance(inst, function(classAdded)
		if classAdded then
			promise:Resolve(classAdded)
		end
	end))

	task.delay(5, function()
		if promise:IsPending() then
			warn(
				string.format(
					"[promiseBoundClass] - Infinite yield possible on %q for binder %q\n",
					inst:GetFullName(),
					self:GetTag()
				)
			)
		end
	end)

	promise:Finally(function()
		maid:Destroy()
	end)

	return promise
end

--[=[
	Creates a new class tagged with this binder's instance

	@param className string?
	@return Instance
]=]
function Binder.Create<T>(self: Binder<T>, className: string): Instance
	assert(type(className) == "string" or className == nil, "Bad className")

	local instance = Instance.new(className or self._defaultClassType)
	instance.Name = self._tagName
	instance.Archivable = false

	self:Tag(instance)

	return instance
end

function Binder._add<T>(self: Binder<T>, inst: Instance)
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")

	if self._instToClass[inst] then
		-- https://devforum.roblox.com/t/double-firing-of-collectionservice-getinstanceaddedsignal-when-applying-tag/244235
		return
	end

	if self._pendingInstSet[inst] == true then
		warn("[Binder._add] - Reentered add. Still loading, probably caused by error in constructor.")
		return
	end

	self._pendingInstSet[inst] = true

	local constructor: any = self._constructor
	local class: T
	if type(constructor) == "function" then
		class = constructor(inst, unpack(self._args))
	elseif constructor.Create then
		class = constructor:Create(inst, unpack(self._args))
	else
		class = constructor.new(inst, unpack(self._args))
	end

	if self._pendingInstSet[inst] ~= true then
		-- Got GCed in the process of loading?!
		-- Constructor probably yields. Yikes.
		warn(
			string.format(
				"[Binder._add] - Failed to load instance %q of %q, removed while loading!",
				inst:GetFullName(),
				tostring(type(constructor) == "table" and constructor.ClassName or constructor)
			)
		)
		return
	end

	self._pendingInstSet[inst] = nil
	assert(self._instToClass[inst] == nil, "Overwrote")

	class = class or {} :: any

	-- Add to state
	self._allClassSet[class] = true
	self._instToClass[inst] = class

	-- Fire events
	local listeners = self._listeners[inst]
	if listeners then
		for callback, _ in listeners do
			task.spawn(callback, class)
		end
	end

	if self._classAddedSignal then
		self._classAddedSignal:Fire(class, inst)
	end
end

function Binder._remove<T>(self: Binder<T>, inst: Instance)
	self._pendingInstSet[inst] = nil

	local class = self._instToClass[inst]
	if class == nil then
		return
	end

	-- Fire off events
	if self._classRemovingSignal then
		self._classRemovingSignal:Fire(class, inst)
	end

	-- Clean up state
	self._instToClass[inst] = nil
	self._allClassSet[class] = nil

	-- Fire listener here
	local listeners = self._listeners[inst]
	if listeners then
		for callback, _ in listeners do
			task.spawn(callback, nil)
		end
	end

	if MaidTaskUtils.isValidTask(class) then
		MaidTaskUtils.doTask(class)
	end

	-- Fire off events
	if self._classRemovedSignal then
		self._classRemovedSignal:Fire(class, inst)
	end
end

--[=[
	Cleans up all bound classes, and disconnects all events.
]=]
function Binder.Destroy<T>(self: Binder<T>)
	local inst, class = next(self._instToClass)
	while class ~= nil and inst ~= nil do
		task.spawn(self._remove, self, inst)
		inst, class = next(self._instToClass)
	end

	-- Disconnect events
	self._maid:DoCleaning()
end

return Binder
