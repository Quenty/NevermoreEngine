--[=[
	@class TiePropertyInterface
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local AttributeValue = require("AttributeValue")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxSignal = require("RxSignal")
local String = require("String")
local Symbol = require("Symbol")
local TieMemberInterface = require("TieMemberInterface")
local TiePropertyImplementationUtils = require("TiePropertyImplementationUtils")
local TieUtils = require("TieUtils")
local ValueBaseUtils = require("ValueBaseUtils")

local UNSET_VALUE = Symbol.named("unsetValue")

local TiePropertyInterface = setmetatable({}, TieMemberInterface)
TiePropertyInterface.ClassName = "TiePropertyInterface"
TiePropertyInterface.__index = TiePropertyInterface

function TiePropertyInterface.new(implParent, adornee: Instance, memberDefinition, interfaceTieRealm)
	local self = setmetatable(
		TieMemberInterface.new(implParent, adornee, memberDefinition, interfaceTieRealm),
		TiePropertyInterface
	)

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
		end),
	})
end

function TiePropertyInterface:Observe()
	return self:_observeValueBaseBrio():Pipe({
		Rx.switchMap(function(brio)
			return Observable.new(function(sub)
				if brio:IsDead() then
					sub:Fire(nil)
					sub:Complete()
					return
				end

				local valueBase = brio:GetValue()
				if not valueBase then
					sub:Fire(nil)
					sub:Complete()
					return
				end

				local maid = brio:ToMaid()

				maid:GiveTask(valueBase.Changed:Connect(function()
					sub:Fire(valueBase.Value)
				end))

				maid:GiveTask(brio:GetDiedSignal():Connect(function()
					if sub:IsPending() then
						sub:Fire(nil)
					end
				end))

				sub:Fire(valueBase.Value)

				return maid
			end)
		end),
		Rx.distinct(),
	})
end

function TiePropertyInterface:_findValueBase()
	local implParent = self:GetImplParent()
	if not implParent then
		return nil
	end

	local implementation = implParent:FindFirstChild(self._memberDefinition:GetMemberName())
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
		error(
			string.format(
				"%s.%s is not implemented for %s",
				self._memberDefinition:GetFriendlyName(),
				self:_getFullName()
			)
		)
	end
	return valueBase
end

function TiePropertyInterface:_getFullName()
	if self._implParent then
		return self._implParent:GetFullName()
	elseif self._adornee then
		return self._adornee:GetFullName()
	else
		error("[TiePropertyInterface] - Either implParent or adornee should be defined")
	end
end

function TiePropertyInterface:_getChangedEvent()
	return RxSignal.new(self:Observe():Pipe({
		Rx.skip(1),
	}))
end

local IMPLEMENTATION_TYPES = {
	attribute = "attribute",
	none = "none",
}

function TiePropertyInterface:_observeFromImplParent(implParent)
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
			local currentAttribute = implParent:GetAttribute(memberName)
			if currentAttribute ~= nil then
				if lastImplementationType ~= IMPLEMENTATION_TYPES.attribute then
					lastImplementationType = IMPLEMENTATION_TYPES.attribute
					sub:Fire(AttributeValue.new(implParent, memberName))
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

		-- Subscribe to named children, assuming no name changes...
		topMaid:GiveTask(RxInstanceUtils.observeChildrenBrio(implParent, function(value)
			return value.Name == memberName
		end):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local innerMaid, child = brio:ToMaidAndValue()

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

		topMaid:GiveTask(implParent:GetAttributeChangedSignal(memberName):Connect(update))
		update()

		return topMaid
	end)
end

function TiePropertyInterface:_observeValueBaseBrio()
	return self:ObserveImplParentBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(implParent)
			return self:_observeFromImplParent(implParent)
		end),
		RxBrioUtils.onlyLastBrioSurvives(),
	})
end

function TiePropertyInterface:__index(index)
	if TiePropertyInterface[index] then
		return TiePropertyInterface[index]
	elseif index == "Value" then
		local implParent = self:GetImplParent()
		if implParent then
			local currentAttributeValue = implParent:GetAttribute(self._memberDefinition:GetMemberName())
			if currentAttributeValue ~= nil then
				return currentAttributeValue
			end
		end

		local valueBase = self:_getValueBaseOrError()
		return valueBase.Value
	elseif index == "Changed" then
		return self:_getChangedEvent()
	elseif
		index == "_adornee"
		or index == "_implParent"
		or index == "_memberDefinition"
		or index == "_tieDefinition"
	then
		return rawget(self, index)
	else
		error(string.format("Bad index %q for TiePropertyInterface", tostring(index)))
	end
end

function TiePropertyInterface:__newindex(index, value)
	if index == "_adornee" or index == "_implParent" or index == "_memberDefinition" or index == "_tieDefinition" then
		rawset(self, index, value)
	elseif index == "Value" then
		local className = ValueBaseUtils.getClassNameFromType(typeof(value))
		if not className then
			error(
				string.format(
					"[TiePropertyImplementation] - Bad implementation value type %q, cannot set",
					typeof(value)
				)
			)
		end

		local valueBase = self:_findValueBase()
		if type(valueBase) == "table" or (typeof(valueBase) == "Instance" and valueBase.ClassName == className) then
			(valueBase :: any).Value = value
		elseif AttributeUtils.isValidAttributeType(typeof(value)) and value ~= nil then
			local implParent = self:GetImplParent()
			if implParent then
				implParent:SetAttribute(self._memberDefinition:GetMemberName(), value)

				-- Remove existing as needed
				local current = implParent:FindFirstChild(self._memberDefinition:GetMemberName())
				if current then
					current:Destroy()
				end
				return
			end
		else
			local implParent = self:GetImplParent()
			if implParent then
				local copy =
					TiePropertyImplementationUtils.changeToClassIfNeeded(self._memberDefinition, implParent, className)
				copy.Value = value
				copy.Parent = implParent
			else
				error(
					string.format(
						"[TiePropertyImplementation] - No implParent for %q",
						self._memberDefinition:GetMemberName()
					)
				)
			end
		end
	elseif index == "Changed" then
		error(string.format("Cannot assign %q for TiePropertyInterface", tostring(index)))
	else
		error(string.format("Bad index %q for TiePropertyInterface", tostring(index)))
	end
end

return TiePropertyInterface
