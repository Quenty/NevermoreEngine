--[=[
	@class RogueSetter
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local RogueModifierBase = require("RogueModifierBase")
local RogueModifierInterface = require("RogueModifierInterface")
local Rx = require("Rx")
local RxValueBaseUtils = require("RxValueBaseUtils")

local RogueSetter = setmetatable({}, RogueModifierBase)
RogueSetter.ClassName = "RogueSetter"
RogueSetter.__index = RogueSetter

function RogueSetter.new(valueObject, serviceBag)
	local self = setmetatable(RogueModifierBase.new(valueObject, serviceBag), RogueSetter)

	self._maid:GiveTask(RogueModifierInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueSetter:GetModifiedVersion(value)
	if self._data.Enabled.Value then
		return self._obj.Value
	else
		return value
	end
end

function RogueSetter:ObserveModifiedVersion(inputValue)
	return self._data.Enabled:Observe():Pipe({
		Rx.switchMap(function(enabled)
			if enabled then
				return RxValueBaseUtils.observeValue(self._obj)
			else
				return inputValue
			end
		end),
		Rx.distinct(),
	})
end

function RogueSetter:GetInvertedVersion(value, initialValue)
	if not self._data.Enabled.Value then
		return value
	end

	return initialValue
end

return Binder.new("RogueSetter", RogueSetter)
