--!strict
--[=[
    @class BrineInstanceRegistry
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local BrineInstanceRegistry = setmetatable({}, BaseObject)
BrineInstanceRegistry.ClassName = "BrineInstanceRegistry"
BrineInstanceRegistry.__index = BrineInstanceRegistry

export type InstanceId = string

export type BrineInstanceRegistry = typeof(setmetatable(
	{} :: {
		_idToInstance: { [InstanceId]: Instance },
		_instanceToId: { [Instance]: InstanceId },
		_counter: number,
	},
	{} :: typeof({ __index = BrineInstanceRegistry })
))

function BrineInstanceRegistry.new(): BrineInstanceRegistry
	local self: BrineInstanceRegistry = setmetatable(BaseObject.new() :: any, BrineInstanceRegistry)

	self._idToInstance = setmetatable({} :: any, { __mode = "" })
	self._instanceToId = setmetatable({} :: any, { __mode = "" })
	self._counter = 0

	return self
end

function BrineInstanceRegistry.IdToInstance(self: BrineInstanceRegistry, id: InstanceId): Instance?
	return self._idToInstance[id]
end

function BrineInstanceRegistry.FindInstanceId(self: BrineInstanceRegistry, instance: Instance): InstanceId?
	return self._instanceToId[instance]
end

function BrineInstanceRegistry.InstanceToId(self: BrineInstanceRegistry, instance: Instance): InstanceId
	local found = self._instanceToId[instance]
	if found then
		return found
	end

	local id = self._counter
	self._counter = self._counter + 1

	local newId = tostring(id)
	self._idToInstance[newId] = instance
	self._instanceToId[instance] = newId
	return newId
end

function BrineInstanceRegistry.SetInstanceId(self: BrineInstanceRegistry, instance: Instance, id: InstanceId?)
	local currentId = self._instanceToId[instance]
	if currentId then
		self._idToInstance[currentId] = nil
	end

	if id ~= nil then
		local currentInstance = self._idToInstance[id]
		if currentInstance then
			self._instanceToId[currentInstance] = nil
		end

		self._idToInstance[id] = instance
	end

	self._instanceToId[instance] = id :: any
end

return BrineInstanceRegistry
