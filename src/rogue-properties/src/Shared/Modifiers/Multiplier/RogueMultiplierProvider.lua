--[=[
	@class RogueMultiplierProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local BinderUtils = require("BinderUtils")
local RoguePropertyModifierUtils = require("RoguePropertyModifierUtils")
local RoguePropertyService = require("RoguePropertyService")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")

local RogueMultiplierProvider = {}
RogueMultiplierProvider.ServiceName = "RogueMultiplierProvider"

function RogueMultiplierProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._roguePropetyService = self._serviceBag:GetService(RoguePropertyService)
	self._rogueMultiplierBinder = self._serviceBag:GetService(require("RogueMultiplier"))

	self._roguePropetyService:AddProvider(self)
end

function RogueMultiplierProvider:GetBinder()
	return self._rogueMultiplierBinder
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
		self._rogueMultiplierBinder:BindClient(obj)
	else
		self._rogueMultiplierBinder:Bind(obj)
	end

	return obj
end

function RogueMultiplierProvider:GetInvertedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local multiplier = self:_getTotalMultiplier(propObj)

		return baseValue/multiplier
	else
		return baseValue
	end
end

function RogueMultiplierProvider:GetModifiedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local multiplier = self:_getTotalMultiplier(propObj)

		return baseValue*multiplier
	else
		return baseValue
	end
end

function RogueMultiplierProvider:ObserveModifiedVersion(propObj, rogueProperty, observeBaseValue)
	assert(rogueProperty, "No rogueProperty")
	assert(Observable.isObservable(observeBaseValue), "Bad observeBaseValue")

	if rogueProperty:GetDefinition():GetValueType() == "number" then
		return RxBrioUtils.flatCombineLatest({
			baseValue = observeBaseValue;
			multiplier = self:_observeMultipliersBrio(propObj):Pipe({
				RxBrioUtils.flatMapBrio(function(item)
					return item:ObserveMultiplier();
				end);
				RxBrioUtils.reduceToAliveList();
				RxBrioUtils.switchMapBrio(function(state)
					local multiplier = 1
					for _, item in pairs(state) do
						multiplier = multiplier*item
					end
					return Rx.of(multiplier)
				end);
				RxBrioUtils.emitOnDeath(1);
				Rx.distinct();
			});
		}):Pipe({
			Rx.map(function(state)
				return state.baseValue*state.multiplier
			end);
			Rx.distinct();
		})
	else
		return observeBaseValue
	end
end

function RogueMultiplierProvider:_observeMultipliersBrio(propObj)
	return RxBinderUtils.observeBoundChildClassBrio(self._rogueMultiplierBinder, propObj)
end

function RogueMultiplierProvider:_getTotalMultiplier(propObj)
	local multiplier = 1
	for _, item in pairs(BinderUtils.getChildren(self._rogueMultiplierBinder, propObj)) do
		multiplier = multiplier*item:GetMultiplier()
	end
	return multiplier
end

return RogueMultiplierProvider