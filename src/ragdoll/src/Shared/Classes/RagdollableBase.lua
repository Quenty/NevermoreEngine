--!strict
--[=[
	@class RagdollableBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Observable = require("Observable")
local Rx = require("Rx")
local RxSignal = require("RxSignal")

local RagdollableBase = setmetatable({}, BaseObject)
RagdollableBase.ClassName = "RagdollableBase"
RagdollableBase.__index = RagdollableBase

export type RagdollableBase =
	typeof(setmetatable(
		{} :: {
			Ragdolled: RxSignal.RxSignal<boolean>,
			Unragdolled: RxSignal.RxSignal<boolean>,
		},
		{} :: typeof({ __index = RagdollableBase })
	))
	& BaseObject.BaseObject

function RagdollableBase.new(humanoid: Humanoid): RagdollableBase
	local self: RagdollableBase = setmetatable(BaseObject.new(humanoid) :: any, RagdollableBase)

	self.Ragdolled = RxSignal.new(function(): any
		return (self:ObserveIsRagdolled() :: any):Pipe({
			Rx.skip(1),
			Rx.where(function(value): any
				return value == true
			end),
		})
	end) :: any

	self.Unragdolled = RxSignal.new(function(): any
		return (self:ObserveIsRagdolled() :: any):Pipe({
			Rx.skip(1),
			Rx.where(function(value): any
				return value == true
			end),
		})
	end) :: any

	return self
end

function RagdollableBase.Ragdoll(self: RagdollableBase): ()
	(self._obj :: Instance):AddTag("Ragdoll")
end

function RagdollableBase.Unragdoll(self: RagdollableBase): ()
	(self._obj :: Instance):RemoveTag("Ragdoll")
end

function RagdollableBase.ObserveIsRagdolled(self: RagdollableBase): Observable.Observable<boolean>
	return error("Not implemented")
end

function RagdollableBase.IsRagdolled(self: RagdollableBase): boolean
	return (self._obj :: Instance):HasTag("Ragdoll")
end

return RagdollableBase
