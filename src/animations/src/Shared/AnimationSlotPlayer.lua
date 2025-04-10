--!strict
--[=[
	Acts as a priority slot which can be overridden and play any animation in.
	See Roblox's animation system for more information.

	@class AnimationSlotPlayer
]=]

local require = require(script.Parent.loader).load(script)

local AnimationUtils = require("AnimationUtils")
local BaseObject = require("BaseObject")
local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local RbxAssetUtils = require("RbxAssetUtils")
local ValueObject = require("ValueObject")

local AnimationSlotPlayer = setmetatable({}, BaseObject)
AnimationSlotPlayer.ClassName = "AnimationSlotPlayer"
AnimationSlotPlayer.__index = AnimationSlotPlayer

export type AnimationSlotPlayer = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_animationTarget: ValueObject.ValueObject<Instance>,
		_defaultFadeTime: ValueObject.ValueObject<number>,
		_defaultAnimationPriority: ValueObject.ValueObject<Enum.AnimationPriority>,
		_currentAnimationTrackData: ValueObject.ValueObject<any>,
		_currentAnimationId: ValueObject.ValueObject<string>,
	},
	{} :: typeof({ __index = AnimationSlotPlayer })
)) & BaseObject.BaseObject

--[=[
	Creates a new AnimationSlotPlayer with a target to play the animation on.

	@param animationTarget Instance? | Observable<Instance>
	@return AnimationSlotPlayer
]=]
function AnimationSlotPlayer.new(animationTarget): AnimationSlotPlayer
	local self: AnimationSlotPlayer = setmetatable(BaseObject.new() :: any, AnimationSlotPlayer)

	self._animationTarget = self._maid:Add(ValueObject.new(nil))
	self._defaultFadeTime = self._maid:Add(ValueObject.new(0.1, "number"))
	self._defaultAnimationPriority = self._maid:Add(ValueObject.new(nil))
	self._currentAnimationTrackData = self._maid:Add(ValueObject.new(nil))
	self._currentAnimationId = self._maid:Add(ValueObject.new(nil))

	if animationTarget then
		self:SetAnimationTarget(animationTarget)
	end

	return self
end

--[=[
	Sets a new default fade time

	@param defaultFadeTime number
]=]
function AnimationSlotPlayer.SetDefaultFadeTime(self: AnimationSlotPlayer, defaultFadeTime: number)
	self._defaultFadeTime.Value = defaultFadeTime
end

--[=[
	Sets a new default animation priority

	@param defaultAnimationPriority number
]=]
function AnimationSlotPlayer.SetDefaultAnimationPriority(self: AnimationSlotPlayer, defaultAnimationPriority)
	assert(
		EnumUtils.isOfType(Enum.AnimationPriority, defaultAnimationPriority) or defaultAnimationPriority == nil,
		"Bad defaultAnimationPriority"
	)

	self._defaultAnimationPriority.Value = defaultAnimationPriority
end

--[=[
	Sets an animation target to play the animation on

	@param animationTarget Instance | Observable<Instance>
]=]
function AnimationSlotPlayer.SetAnimationTarget(self: AnimationSlotPlayer, animationTarget)
	self._animationTarget:Mount(animationTarget)
end

type AnimationData = {
	animationId: string,
	track: AnimationTrack,
	originalSpeed: number?,
	originalWeight: number?,
	originalPriority: Enum.AnimationPriority?,
}

--[=[
	Adjusts the speed of the animation playing in the slot

	@param id string | number
	@param speed number
	@return () -> () -- Callback to clean things up
]=]
function AnimationSlotPlayer.AdjustSpeed(self: AnimationSlotPlayer, id: string | number, speed: number)
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")
	assert(type(speed) == "number", "Bad speed")

	local animationId = RbxAssetUtils.toRbxAssetId(id)

	local topMaid = Maid.new()

	-- stylua: ignore
	topMaid:GiveTask(self._currentAnimationTrackData
		:ObserveBrio(function(data: AnimationData)
			return data and data.animationId == animationId
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local data: AnimationData = brio:GetValue()
			local maid = brio:ToMaid()

			data.track:AdjustSpeed(speed)

			-- TODO: Use stack here?
			-- TODO: Probably need rogue property mechanisms
			maid:GiveTask(function()
				if math.abs(data.track.Speed - speed) <= 1e-3 then
					data.track:AdjustSpeed(data.originalSpeed)
				end
			end)
		end))

	-- TODO: Probably per-a-track instead of global like this
	self._maid._currentSpeedAdjustment = topMaid

	return function()
		if self._maid._currentSpeedAdjustment :: any == topMaid then
			self._maid._currentSpeedAdjustment = nil
		end
	end
end

--[=[
	Adjusts the weight of the animation playing in the slot

	@param id string | number
	@param weight number
	@param fadeTime number?
	@return () -> () -- Callback to clean things up
]=]
function AnimationSlotPlayer.AdjustWeight(self: AnimationSlotPlayer, id: string, weight: number, fadeTime: number?)
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")
	assert(type(weight) == "number", "Bad weight")
	assert(type(fadeTime) == "number" or fadeTime == nil, "Bad fadeTime")

	local animationId = RbxAssetUtils.toRbxAssetId(id)

	local topMaid = Maid.new()

	-- stylua: ignore
	topMaid:GiveTask(self._currentAnimationTrackData
		:ObserveBrio(function(data)
			return data and data.animationId == animationId
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local data: AnimationData = brio:GetValue()
			local maid = brio:ToMaid()

			data.track:AdjustWeight(weight, fadeTime)

			-- TODO: Use stack here?
			-- TODO: Probably need rogue property mechanisms
			maid:GiveTask(function()
				if math.abs(data.track.Speed - weight) <= 1e-3 then
					data.track:AdjustWeight(data.originalWeight, fadeTime)
				end
			end)
		end))

	-- TODO: Probably per-a-track instead of global like this
	self._maid._currentWeightAdjustment = topMaid

	return function()
		if self._maid._currentWeightAdjustment :: any == topMaid then
			self._maid._currentWeightAdjustment = nil
		end
	end
end

--[=[
	Plays the animation in the slot, overriding any previous animation

	@param id string | number
	@param fadeTime number?
	@param weight number?
	@param speed number?
	@param priority Enum.AnimationPriority?
	@return () -> () -- Callback to clean things up
]=]
function AnimationSlotPlayer.Play(
	self: AnimationSlotPlayer,
	id: string | number,
	fadeTime: number?,
	weight: number?,
	speed: number?,
	priority: Enum.AnimationPriority?
): () -> ()
	fadeTime = fadeTime or self._defaultFadeTime.Value
	priority = priority or self._defaultAnimationPriority.Value
	weight = weight or 1 -- We need to explicitly adjust the weight here

	local topMaid = Maid.new()

	local animationId = RbxAssetUtils.toRbxAssetId(id)

	topMaid:GiveTask(self._animationTarget
		:ObserveBrio(function(target)
			return target ~= nil
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local animationTarget: any = brio:GetValue()
			local maid = brio:ToMaid()

			local track = AnimationUtils.playAnimation(animationTarget, animationId, fadeTime, weight, speed, priority)
			if track then
				local data = {
					animationId = animationId,
					track = track,
					originalSpeed = speed,
					originalWeight = weight,
					originalPriority = priority,
				}

				self._currentAnimationTrackData.Value = data
				maid:GiveTask(function()
					if self._currentAnimationTrackData.Value == data then
						self._currentAnimationTrackData.Value = nil
					end
				end)

				maid:GiveTask(function()
					track:AdjustWeight(0, fadeTime or self._defaultFadeTime.Value)
				end)
			else
				warn("[AnimationSlotPlayer] - Failed to get animation to play")
			end
		end))

	self._maid._current = topMaid

	return function()
		if self._maid._current :: any == topMaid then
			self._maid._current = nil
		end
	end
end

--[=[
	Stops the current animation playing
]=]
function AnimationSlotPlayer.Stop(self: AnimationSlotPlayer)
	self._maid._current = nil
end

return AnimationSlotPlayer