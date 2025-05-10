--[=[
	@class IKResource
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local IKResource = setmetatable({}, BaseObject)
IKResource.ClassName = "IKResource"
IKResource.__index = IKResource

function IKResource.new(data)
	local self = setmetatable(BaseObject.new(), IKResource)

	self._data = assert(data, "Bad data")
	assert(data.name, "Bad data.name")
	assert(data.robloxName, "Bad data.robloxName")

	self._instance = nil
	self._childResourceMap = {} -- [robloxName] = { data = data; ikResource = ikResource }
	self._descendantLookupMap = {
		[data.name] = self,
	}

	self._ready = self._maid:Add(ValueObject.new(false, "boolean"))

	self.ReadyChanged = self._ready.Changed

	if self._data.children then
		for _, childData in self._data.children do
			self:_addResource(IKResource.new(childData))
		end
	end

	return self
end

function IKResource:GetData()
	return self._data
end

function IKResource:IsReady(): boolean
	return self._ready.Value
end

function IKResource:Get(descendantName: string)
	local resource = self._descendantLookupMap[descendantName]
	if not resource then
		error(string.format("[IKResource.Get] - Resource %q does not exist", tostring(descendantName)))
	end

	local result = resource:GetInstance()
	if not result then
		error("[IKResource.Get] - Not ready!")
	end

	return result
end

function IKResource:GetInstance(): Instance?
	if self._data.isLink then
		if self._instance then
			return self._instance.Value
		else
			return nil
		end
	end

	return self._instance
end

function IKResource:SetInstance(instance: Instance?)
	if self._instance == instance then
		return
	end

	self._maid._instanceMaid = nil
	self._instance = instance

	local maid = Maid.new()

	if next(self._childResourceMap) then
		if instance then
			self:_startListening(maid, instance)
		else
			self:_clearChildren()
		end
	end

	if instance and self._data.isLink then
		assert(instance:IsA("ObjectValue"))

		self._maid:GiveTask(instance.Changed:Connect(function()
			self:_updateReady()
		end))
	end

	self._maid._instanceMaid = maid
	self:_updateReady()
end

function IKResource:GetLookupTable()
	return self._descendantLookupMap
end

function IKResource:_startListening(maid, instance)
	for _, child in instance:GetChildren() do
		self:_handleChildAdded(child)
	end

	maid:GiveTask(instance.ChildAdded:Connect(function(child)
		self:_handleChildAdded(child)
	end))
	maid:GiveTask(instance.ChildRemoved:Connect(function(child)
		self:_handleChildRemoved(child)
	end))
end

function IKResource:_addResource(ikResource)
	local data = ikResource:GetData()
	assert(data.name, "Bad data.name")
	assert(data.robloxName, "Bad data.robloxName")

	assert(type(data.robloxName) == "string", "Bad data.robloxName")
	assert(not self._childResourceMap[data.robloxName], "Data already exists")
	assert(not self._descendantLookupMap[data.name], "Data already exists")

	self._childResourceMap[data.robloxName] = ikResource

	self._maid:GiveTask(ikResource)

	self._maid:GiveTask(ikResource.ReadyChanged:Connect(function()
		self:_updateReady()
	end))

	-- Add to _descendantLookupMap, including the actual ikResource
	for name, resource in pairs(ikResource:GetLookupTable()) do
		assert(not self._descendantLookupMap[name], "Resource already exists with name")

		self._descendantLookupMap[name] = resource
	end
end

function IKResource:_handleChildAdded(child)
	local resource = self._childResourceMap[child.Name]
	if not resource then
		return
	end

	resource:SetInstance(child)
end

function IKResource:_handleChildRemoved(child)
	local resource = self._childResourceMap[child.Name]
	if not resource then
		return
	end

	if resource:GetInstance() == child then
		resource:SetInstance(nil)
	end
end

function IKResource:_clearChildren()
	for _, child in self._childResourceMap do
		child:SetInstance(nil)
	end
end

function IKResource:_updateReady()
	self._ready.Value = self:_calculateIsReady()
end

function IKResource:_calculateIsReady()
	if not self._instance then
		return false
	end

	if self._data.isLink then
		if not self._instance.Value then
			return false
		end
	end

	for _, child in self._childResourceMap do
		if not child:IsReady() then
			return false
		end
	end

	return true
end

return IKResource
