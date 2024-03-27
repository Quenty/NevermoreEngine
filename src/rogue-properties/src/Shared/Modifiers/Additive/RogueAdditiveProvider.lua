--[=[
	@class RogueAdditiveProvider
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

local RogueAdditiveProvider = {}
RogueAdditiveProvider.ServiceName = "RogueAdditiveProvider"

function RogueAdditiveProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._roguePropetyService = self._serviceBag:GetService(RoguePropertyService)
	self._rogueAdditiveBinder = self._serviceBag:GetService(require("RogueAdditive"))

	self._roguePropetyService:AddProvider(self)
end

function RogueAdditiveProvider:GetBinder()
	return self._rogueAdditiveBinder
end

function RogueAdditiveProvider:Create(additive, source)
	assert(type(additive) == "number", "Bad additive")
	assert(typeof(source) == "Instance" or source == nil, "Bad source")

	local obj = Instance.new("NumberValue")
	obj.Name = "Additive"
	obj.Value = additive

	if source then
		RoguePropertyModifierUtils.createSourceLink(obj, source)
	end

	if RunService:IsClient() then
		self._rogueAdditiveBinder:BindClient(obj)
	else
		self._rogueAdditiveBinder:Bind(obj)
	end

	return obj
end

function RogueAdditiveProvider:GetInvertedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		return baseValue - self:_getTotalAdditive(propObj)
	else
		return baseValue
	end
end

function RogueAdditiveProvider:GetModifiedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		return baseValue + self:_getTotalAdditive(propObj)
	else
		return baseValue
	end
end

function RogueAdditiveProvider:ObserveModifiedVersion(propObj, rogueProperty, observeBaseValue)
	assert(rogueProperty, "No rogueProperty")
	assert(Observable.isObservable(observeBaseValue), "Bad observeBaseValue")

	if rogueProperty:GetDefinition():GetValueType() == "number" then
		return RxBrioUtils.flatCombineLatest({
			baseValue = observeBaseValue;
			additive = self:_observeAddersBrio(propObj):Pipe({
				RxBrioUtils.flatMapBrio(function(item)
					return item:ObserveAdditive();
				end);
				RxBrioUtils.reduceToAliveList();
				RxBrioUtils.switchMapBrio(function(state)
					local additive = 0
					for _, item in pairs(state) do
						additive = additive + item
					end
					return Rx.of(additive)
				end);
				RxBrioUtils.emitOnDeath(0);
				Rx.distinct();
			});
		}):Pipe({
			Rx.map(function(state)
				return state.baseValue + state.additive
			end);
			Rx.distinct();
		})
	else
		return observeBaseValue
	end
end

function RogueAdditiveProvider:_observeAddersBrio(propObj)
	return RxBinderUtils.observeBoundChildClassBrio(self._rogueAdditiveBinder, propObj)
end

function RogueAdditiveProvider:_getTotalAdditive(propObj)
	local additive = 0
	for _, item in pairs(BinderUtils.getChildren(self._rogueAdditiveBinder, propObj)) do
		additive = additive + item:GetAdditive()
	end
	return additive
end

return RogueAdditiveProvider