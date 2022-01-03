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

local Maid = require("Maid")
local MaidTaskUtils = require("MaidTaskUtils")
local Signal = require("Signal")
local promiseBoundClass = require("promiseBoundClass")

local Binder = {}
Binder.__index = Binder
Binder.ClassName = "Binder"

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
function Binder.new(tagName, constructor, ...)
	local self = setmetatable({}, Binder)

	self._maid = Maid.new()
	self._tagName = tagName or error("Bad argument 'tagName', expected string")
	self._constructor = constructor or error("Bad argument 'constructor', expected table or function")

	self._instToClass = {} -- [inst] = class
	self._allClassSet = {} -- [class] = true
	self._pendingInstSet = {} -- [inst] = true

	self._listeners = {} -- [inst] = callback
	self._args = {...}

	task.delay(5, function()
		if not self._loaded then
			warn(("Binder %q is not loaded. Call :Start() on it!"):format(self._tagName))
		end
	end)

	return self
end

--[=[
	Retrieves whether or not the given value is a binder.

	@param value any
	@return boolean true or false, whether or not it is a value
]=]
function Binder.isBinder(value)
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
	Listens for new instances and connects to the GetInstanceAddedSignal() and removed signal!
]=]
function Binder:Start()
	if self._loaded then
		return
	end
	self._loaded = true

	for _, inst in pairs(CollectionService:GetTagged(self._tagName)) do
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
function Binder:GetTag()
	return self._tagName
end

--[=[
	Returns whatever was set for the construtor. Used for meta-analysis of
	the binder, such as extracting if parameters are allowed.

	@return BinderContructor
]=]
function Binder:GetConstructor()
	return self._constructor
end

--[=[
	Fired when added, and then after removal, but before destroy!

	@param inst Instance
	@param callback function
	@return function -- Cleanup function
]=]
function Binder:ObserveInstance(inst, callback)
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
function Binder:GetClassAddedSignal()
	if self._classAddedSignal then
		return self._classAddedSignal
	end

	self._classAddedSignal = Signal.new() -- :fire(class, inst)
	self._maid:GiveTask(self._classAddedSignal)
	return self._classAddedSignal
end

--[=[
	Returns a new signal that will fire whenever a class is removing from the binder.

	@return Signal<T>
	]=]
function Binder:GetClassRemovingSignal()
	if self._classRemovingSignal then
		return self._classRemovingSignal
	end

	self._classRemovingSignal = Signal.new() -- :fire(class, inst)
	self._maid:GiveTask(self._classRemovingSignal)

	return self._classRemovingSignal
end

--[=[
	Returns a new signal that will fire whenever a class is removed from the binder.

	@return Signal<T>
]=]
function Binder:GetClassRemovedSignal()
	if self._classRemovedSignal then
		return self._classRemovedSignal
	end

	self._classRemovedSignal = Signal.new() -- :fire(class, inst)
	self._maid:GiveTask(self._classRemovedSignal)

	return self._classRemovedSignal
end

--[=[
	Returns all of the classes in a new table.

	```lua
	local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

	-- Update every bird every frame
	RunService.Stepped:Connect(function()
		for _, bird in pairs(birdBinder:GetAll()) do
			bird:Update()
		end
	end)

	birdBinder:Start()
	```

	@return {T}
]=]
function Binder:GetAll()
	local all = {}
	for class, _ in pairs(self._allClassSet) do
		all[#all+1] = class
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

	@return { [T]: boolean }
]=]
function Binder:GetAllSet()
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
function Binder:Bind(inst)
	if RunService:IsClient() then
		warn(("[Binder.Bind] - Bindings '%s' done on the client! Will be disrupted upon server replication! %s")
			:format(self._tagName, debug.traceback()))
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

--[=[
	Unbinds the instance by removing the tag.

	@server
	@param inst Instance -- Instance to unbind
]=]
function Binder:Unbind(inst)
	assert(typeof(inst) == "Instance", "Bad inst'")

	if RunService:IsClient() then
		warn(("[Binder.Bind] - Unbinding '%s' done on the client! Might be disrupted upon server replication! %s")
			:format(self._tagName, debug.traceback()))
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
function Binder:BindClient(inst)
	if not RunService:IsClient() then
		warn(("[Binder.BindClient] - Bindings '%s' done on the server! Will be replicated!")
			:format(self._tagName))
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

--[=[
	See Unbind(), acknowledges risk of doing this on the client.

	@client
	@param inst Instance -- Instance to unbind
]=]
function Binder:UnbindClient(inst)
	assert(typeof(inst) == "Instance", "Bad inst")
	CollectionService:RemoveTag(inst, self._tagName)
end

--[=[
	Returns a instance of the class that is bound to the instance given.

	@param inst Instance -- Instance to check
	@return T?
]=]
function Binder:Get(inst)
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")
	return self._instToClass[inst]
end

--[=[
	Returns a promise which will resolve when the instance is bound.

	@param inst Instance -- Instance to check
	@param cancelToken? CancelToken
	@return Promise<T>
]=]
function Binder:Promise(inst, cancelToken)
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")
	return promiseBoundClass(self, inst, cancelToken)
end

function Binder:_add(inst)
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

	local class
	if type(self._constructor) == "function" then
		class = self._constructor(inst, unpack(self._args))
	elseif self._constructor.Create then
		class = self._constructor:Create(inst, unpack(self._args))
	else
		class = self._constructor.new(inst, unpack(self._args))
	end

	if self._pendingInstSet[inst] ~= true then
		-- Got GCed in the process of loading?!
		-- Constructor probably yields. Yikes.
		warn(("[Binder._add] - Failed to load instance %q of %q, removed while loading!")
			:format(
				inst:GetFullName(),
				tostring(type(self._constructor) == "table" and self._constructor.ClassName or self._constructor)))
		return
	end

	self._pendingInstSet[inst] = nil
	assert(self._instToClass[inst] == nil, "Overwrote")

	class = class or {}

	-- Add to state
	self._allClassSet[class] = true
	self._instToClass[inst] = class

	-- Fire events
	local listeners = self._listeners[inst]
	if listeners then
		for callback, _ in pairs(listeners) do
			task.spawn(callback, class)
		end
	end

	if self._classAddedSignal then
		self._classAddedSignal:Fire(class, inst)
	end
end

function Binder:_remove(inst)
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
		for callback, _ in pairs(listeners) do
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
function Binder:Destroy()
	local inst, class = next(self._instToClass)
	while class ~= nil do
		self:_remove(inst)
		assert(self._instToClass[inst] == nil, "Failed to remove")

		inst, class = next(self._instToClass)
	end

	-- Disconnect events
	self._maid:DoCleaning()
end

return Binder