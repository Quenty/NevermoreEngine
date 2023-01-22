--[=[
	@class TiePropertyImplementation
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TieUtils = require("TieUtils")
local Maid = require("Maid")
local ValueBaseUtils = require("ValueBaseUtils")
local TiePropertyImplementationUtils = require("TiePropertyImplementationUtils")
local AttributeUtils = require("AttributeUtils")
local AttributeValue = require("AttributeValue")

local TiePropertyImplementation = setmetatable({}, BaseObject)
TiePropertyImplementation.ClassName = "TiePropertyImplementation"
TiePropertyImplementation.__index = TiePropertyImplementation

function TiePropertyImplementation.new(memberDefinition, folder, initialValue, _actualSelf)
	local self = setmetatable(BaseObject.new(), TiePropertyImplementation)

	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._folder = assert(folder, "No folder")

	self._maid:GiveTask(function()
		local memberName = self._memberDefinition:GetMemberName()
		local currentInstance = self._folder:FindFirstChild(memberName)
		self._folder:SetAttribute(memberName, nil)

		if not currentInstance then
			return
		end

		-- Clean up what we've created.
		currentInstance:Destroy()
	end)

	self:SetImplementation(initialValue)

	return self
end

function TiePropertyImplementation:SetImplementation(implementation)
	local maid = Maid.new()
	self._maid._current = nil

	-- override with default value on nil case
	if implementation == nil then
		implementation = self._memberDefinition:GetDefaultValue()
	end

	self:_updateImplementation(maid, implementation)

	self._maid._current = maid
end

function TiePropertyImplementation:_updateImplementation(maid, implementation)
	if type(implementation) == "table" and implementation.Changed then
		local copy = self:_changeToClassIfNeeded("BindableFunction", implementation)
		copy.OnInvoke = function()
			return TieUtils.encode(implementation)
		end
		copy.Parent = self._folder
	elseif typeof(implementation) == "Instance" and implementation:IsA("ValueBase") then
		local resultingType = ValueBaseUtils.getValueBaseType(implementation.ClassName)
		if resultingType and AttributeUtils.isValidAttributeType(resultingType) and resultingType ~= "nil" then
			self:_removeClassIfNeeded()

			local attributeValue = AttributeValue.new(self._folder, self._memberDefinition:GetMemberName())
			self:_syncMember(maid, attributeValue, implementation)
		else
			local copy = self:_changeToClassIfNeeded(implementation.ClassName, implementation)
			self:_syncMember(maid, copy, implementation)
			copy.Parent = self._folder
		end
	else
		if AttributeUtils.isValidAttributeType(typeof(implementation)) and implementation ~= nil then
			self:_removeClassIfNeeded()
			self._folder:SetAttribute(self._memberDefinition:GetMemberName(), implementation)
			return
		end

		local className = ValueBaseUtils.getClassNameFromType(typeof(implementation))
		if not className then
			error(("[TiePropertyImplementation] - Bad implementation value type %q, cannot set"):format(typeof(implementation)))
		end

		local copy = self:_changeToClassIfNeeded(className, implementation)
		copy.Value = implementation
		copy.Parent = self._folder
	end
end

function TiePropertyImplementation:_changeToClassIfNeeded(className)
	return TiePropertyImplementationUtils.changeToClassIfNeeded(self._memberDefinition, self._folder, className)
end

function TiePropertyImplementation:_removeClassIfNeeded()
	local implementation = self._folder:FindFirstChild(self._memberDefinition:GetMemberName())
	if implementation then
		implementation:Destroy()
	end
end

function TiePropertyImplementation:_syncMember(maid, copy, implementation)
	copy.Value = implementation.Value

	maid:GiveTask(implementation.Changed:Connect(function()
		copy.Value = implementation.Value
	end))

	maid:GiveTask(copy.Changed:Connect(function()
		implementation.Value = copy.Value
	end))
end

return TiePropertyImplementation