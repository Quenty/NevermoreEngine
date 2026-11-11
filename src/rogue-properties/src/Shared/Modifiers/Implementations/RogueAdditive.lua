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

function RogueAdditive.new(valueObject: Instance, serviceBag: ServiceBag.ServiceBag): RogueAdditive
	local self: RogueAdditive = setmetatable(RogueModifierBase.new(valueObject, serviceBag) :: any, RogueAdditive)

	self._maid:GiveTask((RogueModifierInterface :: any):Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueAdditive.GetModifiedVersion(self: RogueAdditive, value: any): any
	if not self._data.Enabled.Value then
		return value
	end

	local input = LinearValue.toLinearIfNeeded(value) :: any
	local additive = LinearValue.toLinearIfNeeded((self._obj :: any).Value) :: any

	return LinearValue.fromLinearIfNeeded(input + additive)
end

function RogueAdditive.GetInvertedVersion(self: RogueAdditive, value: any): any
	if not self._data.Enabled.Value then
		return value
	end

	local input = LinearValue.toLinearIfNeeded(value) :: any
	local additive = LinearValue.toLinearIfNeeded((self._obj :: any).Value) :: any

	return LinearValue.fromLinearIfNeeded(input - additive)
end

function RogueAdditive.ObserveModifiedVersion(self: RogueAdditive, inputValue: any): Observable.Observable<any>
	local combined = Rx.combineLatest({
		inputValue = inputValue,
		enabled = self._data.Enabled:Observe(),
		additive = RxInstanceUtils.observeProperty(self._obj :: any, "Value"),
	})

	return (combined :: any):Pipe({
		Rx.map(function(state: any)
			if not state.enabled then
				return state.inputValue
			end

			if state.inputValue and type(state.inputValue) == type(state.additive) then
				local input = LinearValue.toLinearIfNeeded(state.inputValue) :: any
				local additive = LinearValue.toLinearIfNeeded(state.additive) :: any

				return LinearValue.fromLinearIfNeeded(input + additive)
			else
				return state.inputValue
			end
		end) :: any,
		Rx.distinct() :: any,
	})
end

return Binder.new("RogueAdditive", RogueAdditive :: any) :: Binder.Binder<RogueAdditive>
