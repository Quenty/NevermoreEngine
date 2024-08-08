--[=[
	@class RogueProperty
]=]

local require = require(script.Parent.loader).load(script)

local RogueAdditiveProvider = require("RogueAdditiveProvider")
local RogueMultiplierProvider = require("RogueMultiplierProvider")
local RoguePropertyBinderGroups = require("RoguePropertyBinderGroups")
local RoguePropertyModifierUtils = require("RoguePropertyModifierUtils")
local RoguePropertyService = require("RoguePropertyService")
local RoguePropertyUtils = require("RoguePropertyUtils")
local RogueSetterProvider = require("RogueSetterProvider")
local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxValueBaseUtils = require("RxValueBaseUtils")
local RxSignal = require("RxSignal")

local RogueProperty = {}
RogueProperty.ClassName = "RogueProperty"
RogueProperty.__index = RogueProperty

function RogueProperty.new(adornee, serviceBag, definition)
	local self = {}

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._roguePropertyBinderGroups = self._serviceBag:GetService(RoguePropertyBinderGroups)
	self._roguePropertyService = self._serviceBag:GetService(RoguePropertyService)

	self._adornee = assert(adornee, "Bad adornee")
	self._definition = assert(definition, "Bad definition")
	self._canInitialize = false

	setmetatable(self, RogueProperty)

	return self
end

function RogueProperty:SetCanInitialize(canInitialize)
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
	-- TODO: Consider applying inverted chain here
	for _, item in pairs(self._roguePropertyService:GetProviders()) do
		current = item:GetInvertedVersion(baseValue, self, current)
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

	for _, item in pairs(self._roguePropertyService:GetProviders()) do
		current = item:GetModifiedVersion(propObj, self, current)
	end

	return current
end

function RogueProperty:GetDefinition()
	return self._definition
end

function RogueProperty:ObserveModifiersBrio()
	return self:_observeBaseValueBrio()
		:Pipe({
			RxBrioUtils.flatMapBrio(function(baseValue)
				if baseValue then
					return RxBinderUtils.observeBoundChildClassesBrio(self._roguePropertyBinderGroups.RogueModifiers:GetBinders(), baseValue)
				else
					return Rx.EMPTY
				end
			end);
		})
end

function RogueProperty:ObserveSourcesBrio()
	return self:ObserveModifiersBrio()
		:Pipe({
			RxBrioUtils.flatMapBrio(function(rogueModifier)
				return RoguePropertyModifierUtils.observeSourceLinksBrio(rogueModifier:GetObject())
			end);
		})
end

function RogueProperty:Observe()
	return self._roguePropertyService:ObserveProviderList():Pipe({
		RxBrioUtils.toBrio();
		RxBrioUtils.switchMapBrio(function()
			return self:_observeBaseValueBrio()
		end);
		RxBrioUtils.switchMapBrio(function(baseValue)
			local current
			if baseValue then
				current = RxValueBaseUtils.observeValue(baseValue)

				if self._definition:GetValueType() == "table" then
					current = current:Pipe({
						Rx.map(function(value)
							return self:_decodeValue(value)
						end)
					})
				end
			else
				current = Rx.of(self._definition:GetDefaultValue())
			end

			for _, provider in pairs(self._roguePropertyService:GetProviders()) do
				current = provider:ObserveModifiedVersion(baseValue, self, current)
			end

			return current
		end);
		RxBrioUtils.emitOnDeath(self._definition:GetDefaultValue());
		Rx.defaultsTo(self._definition:GetDefaultValue());
		Rx.distinct();
	})
end

function RogueProperty:CreateMultiplier(amount, source)
	assert(type(amount) == "number", "Bad amount")

	local provider = self._serviceBag:GetService(RogueMultiplierProvider)
	local baseValue = self:GetBaseValueObject()

	if not baseValue then
		warn(string.format("[RogueProperty.CreateMultiplier] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
	end

	local multiplier = provider:Create(amount, source)
	multiplier.Parent = baseValue

	return multiplier
end

function RogueProperty:CreateAdditive(amount, source)
	assert(type(amount) == "number", "Bad amount")

	local provider = self._serviceBag:GetService(RogueAdditiveProvider)
	local baseValue = self:GetBaseValueObject()

	if not baseValue then
		warn(string.format("[RogueProperty.CreateAdditive] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
	end

	local multiplier = provider:Create(amount, source)
	multiplier.Parent = baseValue

	return multiplier
end

function RogueProperty:CreateSetter(value, source)
	local provider = self._serviceBag:GetService(RogueSetterProvider)
	local baseValue = self:GetBaseValueObject()

	if not baseValue then
		warn(string.format("[RogueProperty.CreateSetter] - Failed to get the baseValue for %q on %q", self._definition:GetFullName(), self._adornee:GetFullName()))
	end

	local setter = provider:Create(value, source)
	setter.Parent = baseValue

	return setter
end

function RogueProperty:_observeModifiersBrio()
	return RxBinderUtils.observeBoundChildClassesBrio(self._roguePropertyBinderGroups.RogueModifiers:GetAll(), self._adornee)
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