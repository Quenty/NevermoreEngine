--[=[
	@class RogueMultiplier
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local LinearValue = require("LinearValue")
local RogueModifierBase = require("RogueModifierBase")
local RogueModifierInterface = require("RogueModifierInterface")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local RogueMultiplier = setmetatable({}, RogueModifierBase)
RogueMultiplier.ClassName = "RogueMultiplier"
RogueMultiplier.__index = RogueMultiplier

function RogueMultiplier.new(valueObject, serviceBag)
	local self = setmetatable(RogueModifierBase.new(valueObject, serviceBag), RogueMultiplier)

	self._maid:GiveTask(RogueModifierInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueMultiplier:GetModifiedVersion(value)
	if not self._data.Enabled.Value then
		return value
	end

	local input = LinearValue.toLinearIfNeeded(value)
	local multiplier = LinearValue.toLinearIfNeeded(self._obj.Value)

	return LinearValue.fromLinearIfNeeded(input * multiplier)
end

function RogueMultiplier:GetInvertedVersion(value)
	if not self._data.Enabled.Value then
		return value
	end

	local input = LinearValue.toLinearIfNeeded(value)
	local multiplier = LinearValue.toLinearIfNeeded(self._obj.Value)

	return LinearValue.fromLinearIfNeeded(input / multiplier)
end

function RogueMultiplier:ObserveModifiedVersion(inputValue)
	return Rx.combineLatest({
		inputValue = inputValue,
		enabled = self._data.Enabled:Observe(),
		multiplier = RxInstanceUtils.observeProperty(self._obj, "Value"),
	}):Pipe({
		Rx.map(function(state)
			if not state.enabled then
				return state.inputValue
			end

			if state.inputValue and type(state.inputValue) == type(state.multiplier) then
				local input = LinearValue.toLinearIfNeeded(state.inputValue)
				local multiplier = LinearValue.toLinearIfNeeded(state.multiplier)

				return LinearValue.fromLinearIfNeeded(input * multiplier)
			else
				return state.inputValue
			end
		end),
		Rx.distinct(),
	})
end

return Binder.new("RogueMultiplier", RogueMultiplier)
