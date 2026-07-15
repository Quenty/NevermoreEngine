--!strict
--[=[
	When a humanoid is tagged with this, it will unragdoll automatically. This class exports a [Binder].
	@server
	@class UnragdollAutomatically
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")
local RagdollHumanoidOnFall = require("RagdollHumanoidOnFall")
local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")
local UnragdollAutomaticallyConstants = require("UnragdollAutomaticallyConstants")
local cancellableDelay = require("cancellableDelay")

local UnragdollAutomatically = setmetatable({}, BaseObject)
UnragdollAutomatically.ClassName = "UnragdollAutomatically"
UnragdollAutomatically.__index = UnragdollAutomatically

export type UnragdollAutomatically =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: typeof(Ragdoll),
			_ragdollHumanoidOnFallBinder: typeof(RagdollHumanoidOnFall),
			_player: Player?,
			_unragdollAutomatically: AttributeValue.AttributeValue<boolean>,
			_unragdollAutomaticTime: AttributeValue.AttributeValue<number>,
		},
		{} :: typeof({ __index = UnragdollAutomatically })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new UnragdollAutomatically. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return UnragdollAutomatically
]=]
function UnragdollAutomatically.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): UnragdollAutomatically
	local self: UnragdollAutomatically = setmetatable(BaseObject.new(humanoid) :: any, UnragdollAutomatically)

	self._serviceBag = assert(serviceBag, "Bad serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)
	self._ragdollHumanoidOnFallBinder = self._serviceBag:GetService(RagdollHumanoidOnFall)
	self._player = CharacterUtils.getPlayerFromCharacter(self._obj :: Humanoid)

	self._unragdollAutomatically = AttributeValue.new(
		self._obj :: Instance,
		UnragdollAutomaticallyConstants.UNRAGDOLL_AUTOMATICALLY_ATTRIBUTE,
		true
	)
	self._unragdollAutomaticTime =
		AttributeValue.new(self._obj :: Instance, UnragdollAutomaticallyConstants.UNRAGDOLL_AUTOMATIC_TIME_ATTRIBUTE, 5)

	self._maid:GiveTask(self._ragdollBinder:ObserveInstance(self._obj :: Instance, function()
		self:_handleRagdollChanged(self._maid)
	end))
	self:_handleRagdollChanged(self._maid)

	return self
end

function UnragdollAutomatically._handleRagdollChanged(self: UnragdollAutomatically, maid: Maid.Maid): ()
	if self._ragdollBinder:Get(self._obj :: Instance) then
		maid._unragdoll = (self:_observeCanUnragdollTimer() :: any)
			:Pipe({
				Rx.switchMap(function(state): any
					if state then
						return self:_observeAlive()
					else
						return Rx.of(false)
					end
				end) :: any,
				Rx.distinct() :: any,
			})
			:Subscribe(function(canUnragdoll)
				if canUnragdoll then
					self._ragdollBinder:Unbind(self._obj :: Instance)
				end
			end)
	else
		maid._unragdoll = nil
	end
end

function UnragdollAutomatically._observeAlive(self: UnragdollAutomatically): Observable.Observable<boolean>
	return (RxInstanceUtils.observeProperty(self._obj :: Instance, "Health") :: any):Pipe({
		Rx.map(function(health): any
			return health > 0
		end) :: any,
		Rx.distinct() :: any,
	})
end

function UnragdollAutomatically._observeCanUnragdollTimer(self: UnragdollAutomatically): Observable.Observable<boolean>
	return Observable.new(function(sub): any
		local maid = Maid.new()

		local startTime = os.clock()
		local isReady = Instance.new("BoolValue")
		isReady.Value = false
		maid:GiveTask(isReady)

		maid:GiveTask((RxBrioUtils :: any)
			.flatCombineLatest({
				canUnragdoll = (RxBrioUtils.flatCombineLatest({
					enabled = self._unragdollAutomatically:Observe(),
					isFallingRagdoll = self:_observeIsFallingRagdoll(),
				}) :: any):Pipe({
					Rx.map(function(state): any
						return state.enabled and not state.isFallingRagdoll
					end) :: any,
					Rx.distinct() :: any,
					Rx.tap(function(canUnragdoll): ()
						-- Ensure we reset timer if we change state
						if canUnragdoll then
							startTime = os.clock()
						end
					end) :: any,
				}),
				time = self._unragdollAutomaticTime:Observe(),
			})
			:Subscribe(function(state: any)
				if state.canUnragdoll then
					maid._deferred = nil

					local timeElapsed = os.clock() - startTime
					local remainingTime = state.time - timeElapsed
					if remainingTime <= 0 then
						isReady.Value = true
					else
						isReady.Value = false
						maid._deferred = cancellableDelay(remainingTime, function()
							isReady.Value = true
						end)
					end
				else
					isReady.Value = false
					maid._deferred = nil
				end
			end))

		maid:GiveTask(isReady.Changed:Connect(function()
			sub:Fire(isReady.Value)
		end))
		sub:Fire(isReady.Value)

		return maid
	end) :: any
end

function UnragdollAutomatically._observeIsFallingRagdoll(self: UnragdollAutomatically): Observable.Observable<boolean>
	return (RxBinderUtils.observeBoundClassBrio(self._ragdollHumanoidOnFallBinder, self._obj :: Instance) :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(ragdollHumanoidOnFall): any
			return ragdollHumanoidOnFall:ObserveIsFalling()
		end) :: any,
		RxBrioUtils.emitOnDeath(false) :: any,
		Rx.distinct() :: any,
	})
end

return PlayerHumanoidBinder.new(
		"UnragdollAutomatically",
		UnragdollAutomatically :: any
	) :: PlayerHumanoidBinder.PlayerHumanoidBinder<UnragdollAutomatically>
