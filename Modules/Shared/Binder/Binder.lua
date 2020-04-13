--- Bind class to Roblox Instance
-- @classmod Binder

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Maid = require("Maid")
local fastSpawn = require("fastSpawn")
local Signal = require("Signal")

local Binder = {}
Binder.__index = Binder
Binder.ClassName = "Binder"

function Binder.new(tagName, constructor)
	local self = setmetatable({}, Binder)

	self._maid = Maid.new()
	self._tagName = tagName or error("Bad argument 'tagName', expected string")
	self._constructor = constructor or error("Bad argument 'constructor', expected table or function")

	self._loading = setmetatable({}, {__mode = "kv"})

	delay(5, function()
		if not self._loaded then
			warn("Binder is not loaded. Call :Init() on it!")
		end
	end)

	return self
end

function Binder:Init()
	if self._loaded then
		return
	end
	self._loaded = true

	for _, inst in pairs(CollectionService:GetTagged(self._tagName)) do
		fastSpawn(function()
			self:_add(inst)
		end)
	end

	self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(self._tagName):Connect(function(inst)
		self:_add(inst)
	end))
	self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(self._tagName):Connect(function(inst)
		self:_remove(inst)
	end))
end

function Binder:GetConstructor()
	return self._constructor
end

function Binder:GetClassAddedSignal()
	if self._classAddedSignal then
		return self._classAddedSignal
	end

	self._classAddedSignal = Signal.new() -- :fire(class, inst)
	self._maid:GiveTask(self._classAddedSignal)
	return self._classAddedSignal
end

function Binder:GetClassRemovingSignal()
	if self._classRemovingSignal then
		return self._classRemovingSignal
	end

	self._classRemovingSignal = Signal.new() -- :fire(class, inst)
	self._maid:GiveTask(self._classRemovingSignal)

	return self._classRemovingSignal
end

function Binder:GetTag()
	return self._tagName
end

function Binder:GetAll()
	local all = {}
	for _, inst in pairs(CollectionService:GetTagged(self._tagName)) do
		table.insert(all, self._maid[inst])
	end
	return all
end

-- Using this acknowledges that we're intentionally binding on a safe client object,
-- i.e. one without replication.
function Binder:BindClient(inst)
	if not RunService:IsClient() then
		warn(("[Binder.BindClient] - Bindings '%s' done on the server! Will be replicated!")
			:format(self._tagName))
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

function Binder:Bind(inst)
	if RunService:IsClient() then
		warn(("[Binder.Bind] - Bindings '%s' done on the client! Will be disrupted upon server replication!")
			:format(self._tagName))
	end

	CollectionService:AddTag(inst, self._tagName)
	return self:Get(inst)
end

function Binder:Unbind(inst)
	assert(typeof(inst) == "Instance")

	if RunService:IsClient() then
		warn(("[Binder.Bind] - Unbinding '%s' done on the client! Might be disrupted upon server replication!")
			:format(self._tagName))
	end

	CollectionService:RemoveTag(inst, self._tagName)
end

function Binder:UnbindClient(inst)
	assert(typeof(inst) == "Instance")
	CollectionService:RemoveTag(inst, self._tagName)
end

function Binder:Get(inst)
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")
	return self._maid[inst]
end

function Binder:_add(inst)
	assert(typeof(inst) == "Instance", "Argument 'inst' is not an Instance")
	if self._loading[inst] then
		return
	end

	self._loading[inst] = true

	local result
	if type(self._constructor) == "function" then
		result = self._constructor(inst)
	elseif self._constructor.Create then
		result = self._constructor:Create(inst)
	else
		result = self._constructor.new(inst)
	end

	if not self._loading[inst] then
		-- Got GCed in the process of loading?!
		warn(("[Binder._add] - Failed to load instance %q of %q, removed while loading!")
			:format(
				inst:GetFullName(),
				tostring(type(self._constructor) == "table" and self._constructor.ClassName or self._constructor)))
		return
	end

	self._maid[inst] = result

	if self._classAddedSignal then
		self._classAddedSignal:Fire(result, inst)
	end
end

function Binder:_remove(inst)
	local class = self._maid[inst]
	if class and self._classRemovingSignal then
		self._classRemovingSignal:Fire(class, inst)
	end

	self._maid[inst] = nil
	self._loading[inst] = nil
end

function Binder:Destroy()
	self._maid:DoCleaning()
end

return Binder