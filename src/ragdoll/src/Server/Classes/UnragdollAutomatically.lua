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
local UnragdollAutomaticallyConstants = require("UnragdollAutomaticallyConstants")
local cancellableDelay = require("cancellableDelay")

local UnragdollAutomatically = setmetatable({}, BaseObject)
UnragdollAutomatically.ClassName = "UnragdollAutomatically"
UnragdollAutomatically.__index = UnragdollAutomatically

--[=[
	Constructs a new UnragdollAutomatically. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return UnragdollAutomatically
]=]
function UnragdollAutomatically.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), UnragdollAutomatically)

	self._serviceBag = assert(serviceBag, "Bad serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)
	self._ragdollHumanoidOnFallBinder = self._serviceBag:GetService(RagdollHumanoidOnFall)
	self._player = CharacterUtils.getPlayerFromCharacter(self._obj)

	self._unragdollAutomatically =
		AttributeValue.new(self._obj, UnragdollAutomaticallyConstants.UNRAGDOLL_AUTOMATICALLY_ATTRIBUTE, true)
	self._unragdollAutomaticTime =
		AttributeValue.new(self._obj, UnragdollAutomaticallyConstants.UNRAGDOLL_AUTOMATIC_TIME_ATTRIBUTE, 5)

	self._maid:GiveTask(self._ragdollBinder:ObserveInstance(self._obj, function()
		self:_handleRagdollChanged(self._maid)
	end))
	self:_handleRagdollChanged(self._maid)

	return self
end

function UnragdollAutomatically:_handleRagdollChanged(maid)
	if self._ragdollBinder:Get(self._obj) then
		maid._unragdoll = self:_observeCanUnragdollTimer()
			:Pipe({
				Rx.switchMap(function(state)
					if state then
						return self:_observeAlive()
					else
						return Rx.of(false)
					end
				end),
				Rx.distinct(),
			})
			:Subscribe(function(canUnragdoll)
				if canUnragdoll then
					self._ragdollBinder:Unbind(self._obj)
				end
			end)
	else
		maid._unragdoll = nil
	end
end

function UnragdollAutomatically:_observeAlive()
	return RxInstanceUtils.observeProperty(self._obj, "Health"):Pipe({
		Rx.map(function(health)
			return health > 0
		end),
		Rx.distinct(),
	})
end

function UnragdollAutomatically:_observeCanUnragdollTimer()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startTime = os.clock()
		local isReady = Instance.new("BoolValue")
		isReady.Value = false
		maid:GiveTask(isReady)

		maid:GiveTask(RxBrioUtils.flatCombineLatest({
			canUnragdoll = RxBrioUtils.flatCombineLatest({
				enabled = self._unragdollAutomatically:Observe(),
				isFallingRagdoll = self:_observeIsFallingRagdoll(),
			}):Pipe({
				Rx.map(function(state)
					return state.enabled and not state.isFallingRagdoll
				end),
				Rx.distinct(),
				Rx.tap(function(canUnragdoll)
					-- Ensure we reset timer if we change state
					if canUnragdoll then
						startTime = os.clock()
					end
				end),
			}),
			time = self._unragdollAutomaticTime:Observe(),
		}):Subscribe(function(state)
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
	end)
end

function UnragdollAutomatically:_observeIsFallingRagdoll()
	return RxBinderUtils.observeBoundClassBrio(self._ragdollHumanoidOnFallBinder, self._obj):Pipe({
		RxBrioUtils.switchMapBrio(function(ragdollHumanoidOnFall)
			return ragdollHumanoidOnFall:ObserveIsFalling()
		end),
		RxBrioUtils.emitOnDeath(false),
		Rx.distinct(),
	})
end

return PlayerHumanoidBinder.new("UnragdollAutomatically", UnragdollAutomatically)
