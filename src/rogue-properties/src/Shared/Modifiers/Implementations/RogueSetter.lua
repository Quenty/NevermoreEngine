--!strict
--[=[
	@class RogueSetter
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local RogueModifierBase = require("RogueModifierBase")
local RogueModifierInterface = require("RogueModifierInterface")
local Rx = require("Rx")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ServiceBag = require("ServiceBag")

local RogueSetter = setmetatable({}, RogueModifierBase)
RogueSetter.ClassName = "RogueSetter"
RogueSetter.__index = RogueSetter

export type RogueSetter =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = RogueSetter })))
	& RogueModifierBase.RogueModifierBase

function RogueSetter.new(valueObject: Instance, serviceBag: ServiceBag.ServiceBag): RogueSetter
	local self: RogueSetter = setmetatable(RogueModifierBase.new(valueObject, serviceBag) :: any, RogueSetter)

	self._maid:GiveTask((RogueModifierInterface :: any):Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueSetter.GetModifiedVersion(self: RogueSetter, value: any): any
	if self._data.Enabled.Value then
		return (self._obj :: any).Value
	else
		return value
	end
end

function RogueSetter.ObserveModifiedVersion(self: RogueSetter, inputValue: any): any
	return (self._data.Enabled:Observe() :: any):Pipe({
		Rx.switchMap(function(enabled): any
			if enabled then
				return RxValueBaseUtils.observeValue(self._obj :: any)
			else
				return inputValue
			end
		end),
		Rx.distinct(),
	} :: { any })
end

function RogueSetter.GetInvertedVersion(self: RogueSetter, value: any, initialValue: any): any
	if not self._data.Enabled.Value then
		return value
	end

	return initialValue
end

return Binder.new("RogueSetter", RogueSetter :: any) :: Binder.Binder<RogueSetter>
