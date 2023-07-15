--[=[
	@class RogueMultiplierProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local RogueBindersShared = require("RogueBindersShared")
local BinderUtils = require("BinderUtils")
local RoguePropertyModifierUtils = require("RoguePropertyModifierUtils")
local RoguePropertyService = require("RoguePropertyService")

local RogueMultiplierProvider = {}
RogueMultiplierProvider.ServiceName = "RogueMultiplierProvider"

function RogueMultiplierProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._roguePropetyService = self._serviceBag:GetService(RoguePropertyService)
	self._rogueBinders = self._serviceBag:GetService(RogueBindersShared)

	self._roguePropetyService:AddProvider(self)
end

function RogueMultiplierProvider:GetBinder()
	return self._rogueBinders.RogueMultiplier
end

function RogueMultiplierProvider:Create(multiplier, source)
	assert(type(multiplier) == "number", "Bad multiplier")
	assert(typeof(source) == "Instance" or source == nil, "Bad source")

	local obj = Instance.new("NumberValue")
	obj.Name = "Multiplier"
	obj.Value = multiplier

	if source then
		RoguePropertyModifierUtils.createSourceLink(obj, source)
	end

	if RunService:IsClient() then
		self._rogueBinders.RogueMultiplier:BindClient(obj)
	else
		self._rogueBinders.RogueMultiplier:Bind(obj)
	end

	return obj
end

function RogueMultiplierProvider:GetInvertedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local multiplier = 1

		for _, item in pairs(self:_getMultipliers(propObj)) do
			multiplier = multiplier*item:GetMultiplier()
		end

		return baseValue/multiplier
	else
		return baseValue
	end
end

function RogueMultiplierProvider:GetModifiedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local multiplier = 1

		for _, item in pairs(self:_getMultipliers(propObj)) do
			multiplier = multiplier*item:GetMultiplier()
		end

		return baseValue*multiplier
	else
		return baseValue
	end
end

function RogueMultiplierProvider:ObserveModifiedVersion(propObj, rogueProperty, observeBaseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		return RxBrioUtils.flatCombineLatest({
			value = observeBaseValue;
			multiplier = self:_observeMultipliersBrio(propObj):Pipe({
				RxBrioUtils.flatMapBrio(function(item)
					return item:ObserveMultiplier();
				end); -- this gets us a list of multipliers which should mutate pretty frequently.
				Rx.defaultsToNil;
			});
		}):Pipe({
			Rx.map(function(state)
				return self:GetModifiedVersion(propObj, rogueProperty, state.value)
			end);
		})
	else
		return observeBaseValue
	end
end

function RogueMultiplierProvider:_observeMultipliersBrio(propObj)
	return RxBinderUtils.observeBoundChildClassBrio(self._rogueBinders.RogueMultiplier, propObj)
end

function RogueMultiplierProvider:_getMultipliers(propObj)
	return BinderUtils.getChildren(self._rogueBinders.RogueMultiplier, propObj)
end

return RogueMultiplierProvider