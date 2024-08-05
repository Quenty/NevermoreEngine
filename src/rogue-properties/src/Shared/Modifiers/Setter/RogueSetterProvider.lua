--[=[
	@class RogueSetterProvider
]=]

local require = require(script.Parent.loader).load(script)

local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local BinderUtils = require("BinderUtils")
local RoguePropertyModifierUtils = require("RoguePropertyModifierUtils")
local RoguePropertyService = require("RoguePropertyService")
local ValueBaseUtils = require("ValueBaseUtils")
local Observable = require("Observable")

local RogueSetterProvider = {}
RogueSetterProvider.ServiceName = "RogueSetterProvider"

function RogueSetterProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._roguePropetyService = self._serviceBag:GetService(RoguePropertyService)
	self._rogueSetterBinder = self._serviceBag:GetService(require("RogueSetter"))

	self._roguePropetyService:AddProvider(self)
end

function RogueSetterProvider:GetBinder()
	return self._rogueSetterBinder
end

function RogueSetterProvider:Create(value, source)
	assert(typeof(source) == "Instance" or source == nil, "Bad source")

	local className = ValueBaseUtils.getClassNameFromType(typeof(value))
	if not className then
		error(string.format("[RogueSetterProvider] - Can't set to type %q", typeof(value)))
		return nil
	end

	local obj = Instance.new(className)
	obj.Name = "Setter"
	obj.Value = value

	if source then
		RoguePropertyModifierUtils.createSourceLink(obj, source)
	end

	self._rogueSetterBinder:Bind(obj)

	return obj
end

function RogueSetterProvider:GetInvertedVersion(_propObj, _rogueProperty, baseValue)
	-- TODO: discard previous value chain
	return baseValue
end

function RogueSetterProvider:GetModifiedVersion(propObj, _rogueProperty, baseValue)
	-- Just return the first value
	for _, item in pairs(self:_getSetters(propObj)) do
		return item:GetValue()
	end

	return baseValue
end

function RogueSetterProvider:ObserveModifiedVersion(propObj, rogueProperty, observeBaseValue)
	assert(rogueProperty, "No rogueProperty")
	assert(Observable.isObservable(observeBaseValue), "Bad observeBaseValue")

	-- TODO: optimize this.
	return RxBrioUtils.flatCombineLatest({
		value = observeBaseValue;
		prioritySetter = self:_observeSettersBrio(propObj):Pipe({
			RxBrioUtils.flatMapBrio(function(item)
				return item:ObserveValue();
			end);
			RxBrioUtils.reduceToAliveList();
			RxBrioUtils.switchMapBrio(function(state)
				local lastSetter = nil
				for _, item in pairs(state) do
					lastSetter = item
				end
				return Rx.of(lastSetter)
			end);
			-- TODO: Emit token instead
			RxBrioUtils.emitOnDeath(nil);
			Rx.distinct();
		});
	}):Pipe({
		Rx.map(function(state)
			if state.prioritySetter ~= nil then
				return state.prioritySetter
			else
				return state.value
			end
		end);
		Rx.distinct();
	})
end

function RogueSetterProvider:_observeSettersBrio(propObj)
	return RxBinderUtils.observeBoundChildClassBrio(self._rogueSetterBinder, propObj)
end

function RogueSetterProvider:_getSetters(propObj)
	return BinderUtils.getChildren(self._rogueSetterBinder, propObj)
end

return RogueSetterProvider