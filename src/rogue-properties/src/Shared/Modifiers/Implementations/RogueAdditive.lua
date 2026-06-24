--!strict
--[=[
	@class RogueAdditive
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local LinearValue = require("LinearValue")
local Observable = require("Observable")
local RogueModifierBase = require("RogueModifierBase")
local RogueModifierInterface = require("RogueModifierInterface")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")

local RogueAdditive = setmetatable({}, RogueModifierBase)
RogueAdditive.ClassName = "RogueAdditive"
RogueAdditive.__index = RogueAdditive

export type RogueAdditive =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = RogueAdditive })))
	& RogueModifierBase.RogueModifierBase

function RogueAdditive.new(valueObject: ValueBase, serviceBag: ServiceBag.ServiceBag): RogueAdditive
	local self: RogueAdditive = setmetatable(RogueModifierBase.new(valueObject, serviceBag) :: any, RogueAdditive)

	self._maid:GiveTask(RogueModifierInterface:Implement(self._obj :: any, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueAdditive.GetModifiedVersion(self: RogueAdditive, value: any): any
	if not self._data.Enabled.Value then
		return value
	end

	local input = LinearValue.toLinearIfNeeded(value)
	local additive = LinearValue.toLinearIfNeeded((self._obj :: any).Value)

	return LinearValue.fromLinearIfNeeded((input :: any) + additive)
end

function RogueAdditive.GetInvertedVersion(self: RogueAdditive, value: any): any
	if not self._data.Enabled.Value then
		return value
	end

	local input = LinearValue.toLinearIfNeeded(value)
	local additive = LinearValue.toLinearIfNeeded((self._obj :: any).Value)

	return LinearValue.fromLinearIfNeeded((input :: any) - additive)
end

function RogueAdditive.ObserveModifiedVersion(
	self: RogueAdditive,
	inputValue: Observable.Observable<any>
): Observable.Observable<any>
	return (Rx.combineLatest({
		inputValue = inputValue,
		enabled = self._data.Enabled:Observe(),
		additive = RxInstanceUtils.observeProperty(self._obj :: any, "Value"),
	}) :: any):Pipe({
		Rx.map(function(state: any)
			if not state.enabled then
				return state.inputValue
			end

			if state.inputValue and type(state.inputValue) == type(state.additive) then
				local input = LinearValue.toLinearIfNeeded(state.inputValue)
				local additive = LinearValue.toLinearIfNeeded(state.additive)

				return LinearValue.fromLinearIfNeeded((input :: any) + additive)
			else
				return state.inputValue
			end
		end),
		Rx.distinct(),
	} :: { any }) :: any
end

return Binder.new("RogueAdditive", RogueAdditive :: any) :: Binder.Binder<RogueAdditive>
