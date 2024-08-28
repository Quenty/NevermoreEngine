--[=[
	@class RogueMultiplier
]=]

local require = require(script.Parent.loader).load(script)

local RogueModifierBase = require("RogueModifierBase")
local Binder = require("Binder")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local LinearValue = require("LinearValue")
local RogueModifierInterface = require("RogueModifierInterface")

local RogueMultiplier = setmetatable({}, RogueModifierBase)
RogueMultiplier.ClassName = "RogueMultiplier"
RogueMultiplier.__index = RogueMultiplier

function RogueMultiplier.new(valueObject, serviceBag)
	local self = setmetatable(RogueModifierBase.new(valueObject, serviceBag), RogueMultiplier)

	self._maid:GiveTask(RogueModifierInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueMultiplier:GetModifiedVersion(value)
	local input = LinearValue.toLinearIfNeeded(value)
	local multiplier = LinearValue.toLinearIfNeeded(self._obj.Value)

	return LinearValue.fromLinearIfNeeded(input * multiplier)
end

function RogueMultiplier:GetInvertedVersion(value)
	local input = LinearValue.toLinearIfNeeded(value)
	local multiplier = LinearValue.toLinearIfNeeded(self._obj.Value)

	return LinearValue.fromLinearIfNeeded(input / multiplier)
end

function RogueMultiplier:ObserveModifiedVersion(inputValue)
	return Rx.combineLatest({
		inputValue = inputValue;
		multiplier = RxInstanceUtils.observeProperty(self._obj, "Value");
	}):Pipe({
		Rx.map(function(state)
			if state.inputValue and type(state.inputValue) == type(state.multiplier) then
				local input = LinearValue.toLinearIfNeeded(state.inputValue)
				local multiplier = LinearValue.toLinearIfNeeded(state.multiplier)

				return LinearValue.fromLinearIfNeeded(input * multiplier)
			else
				return state.inputValue
			end
		end);
		Rx.distinct();
	})
end

return Binder.new("RogueMultiplier", RogueMultiplier)