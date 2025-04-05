--[=[
	@class RogueProperty
]=]

local require = require(script.Parent.loader).load(script)

local RogueAdditive = require("RogueAdditive")
local RogueModifierInterface = require("RogueModifierInterface")
local RogueMultiplier = require("RogueMultiplier")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local RoguePropertyUtils = require("RoguePropertyUtils")
local RogueSetter = require("RogueSetter")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxSignal = require("RxSignal")
local ValueBaseUtils = require("ValueBaseUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSortedList = require("ObservableSortedList")

local RogueProperty = {}
RogueProperty.ClassName = "RogueProperty"
RogueProperty.__index = RogueProperty

function RogueProperty.new(adornee, serviceBag, definition)
	local self = {}

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._adornee = assert(adornee, "Bad adornee")
	self._definition = assert(definition, "Bad definition")
	self._canInitialize = false

	return setmetatable(self, RogueProperty)
end

function RogueProperty:SetCanInitialize(canInitialize: boolean)
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	if rawget(self, "_canInitialize") ~= canInitialize then
		rawset(self, "_canInitialize", canInitialize)

		if canInitialize then
			self:GetBaseValueObject()
		end
	end
end

function RogueProperty:GetAdornee()
	return self._adornee
end

function RogueProperty:CanInitialize()
	return rawget(self, "_canInitialize")
end

function RogueProperty:GetBaseValueObject()
	local cached = rawget(self, "_baseValueCache")
	local adornee = rawget(self, "_adornee")
	local definition = rawget(self, "_definition")

	if cached and cached:IsDescendantOf(adornee) then
		return cached
	end

	local parent
	local parentDefinition = definition:GetParentPropertyDefinition()

	if parentDefinition then
		parent = parentDefinition:GetContainer(adornee, self:CanInitialize())
	else
		parent = adornee
	end

	if not parent then
		return nil
	end

	local found
	if self:CanInitialize() then
		found = definition:GetOrCreateInstance(parent)
	else
		found = parent:FindFirstChild(definition:GetName())
	end

	-- Store cache
	rawset(self, "_baseValueCache", found)

	return found
end

function RogueProperty:_observeBaseValueBrio()
	local parentDefinition = self._definition:GetParentPropertyDefinition()
	if parentDefinition then
		return parentDefinition:ObserveContainerBrio(self._adornee, self:CanInitialize())
			:Pipe({
				RxBrioUtils.switchMapBrio(function(container)
					return RxInstanceUtils.observeLastNamedChildBrio(
						container,
						self._definition:GetStorageInstanceType(),
						self._definition:GetName())
				end);
			})
	else
		return RxInstanceUtils.observeLastNamedChildBrio(self._adornee, self._definition:GetStorageInstanceType(), self._definition:GetName())
	end
end

function RogueProperty:SetBaseValue(value)
	assert(self._definition:CanAssign(value, false)) -- This has a good error message

	local baseValue = self:GetBaseValueObject()
	if baseValue then
		baseValue.Value = self:_encodeValue(value)
	else
		warn(string.format("[RogueProperty.SetBaseValue] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
	end
end

function RogueProperty:SetValue(value)
	assert(self._definition:CanAssign(value, false)) -- This has a good error message

	local baseValue = self:GetBaseValueObject()
	if not baseValue then
		warn(string.format("[RogueProperty.SetValue] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
		return
	end

	local current = value

	local modifiers = self:GetRogueModifiers()
	for i=#modifiers, 1, -1 do
		current = modifiers[i]:GetInvertedVersion(current, value)
	end

	baseValue.Value = self:_encodeValue(current)
end

function RogueProperty:GetBaseValue()
	local baseValue = self:GetBaseValueObject()
	if baseValue then
		return self:_decodeValue(baseValue.Value)
	else
		return self:_decodeValue(self._definition:GetEncodedDefaultValue())
	end
end

function RogueProperty:GetValue()
	local propObj = self:GetBaseValueObject()
	if not propObj then
		return self._definition:GetDefaultValue()
	end

	local current = self:_decodeValue(propObj.Value)

	for _, rogueModifier in self:GetRogueModifiers() do
		current = rogueModifier:GetModifiedVersion(current)
	end

	return current
end

function RogueProperty:GetDefinition()
	return self._definition
end

function RogueProperty:GetRogueModifiers()
	local propObj = self:GetBaseValueObject()
	if not propObj then
		return {}
	end

	local found = RogueModifierInterface:GetChildren(propObj)

	local orders = {}
	for _, item in found do
		orders[item] = item.Order.Value
	end
	table.sort(found, function(a, b)
		return orders[a] < orders[b]
	end)

	return found
end

function RogueProperty:_observeModifierSortedList()
	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local sortedList = topMaid:Add(ObservableSortedList.new())

		topMaid:GiveTask(self:_observeBaseValueBrio()
			:Pipe({
				RxBrioUtils.flatMapBrio(function(baseValue)
					return RogueModifierInterface:ObserveChildrenBrio(baseValue)
				end),
			})
			:Subscribe(function(brio)
				if brio:IsDead() then
					return
				end
				local maid, rogueModifier = brio:ToMaidAndValue()
				maid:GiveTask(sortedList:Add(rogueModifier, rogueModifier.Order:Observe()))
			end))

		sub:Fire(sortedList)

		return topMaid
	end):Pipe({
		Rx.cache(),
	})
end

function RogueProperty:Observe()
	local observeInitialValue = self:_observeBaseValueBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(baseValue)
			return RxInstanceUtils.observeProperty(baseValue, "Value")
		end),
		RxBrioUtils.emitOnDeath(self._definition:GetDefaultValue()),
		Rx.defaultsTo(self._definition:GetDefaultValue()),
		Rx.distinct(),
	})

	return self:_observeModifierSortedList():Pipe({
		Rx.switchMap(function(sortedList)
		return sortedList:Observe()
		end);
		Rx.switchMap(function(rogueModifierList)
		local current = observeInitialValue
			for _, rogueModifier in rogueModifierList do
				current = rogueModifier:ObserveModifiedVersion(current)
			end
			return current
		end);
	})
end

function RogueProperty:ObserveBrio(predicate)
	return self:Observe():Pipe({
		RxBrioUtils.switchToBrio(predicate)
	})
end

function RogueProperty:CreateMultiplier(amount, source)
	assert(type(amount) == "number", "Bad amount")

	local baseValue = self:GetBaseValueObject()
	if not baseValue then
		warn(string.format("[RogueProperty.CreateMultiplier] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
	end

	local className = ValueBaseUtils.getClassNameFromType(typeof(amount))
	if not className then
		error(string.format("[RogueProperty.CreateMultiplier] - Can't set to type %q", typeof(amount)))
		return nil
	end

	local multiplier = Instance.new(className)
	multiplier.Name = "Multiplier"
	multiplier.Value = amount

	local data = RoguePropertyModifierData:Create(multiplier)
	data.Order.Value = 2
	data.RoguePropertySourceLink.Value = source

	RogueMultiplier:Tag(multiplier)

	multiplier.Parent = baseValue

	return multiplier
end

function RogueProperty:CreateAdditive(amount: number, source)
	assert(type(amount) == "number", "Bad amount")

	local baseValue = self:GetBaseValueObject()
	if not baseValue then
		warn(string.format("[RogueProperty.CreateAdditive] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
		return nil
	end

	local className = ValueBaseUtils.getClassNameFromType(typeof(amount))
	if not className then
		error(string.format("[RogueProperty.CreateAdditive] - Can't set to type %q", typeof(amount)))
		return nil
	end

	local additive = Instance.new(className)
	additive.Name = "Additive"
	additive.Value = amount

	local data = RoguePropertyModifierData:Create(additive)
	data.Order.Value = 1
	data.RoguePropertySourceLink.Value = source

	RogueAdditive:Tag(additive)

	additive.Parent = baseValue

	return additive
end

function RogueProperty:GetNamedAdditive(name, source)
	local baseValue = self:GetBaseValueObject()
	if not baseValue then
		warn(string.format("[RogueProperty.GetNamedAdditive] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
		return nil
	end

	local searchName = name .. "Additive"

	local found = baseValue:FindFirstChild(searchName)
	if found then
		return found
	end

	local created = self:CreateAdditive(0, source)
	created.Name = searchName
	return created
end

function RogueProperty:CreateSetter(value, source)
	local baseValue = self:GetBaseValueObject()
	if not baseValue then
		warn(string.format("[RogueProperty.CreateSetter] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
		return nil
	end

	local className = ValueBaseUtils.getClassNameFromType(typeof(value))
	if not className then
		error(string.format("[RogueProperty.CreateSetter] - Can't set to type %q", typeof(value)))
		return nil
	end

	local setter = Instance.new(className)
	setter.Name = "Setter"
	setter.Value = value

	local data = RoguePropertyModifierData:Create(setter)
	data.Order.Value = 0
	data.RoguePropertySourceLink.Value = source

	RogueSetter:Tag(setter)

	setter.Parent = baseValue

	return setter
end

function RogueProperty:__index(index)
	if index == "Value" then
		return self:GetValue()
	elseif index == "Changed" then
		return self:GetChangedEvent()
	elseif RogueProperty[index] then
		return RogueProperty[index]
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function RogueProperty:__newindex(index, value)
	if index == "Value" then
		self:SetValue(value)
	elseif index == "Changed" then
		error("Cannot set .Changed event")
	elseif RogueProperty[index] then
		error(string.format("Cannot set %q", tostring(index)))
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function RogueProperty:_decodeValue(current)
	return RoguePropertyUtils.decodeProperty(self._definition, current)
end

function RogueProperty:_encodeValue(current)
	return RoguePropertyUtils.encodeProperty(self._definition, current)
end

function RogueProperty:GetChangedEvent()
	return RxSignal.new(self:Observe():Pipe({
		Rx.skip(1)
	}))
end

return RogueProperty