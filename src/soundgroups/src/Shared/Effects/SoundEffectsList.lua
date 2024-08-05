--[=[
	@class SoundEffectsList
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ObservableList = require("ObservableList")
local Maid = require("Maid")
local MaidTaskUtils = require("MaidTaskUtils")
local ValueObject = require("ValueObject")
local Counter = require("Counter")
local Rx = require("Rx")

local SoundEffectsList = setmetatable({}, BaseObject)
SoundEffectsList.ClassName = "SoundEffectsList"
SoundEffectsList.__index = SoundEffectsList

function SoundEffectsList.new()
	local self = setmetatable(BaseObject.new(), SoundEffectsList)

	self._effectList = self._maid:Add(ObservableList.new())
	self._appliedCount = self._maid:Add(Counter.new())

	-- Export active state
	self._isActive = self._maid:Add(ValueObject.new(false, "boolean"))
	self._hasEffects = self._maid:Add(ValueObject.new(false, "boolean"))

	self.IsActiveChanged = assert(self._isActive.Changed, "No Changed")

	self._maid:GiveTask(Rx.combineLatest({
		appliedCount = self._appliedCount:Observe();
		effectCount = self._effectList:ObserveCount();
	}):Subscribe(function(state)
		self._hasEffects.Value = state.effectCount > 0
		self._isActive.Value = state.appliedCount > 0 or state.effectCount > 0
	end))

	return self
end

function SoundEffectsList:HasEffects()
	return self._hasEffects.Value
end

function SoundEffectsList:ObserveHasEffects()
	return self._hasEffects:Observe()
end

function SoundEffectsList:IsActive()
	return self._isActive.Value
end

--[=[
	Pushes an affect that will be applied to the sound group or sound
	as it exists.

	@param effect (instance) -> MaidTask
	@return () -> () -- Cleanup call
]=]
function SoundEffectsList:PushEffect(effect)
	assert(type(effect) == "function", "Bad effect")

	return self._effectList:Add(effect)
end

--[=[
	Pushes an affect that will be applied to the sound group or sound
	as it exists.

	@param instance SoundGroup | Sound
	@return () -> () -- Cleanup call
]=]
function SoundEffectsList:ApplyEffects(instance)
	assert(typeof(instance) == "Instance" and (instance:IsA("SoundGroup") or instance:IsA("Sound")), "Bad instance")

	local topMaid = Maid.new()

	topMaid:Add(self._appliedCount:Add(1))

	topMaid:GiveTask(self._effectList:ObserveItemsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, effect = brio:ToMaidAndValue()
		local cleanUpJob = effect(instance)

		if cleanUpJob then
			if not MaidTaskUtils.isValidTask(cleanUpJob) then
				error("[SoundEffectsList] - Effect did not return a valid cleanUpJob to cleanup")
			end

			maid:GiveTask(cleanUpJob)
		else
			warn("[SoundEffectsList] - Effect did not return any cleanup job (job is nil)")
		end
	end))

	topMaid:GiveTask(instance.Destroying:Connect(function()
		self._maid[topMaid] = nil
	end))

	self._maid[topMaid] = topMaid

	return function()
		self._maid[topMaid] = nil
	end
end

return SoundEffectsList