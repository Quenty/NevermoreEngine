--[=[
	@class RogueSetterProvider
]=]

local require = require(script.Parent.loader).load(script)

local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local RogueBindersShared = require("RogueBindersShared")
local BinderUtils = require("BinderUtils")
local RoguePropertyModifierUtils = require("RoguePropertyModifierUtils")
local RoguePropertyService = require("RoguePropertyService")
local ValueBaseUtils = require("ValueBaseUtils")

local RogueSetterProvider = {}
RogueSetterProvider.ServiceName = "RogueSetterProvider"

function RogueSetterProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._roguePropetyService = self._serviceBag:GetService(RoguePropertyService)
	self._rogueBinders = self._serviceBag:GetService(RogueBindersShared)

	self._roguePropetyService:AddProvider(self)
end

function RogueSetterProvider:GetBinder()
	return self._rogueBinders.RogueSetter
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

	self._rogueBinders.RogueSetter:Bind(obj)

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
	-- TODO: optimize this.
	return RxBrioUtils.flatCombineLatest({
		value = observeBaseValue;
		allSetters = self:_observeSettersBrio(propObj):Pipe({
			RxBrioUtils.flatMapBrio(function(item)
				return item:ObserveValue();
			end); -- this gets us a list of multipliers which should mutate pretty frequently.
			Rx.defaultsToNil;
		});
	}):Pipe({
		Rx.map(function(state)
			return self:GetModifiedVersion(propObj, rogueProperty, state.value)
		end);
	})
end

function RogueSetterProvider:_observeSettersBrio(propObj)
	return RxBinderUtils.observeBoundChildClassBrio(self._rogueBinders.RogueSetter, propObj)
end

function RogueSetterProvider:_getSetters(propObj)
	return BinderUtils.getChildren(self._rogueBinders.RogueSetter, propObj)
end

return RogueSetterProvider