--!strict
--[=[
	Should be bound to any humanoid that is ragdollable. This class exports a [Binder].
	@server
	@class Ragdollable
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Motor6DStackHumanoid = require("Motor6DStackHumanoid")
local Observable = require("Observable")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")
local RagdollAdditionalAttachmentUtils = require("RagdollAdditionalAttachmentUtils")
local RagdollBallSocketUtils = require("RagdollBallSocketUtils")
local RagdollCollisionUtils = require("RagdollCollisionUtils")
local RagdollMotorUtils = require("RagdollMotorUtils")
local RagdollableBase = require("RagdollableBase")
local RagdollableInterface = require("RagdollableInterface")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxRagdollUtils = require("RxRagdollUtils")
local ServiceBag = require("ServiceBag")

local Ragdollable = setmetatable({}, RagdollableBase)
Ragdollable.ClassName = "Ragdollable"
Ragdollable.__index = Ragdollable

export type Ragdollable =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: typeof(Ragdoll),
		},
		{} :: typeof({ __index = Ragdollable })
	))
	& RagdollableBase.RagdollableBase

--[=[
	Constructs a new Ragdollable. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return Ragdollable
]=]
function Ragdollable.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): Ragdollable
	local self: Ragdollable = setmetatable(RagdollableBase.new(humanoid) :: any, Ragdollable)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)

	Motor6DStackHumanoid:Tag(self._obj :: Instance)

	-- Ensure predefined physics rig immediatelly on the server.
	-- We do this so during replication loop-back there's no chance of death.
	self._maid:GiveTask((RxBrioUtils :: any)
		.flatCombineLatest({
			character = RxRagdollUtils.observeCharacterBrio(self._obj :: Humanoid),
			rigType = RxRagdollUtils.observeRigType(self._obj :: Humanoid),
		})
		:Subscribe(function(state)
			if state.character and state.rigType then
				local maid = Maid.new()

				maid:GiveTask(
					RagdollAdditionalAttachmentUtils.ensureAdditionalAttachments(state.character, state.rigType)
				)
				maid:GiveTask(RagdollBallSocketUtils.ensureBallSockets(state.character, state.rigType))
				maid:GiveTask(RagdollCollisionUtils.ensureNoCollides(state.character, state.rigType))

				-- Not super guarded against race conditions but it should be fine, as this is for debugging.
				RagdollMotorUtils.initMotorAttributes(state.character, state.rigType)

				self._maid._configure = maid
			else
				self._maid._configure = nil
			end
		end))

	self._maid:GiveTask(self._ragdollBinder:ObserveInstance(self._obj :: Instance, function()
		self:_onRagdollChanged()
	end))
	self:_onRagdollChanged()

	self._maid:GiveTask((RagdollableInterface :: any).Server:Implement(self._obj, self))

	return self
end

function Ragdollable.ObserveIsRagdolled(self: Ragdollable): Observable.Observable<boolean>
	return (self._ragdollBinder:Observe(self._obj :: Instance) :: any):Pipe({
		Rx.map(function(value): any
			return value and true or false
		end),
	})
end

function Ragdollable._onRagdollChanged(self: Ragdollable): ()
	if self._ragdollBinder:Get(self._obj :: Instance) then
		self:_setRagdollEnabled(true)
	else
		self:_setRagdollEnabled(false)
	end
end

function Ragdollable._setRagdollEnabled(self: Ragdollable, isEnabled: boolean): ()
	if isEnabled then
		if self._maid._ragdoll then
			return
		end

		self._maid._ragdoll = RxRagdollUtils.runLocal(self._obj :: Humanoid)
	else
		self._maid._ragdoll = nil
	end
end

return PlayerHumanoidBinder.new(
		"Ragdollable",
		Ragdollable :: any
	) :: PlayerHumanoidBinder.PlayerHumanoidBinder<Ragdollable>
