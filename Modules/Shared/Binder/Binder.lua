--- Bind class to Roblox Instance
-- @classmod Binder

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Maid = require("Maid")
local Signal = require("Signal")

--[[
@usage

-- Setup a class!
local MyClass = {}
MyClass.__index = MyClass

function MyClass.new(robloxInstance)
	print("New tagged instance of ", robloxInstance")
	return setmetatable({}, MyClass)
end

function MyClass:Destroy()
	print("Cleaning up")
	setmetatable(self, nil)
end

-- bind to every instance with tag of "TagName"!
local binder = Binder.new("TagName", MyClass)
binder:Init() -- listens for new instances and connects events
]]

local Binder = {}
Binder.__index = Binder
Binder.ClassName = "Binder"

--- Creates a new binder object.
-- @constructor Binder.new(tagName, constructor)
-- @param tagName Name of the tag to bind to. This uses CollectionService's tag system
-- @param constructor A constructor to create the new class. Comes in three flavors.
-- @treturn Binder
function Binder.new(tagName, constructor)
	local self = setmetatable({}, Binder)

	self._maid = Maid.new()
	self._tagName = tagName or error("Bad argument 'tagName', expected string")
	self._constructor = constructor or error("Bad argument 'constructor', expected table or function")

	self._instToClass = {} -- [inst] = class
	self._allClassSet = {} -- [class] = true
	self._pendingInstSet = {} -- [inst] = true

	self._listeners = {} -- [inst] = callback

	delay(5, function()
		if not self._loaded then
			warn("Binder is not loaded. Call :Init() on it!")
		end
	end)

	return self
end

--- Retrieves whether or not its a binder
-- @param value
-- @return true or false, whether or not it is a value
function Binder.isBinder(value)
	return type(value) == "table" and value.ClassName == "Binder"
end

--- Listens for new instances and connects to the GetInstanceAddedSignal() and removed signal!
function Binder:Init()
	if self._loaded then
		return
	end
	self._loaded = true

	local bindable = Instance.new("BindableEvent")

	for _, inst in pairs(CollectionService:GetTagged(self._tagName)) do
		local conn = bindable.Event:Connect(function()
			self:_add(inst)
		end)

		bindable:Fire()
		conn:Disconnect()
	end

	bindable:Destroy()

	self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(self._tagName):Connect(function(inst)
		self:_add(inst)
	end))
	self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(self._tagName):Connect(function(inst)
		self:_remove(inst)
	end))
end


-- Returns the tag name that the binder has
function Binder:GetTag()
	return self._tagName
end

--- Returns whatever was set for the construtor. Used for meta-analysis of the binder, such as extracting new
function Binder:GetConstructor()
	return self._constructor
end

-- Fired when added, and then after removal, but before destroy!
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

-- Returns a new signal that will fire whenever a class is bound to the binder
--[[
@usage

local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

birdBinder:GetClassAddedSignal():Connect(function(bird)
	bird:Squack() -- Make the bird squack when it's first spawned
end)

-- Load all birds
birdBinder:Init()
]]
function Binder:GetClassAddedSignal()
	if self._classAddedSignal then
		return self._classAddedSignal
	end

	self._classAddedSignal = Signal.new() -- :fire(class, inst)
	self._maid:GiveTask(self._classAddedSignal)
	return self._classAddedSignal
end

-- Returns a new signal that will fire whenever a class is removed from the binder
function Binder:GetClassRemovingSignal()
	if self._classRemovingSignal then
		return self._classRemovingSignal
	end

	self._classRemovingSignal = Signal.new() -- :fire(class, inst)
	self._maid:GiveTask(self._classRemovingSignal)

	return self._classRemovingSignal
end

--[[
@usage

local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

-- Update every bird every frame
RunService.Stepped:Connect(function()
	for _, bird in pairs(birdBinder:GetAll()) do
		bird:Update()
	end
end)

birdBinder:Init()
]]
--- Returns all of the classes in a new table
function Binder:GetAll()
	local all = {}
	for class, _ in pairs(self._allClassSet) do
		all[#all+1] = class
	end
	return all
end


--[[
@usage

local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

-- Update every bird every frame
RunService.Stepped:Connect(function()
	for bird, _ in pairs(birdBinder:GetAllSet()) do
		bird:Update()
	end
end)

birdBinder:Init()
]]
--- Faster method to get all items in a binder
-- NOTE: Do not mutate this set directly
function Binder:GetAllSet()
	return self._allClassSet
end

--- Binds an instance to this binder using collection service and attempts
-- to return it if it's bound properly. See BinderUtils.promiseBoundClass() for a safe
-- way to retrieve it.
-- NOTE: Do not assume that a bound object will be retrieved
function Binder:Bind(inst)
	if RunService:IsClient() then
		warn(("[Binder.Bind] - Bindings '%s' done on the client! Will be disrupted upon server replication!")
			:format(self._tagName))
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

-- Unbinds the instance by removing the tag
function Binder:Unbind(inst)
	assert(typeof(inst) == "Instance")

	if RunService:IsClient() then
		warn(("[Binder.Bind] - Unbinding '%s' done on the client! Might be disrupted upon server replication!")
			:format(self._tagName))
	end

	CollectionService:RemoveTag(inst, self._tagName)
end

-- See :Bind(). Acknowledges the risk of doing this on the client.
-- Using this acknowledges that we're intentionally binding on a safe client object,
-- i.e. one without replication. If another tag is changed on this instance, this tag will be lost/changed.
function Binder:BindClient(inst)
	if not RunService:IsClient() then
		warn(("[Binder.BindClient] - Bindings '%s' done on the server! Will be replicated!")
			:format(self._tagName))
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

-- See Unbind(), acknowledges risk of doing this on the client.
function Binder:UnbindClient(inst)
	assert(typeof(inst) == "Instance")
	CollectionService:RemoveTag(inst, self._tagName)
end

--- Returns a version of the clas
function Binder:Get(inst)
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")
	return self._instToClass[inst]
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
		class = self._constructor(inst)
	elseif self._constructor.Create then
		class = self._constructor:Create(inst)
	else
		class = self._constructor.new(inst)
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

	if not (type(class) == "table" and type(class.Destroy) == "function") then
		warn(("[Binder._add] - Bad class constructed for tag %q"):format(self._tagName))
		return
	end

	assert(self._instToClass[inst] == nil, "Overwrote")

	-- Add to state
	self._allClassSet[class] = true
	self._instToClass[inst] = class

	-- Fire events
	local listeners = self._listeners[inst]
	if listeners then
		local bindable = Instance.new("BindableEvent")

		for callback, _ in pairs(listeners) do
			local conn = bindable.Event:Connect(function()
				callback(class)
			end)

			bindable:Fire()
			conn:Disconnect()
		end

		bindable:Destroy()
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
		local bindable = Instance.new("BindableEvent")

		for callback, _ in pairs(listeners) do
			local conn = bindable.Event:Connect(function()
				callback(nil)
			end)

			bindable:Fire()
			conn:Disconnect()
		end

		bindable:Destroy()
	end

	-- Destroy class
	if class.Destroy then
		class:Destroy()
	else
		warn(("[Binder._remove] - Class %q no longer has destroy, something destroyed it!")
			:format(tostring(self._tagName)))
	end
end

--- Cleans up all bound classes, and disconnects all events
function Binder:Destroy()
	local index, class = next(self._instToClass)
	while class ~= nil do
		self:_remove(class)
		assert(self._instToClass[index] == nil)

		index, class = next(self._instToClass)
	end

	-- Disconnect events
	self._maid:DoCleaning()
end

return Binder