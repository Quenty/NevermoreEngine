--[=[
	@class AnimationSlotPlayer
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local AnimationUtils = require("AnimationUtils")
local ValueObject = require("ValueObject")
local Maid = require("Maid")
local EnumUtils = require("EnumUtils")

local AnimationSlotPlayer = setmetatable({}, BaseObject)
AnimationSlotPlayer.ClassName = "AnimationSlotPlayer"
AnimationSlotPlayer.__index = AnimationSlotPlayer

function AnimationSlotPlayer.new(animationTarget)
	local self = setmetatable(BaseObject.new(), AnimationSlotPlayer)

	self._animationTarget = ValueObject.new(nil)
	self._maid:GiveTask(self._animationTarget)

	self._defaultFadeTime = ValueObject.new(0.1, "number")
	self._maid:GiveTask(self._defaultFadeTime)

	self._defaultAnimationPriority = ValueObject.new(nil)
	self._maid:GiveTask(self._defaultAnimationPriority)

	if animationTarget then
		self:SetAnimationTarget(animationTarget)
	end

	return self
end

function AnimationSlotPlayer:SetDefaultFadeTime(defaultFadeTime)
	self._defaultFadeTime.Value = defaultFadeTime
end

function AnimationSlotPlayer:SetDefaultAnimationPriority(defaultAnimationPriority)
	assert(EnumUtils.isOfType(Enum.AnimationPriority, defaultAnimationPriority) or defaultAnimationPriority == nil, "Bad defaultAnimationPriority")

	self._defaultAnimationPriority.Value = defaultAnimationPriority
end

function AnimationSlotPlayer:SetAnimationTarget(animationTarget)
	self._animationTarget:Mount(animationTarget)
end

function AnimationSlotPlayer:Play(id, fadeTime, weight, speed, priority)
	fadeTime = fadeTime or self._defaultFadeTime.Value
	priority = priority or self._defaultAnimationPriority.Value
	weight = weight or 1 -- We need to explicitly adjust the weight here

	local topMaid = Maid.new()

	topMaid:GiveTask(self._animationTarget:ObserveBrio(function(target)
		return target ~= nil
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local animationTarget = brio:GetValue()
		local maid = brio:ToMaid()

		local track = AnimationUtils.playAnimation(animationTarget, id, fadeTime, weight, speed, priority)
		maid:GiveTask(function()
			track:AdjustWeight(0, fadeTime or self._defaultFadeTime.Value)
		end)
	end))

	self._maid._current = topMaid

	return function()
		if self._maid._current == topMaid then
			self._maid._current = nil
		end
	end
end

function AnimationSlotPlayer:Stop()
	self._maid._current = nil
end

return AnimationSlotPlayer