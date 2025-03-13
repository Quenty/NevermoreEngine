--[=[
	Sets properties on the client and then replicates them to the server
	@class OverriddenProperty
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ThrottledFunction = require("ThrottledFunction")

local OverriddenProperty = setmetatable({}, BaseObject)
OverriddenProperty.ClassName = "OverriddenProperty"
OverriddenProperty.__index = OverriddenProperty

--[=[
	Constructs a new OverriddenProperty.

	@param robloxInstance Instance
	@param propertyName string
	@param replicateRate number? -- Optional replication rate and callback
	@param replicateCallback (T)?
	@return OverriddenProperty
]=]
function OverriddenProperty.new(
	robloxInstance: Instance,
	propertyName: string,
	replicateRate: number?,
	replicateCallback: (any) -> ()
)
	local self = setmetatable(BaseObject.new(robloxInstance), OverriddenProperty)

	assert(typeof(robloxInstance) == "Instance", "Bad robloxInstance")
	assert(type(propertyName) == "string", "Bad propertyName")

	self._disconnectCount = 0
	self._propertyName = propertyName or error("No propertyName")
	self._value = self._obj[self._propertyName]

	if replicateRate ~= nil then
		assert(type(replicateRate) == "number", "Bad replicateRate")
		assert(type(replicateCallback) == "function", "Bad replicateCallback")

		self._throttledExecuteReplicate = self._maid:Add(ThrottledFunction.new(replicateRate, replicateCallback))
	end

	self:_updateListenBinding()

	return self
end

--[=[
	Sets the property

	@param value T
]=]
function OverriddenProperty:Set(value)
	assert(typeof(value) == typeof(self._value), "Bad value")

	self._value = value
	self:_executeSet(true)
end

--[=[
	Gets the property

	@return T
]=]
function OverriddenProperty:Get()
	return self._value
end

function OverriddenProperty:_executeSet(doReplicate: boolean)
	self:_pushDisconnectChange()
	self._obj[self._propertyName] = self._value

	if doReplicate and self._throttledExecuteReplicate then
		self._throttledExecuteReplicate:Call(self._value)
	end

	self:_popDisconnectChange()
end

function OverriddenProperty:_pushDisconnectChange()
	self._disconnectCount = self._disconnectCount + 1

	if self._disconnectCount >= 5 then
		warn("[OverriddenProperty._pushDisconnectChange] - Disconnect count is somehow 5+")
	end

	self:_updateListenBinding()
end

function OverriddenProperty:_popDisconnectChange()
	self._disconnectCount = self._disconnectCount - 1

	if self._disconnectCount < 0 then
		warn("[OverriddenProperty._pushDisconnectChange] - Disconnect count is somehow less than 0")
	end

	self:_updateListenBinding()
end

function OverriddenProperty:_updateListenBinding()
	if self._disconnectCount == 0 then
		self:_listenForChange()
	else
		self:_disconnectListenForChange()
	end
end

function OverriddenProperty:_disconnectListenForChange()
	self._maid._update = nil
end

function OverriddenProperty:_listenForChange()
	if self._maid._update and self._maid._update.Connected then
		return
	end

	self._maid._update = self._obj:GetPropertyChangedSignal(self._propertyName)
		:Connect(function()
			self:_executeSet(false)
		end)
end

return OverriddenProperty