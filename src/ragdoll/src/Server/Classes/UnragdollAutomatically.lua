--[=[
	When a humanoid is tagged with this, it will unragdoll automatically.
	@server
	@class UnragdollAutomatically
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local RagdollBindersServer = require("RagdollBindersServer")
local CharacterUtils = require("CharacterUtils")
local AttributeValue = require("AttributeValue")
local Maid = require("Maid")
local UnragdollAutomaticallyConstants = require("UnragdollAutomaticallyConstants")
local cancellableDelay = require("cancellableDelay")
local Observable = require("Observable")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

local UnragdollAutomatically = setmetatable({}, BaseObject)
UnragdollAutomatically.ClassName = "UnragdollAutomatically"
UnragdollAutomatically.__index = UnragdollAutomatically

--[=[
	Constructs a new UnragdollAutomatically. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return UnragdollAutomatically
]=]
function UnragdollAutomatically.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), UnragdollAutomatically)

	self._ragdollBindersServer = serviceBag:GetService(RagdollBindersServer)
	self._player = CharacterUtils.getPlayerFromCharacter(self._obj)

	self._unragdollAutomatically = AttributeValue.new(self._obj, UnragdollAutomaticallyConstants.UNRAGDOLL_AUTOMATICALLY_ATTRIBUTE, true)
	self._unragdollAutomaticTime = AttributeValue.new(self._obj, UnragdollAutomaticallyConstants.UNRAGDOLL_AUTOMATIC_TIME_ATTRIBUTE, 5)

	self._maid:GiveTask(self._ragdollBindersServer.Ragdoll:ObserveInstance(self._obj, function()
		self:_handleRagdollChanged(self._maid)
	end))
	self:_handleRagdollChanged(self._maid)

	return self
end

function UnragdollAutomatically:_handleRagdollChanged(maid)
	if self._ragdollBindersServer.Ragdoll:Get(self._obj) then
		maid._unragdoll = self:_observeCanUnragdollTimer():Pipe({
			Rx.switchMap(function(state)
				if state then
					return self:_observeAlive()
				else
					return Rx.of(false);
				end
			end);
			Rx.distinct();
		}):Subscribe(function(canUnragdoll)
			if canUnragdoll then
				self._ragdollBindersServer.Ragdoll:Unbind(self._obj)
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
		end);
		Rx.distinct();
	})
end

function UnragdollAutomatically:_observeCanUnragdollTimer()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startTime = os.clock()
		local isReady = Instance.new("BoolValue")
		isReady.Value = false
		maid:GiveTask(isReady)

		maid:GiveTask(Rx.combineLatest({
			enabled = self._unragdollAutomatically:Observe();
			time = self._unragdollAutomaticTime:Observe();
		}):Subscribe(function(state)
			if state.enabled then
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

return UnragdollAutomatically