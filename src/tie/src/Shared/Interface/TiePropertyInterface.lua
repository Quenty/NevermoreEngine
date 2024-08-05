--[=[
	@class TiePropertyInterface
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local String = require("String")
local TieInterfaceUtils = require("TieInterfaceUtils")
local TiePropertyChangedSignalConnection = require("TiePropertyChangedSignalConnection")
local TiePropertyImplementationUtils = require("TiePropertyImplementationUtils")
local TieUtils = require("TieUtils")
local ValueBaseUtils = require("ValueBaseUtils")
local ValueObject = require("ValueObject")
local AttributeUtils = require("AttributeUtils")
local AttributeValue = require("AttributeValue")
local Symbol = require("Symbol")

local UNSET_VALUE = Symbol.named("unsetValue")

local TiePropertyInterface = {}
TiePropertyInterface.ClassName = "TiePropertyInterface"
TiePropertyInterface.__index = TiePropertyInterface

function TiePropertyInterface.new(folder, adornee, memberDefinition)
	local self = setmetatable({}, TiePropertyInterface)

	assert(folder or adornee, "Folder or adornee required")

	self._folder = folder
	self._adornee = adornee
	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._tieDefinition = self._memberDefinition:GetTieDefinition()

	return self
end

function TiePropertyInterface:ObserveBrio(predicate)
	return self:_observeValueBaseBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(valueBase)
			if typeof(valueBase) == "Instance" then
				return RxInstanceUtils.observePropertyBrio(valueBase, "Value", predicate)
			else
				-- TODO: Maybe don't assumet his exists and use a helper method instead.
				return valueBase:ObserveBrio(predicate)
			end
		end);
	})
end

function TiePropertyInterface:Observe()
	return self:_observeValueBaseBrio():Pipe({
		Rx.switchMap(function(brio)
			if brio:IsDead() then
				return Rx.of(nil)
			end
			local valueBase = brio:GetValue()
			if not valueBase then
				return Rx.of(nil)
			end

			return Observable.new(function(sub)
				local maid = Maid.new()

				sub:Fire(valueBase.Value)
				maid:GiveTask(valueBase.Changed:Connect(function()
					sub:Fire(valueBase.Value)
				end))

				maid:GiveTask(brio:GetDiedSignal():Connect(function()
					if sub:IsPending() then
						sub:Fire(nil)
					end
				end))

				return maid
			end)
		end);
		Rx.distinct();
	})
end

function TiePropertyInterface:_getFolder()
	return TieInterfaceUtils.getFolder(self._tieDefinition, self._folder, self._adornee)
end

function TiePropertyInterface:_findValueBase()
	local folder = self:_getFolder()
	if not folder then
		return nil
	end

	local implementation = folder:FindFirstChild(self._memberDefinition:GetMemberName())
	if not implementation then
		return nil
	end

	if implementation:IsA("BindableFunction") then
		-- ValueObject
		return TieUtils.decode(implementation:Invoke())
	elseif String.endsWith(implementation.ClassName, "Value") then
		return implementation
	else
		return nil
	end
end

function TiePropertyInterface:_getValueBaseOrError()
	local valueBase = self:_findValueBase()
	if not valueBase then
		error(("%s.%s is not implemented for %s"):format(
			self._tieDefinition:GetContainerName(),
			self._memberDefinition:GetMemberName(),
			self:_getFullName()))
	end
	return valueBase
end

function TiePropertyInterface:_getFullName()
	if self._folder then
		return self._folder:GetFullName()
	elseif self._adornee then
		return self._adornee:GetFullName()
	else
		error("[TiePropertyInterface] - Either folder or adornee should be defined")
	end
end

function TiePropertyInterface:_getChangedEvent()
	return {
		Connect = function(_, callback)
			assert(type(callback) == "function", "Bad callback")
			return TiePropertyChangedSignalConnection.new(function(connMaid)
				local valueObject = ValueObject.new(nil)
				connMaid:GiveTask(valueObject)

				connMaid:GiveTask(self:Observe():Subscribe(function(value)
					valueObject.Value = value
				end))

				-- After observing, so we can emit only changes.
				connMaid:GiveTask(valueObject.Changed:Connect(callback))
			end)
		end;
	}
end

local IMPLEMENTATION_TYPES = {
	attribute = "attribute";
	none = "none";
}

function TiePropertyInterface:_observeFromFolder(folder)
	return Observable.new(function(sub)
		local memberName = self._memberDefinition:GetMemberName()
		local topMaid = Maid.new()

		local validNamedChildren = {}

		local lastImplementationType = UNSET_VALUE

		local function update()
			if not sub:IsPending() then
				return
			end

			-- Prioritize attributes first
			local currentAttribute = folder:GetAttribute(memberName)
			if currentAttribute ~= nil then
				if lastImplementationType ~= IMPLEMENTATION_TYPES.attribute then
					lastImplementationType = IMPLEMENTATION_TYPES.attribute
					sub:Fire(AttributeValue.new(folder, memberName))
				end

				return
			end

			local firstChild = validNamedChildren[1]
			if not firstChild then
				if lastImplementationType ~= IMPLEMENTATION_TYPES.none then
					lastImplementationType = IMPLEMENTATION_TYPES.none
					sub:Fire(nil)
				end

				return
			end

			local implementation
			if firstChild:IsA("BindableFunction") then
				implementation = TieUtils.decode(firstChild:Invoke())
			elseif String.endsWith(firstChild.ClassName, "Value") then
				implementation = firstChild
			else
				if lastImplementationType ~= IMPLEMENTATION_TYPES.none then
					lastImplementationType = IMPLEMENTATION_TYPES.none
					sub:Fire(nil)
				end

				return
			end

			if lastImplementationType ~= implementation then
				lastImplementationType = implementation
				sub:Fire(implementation)
			end
		end

		-- Subscribe to named children
		topMaid:GiveTask(RxInstanceUtils.observeChildrenOfNameBrio(folder, "Instance", self._memberDefinition:GetMemberName())
			:Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local innerMaid = brio:ToMaid()
				local child = brio:GetValue()

				innerMaid:GiveTask(function()
					local index = table.find(validNamedChildren, child)

					if index then
						table.remove(validNamedChildren, index)
					end

					update()
				end)

				table.insert(validNamedChildren, child)
				update()
			end))

		topMaid:GiveTask(folder:GetAttributeChangedSignal(memberName):Connect(update))
		update()

		return topMaid
	end)
end

function TiePropertyInterface:_observeValueBaseBrio()
	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(folder)
			return self:_observeFromFolder(folder)
		end);
		RxBrioUtils.onlyLastBrioSurvives();
	})
end

function TiePropertyInterface:_observeFolderBrio()
	return TieInterfaceUtils.observeFolderBrio(self._tieDefinition, self._folder, self._adornee)
end

function TiePropertyInterface:__index(index)
	if TiePropertyInterface[index] then
		return TiePropertyInterface[index]
	elseif index == "Value" then
		local folder = self:_getFolder()
		if folder then
			local currentAttributeValue = folder:GetAttribute(self._memberDefinition:GetMemberName())
			if currentAttributeValue ~= nil then
				return currentAttributeValue
			end
		end

		local valueBase = self:_getValueBaseOrError()
		return valueBase.Value
	elseif index == "Changed" then
		return self:_getChangedEvent()
	elseif index == "_adornee" or index == "_folder" or index == "_memberDefinition" or index == "_tieDefinition" then
		return rawget(self, index)
	else
		error(("Bad index %q for TiePropertyInterface"):format(tostring(index)))
	end
end

function TiePropertyInterface:__newindex(index, value)
	if index == "_adornee" or index == "_folder" or index == "_memberDefinition" or index == "_tieDefinition" then
		rawset(self, index, value)
	elseif index == "Value" then
		local className = ValueBaseUtils.getClassNameFromType(typeof(value))
		if not className then
			error(("[TiePropertyImplementation] - Bad implementation value type %q, cannot set"):format(typeof(value)))
		end

		local valueBase = self:_findValueBase()
		if type(valueBase) == "table" or (typeof(valueBase) == "Instance" and valueBase.ClassName == className) then
			valueBase.Value = value
		elseif AttributeUtils.isValidAttributeType(typeof(value)) and value ~= nil then
			local folder = self:_getFolder()
			if folder then
				folder:SetAttribute(self._memberDefinition:GetMemberName(), value)

				-- Remove existing as needed
				local current = folder:FindFirstChild(self._memberDefinition:GetMemberName())
				if current then
					current:Destroy()
				end
				return
			end
		else
			local folder = self:_getFolder()
			if folder then
				local copy = TiePropertyImplementationUtils.changeToClassIfNeeded(self._memberDefinition, folder, className)
				copy.Value = value
				copy.Parent = folder
			else
				error(("[TiePropertyImplementation] - No folder for %q"):format(self._memberDefinition:GetMemberName()))
			end
		end
	elseif index == "Changed" then
		error(("Cannot assign %q for TiePropertyInterface"):format(tostring(index)))
	else
		error(("Bad index %q for TiePropertyInterface"):format(tostring(index)))
	end
end


return TiePropertyInterface