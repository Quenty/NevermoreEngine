--[=[
	@class RogueAdditive
]=]

local require = require(script.Parent.loader).load(script)

local RogueModifierBase = require("RogueModifierBase")
local RxInstanceUtils = require("RxInstanceUtils")
local Binder = require("Binder")
local Rx = require("Rx")
local LinearValue = require("LinearValue")
local RogueModifierInterface = require("RogueModifierInterface")

local RogueAdditive = setmetatable({}, RogueModifierBase)
RogueAdditive.ClassName = "RogueAdditive"
RogueAdditive.__index = RogueAdditive

function RogueAdditive.new(valueObject, serviceBag)
	local self = setmetatable(RogueModifierBase.new(valueObject, serviceBag), RogueAdditive)

	self._maid:GiveTask(RogueModifierInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueAdditive:GetModifiedVersion(value)
	local input = LinearValue.toLinearIfNeeded(value)
	local additive = LinearValue.toLinearIfNeeded(self._obj.Value)

	return LinearValue.fromLinearIfNeeded(input + additive)
end

function RogueAdditive:GetInvertedVersion(value)
	local input = LinearValue.toLinearIfNeeded(value)
	local additive = LinearValue.toLinearIfNeeded(self._obj.Value)

	return LinearValue.fromLinearIfNeeded(input - additive)
end

function RogueAdditive:ObserveModifiedVersion(inputValue)
	return Rx.combineLatest({
		inputValue = inputValue;
		additive = RxInstanceUtils.observeProperty(self._obj, "Value");
	}):Pipe({
		Rx.map(function(state)
			if state.inputValue and type(state.inputValue) == type(state.additive) then
				local input = LinearValue.toLinearIfNeeded(state.inputValue)
				local additive = LinearValue.toLinearIfNeeded(state.additive)

				return LinearValue.fromLinearIfNeeded(input + additive)
			else
				return state.inputValue
			end
		end);
		Rx.distinct();
	})
end

return Binder.new("RogueAdditive", RogueAdditive)