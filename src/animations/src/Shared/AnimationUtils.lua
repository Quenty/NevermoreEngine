--!strict
--[=[
	@class AnimationUtils
]=]

local require = require(script.Parent.loader).load(script)

local RbxAssetUtils = require("RbxAssetUtils")
local HumanoidAnimatorUtils = require("HumanoidAnimatorUtils")
local EnumUtils = require("EnumUtils")

local AnimationUtils = {}

--[=[
	Plays the animation on the target instance.

	@return AnimationTrack?
]=]
function AnimationUtils.playAnimation(
	target: Animator | Player | Model | AnimationController,
	id: string | number,
	fadeTime: number?,
	weight: number?,
	speed: number?,
	priority: Enum.AnimationPriority?
): AnimationTrack?
	assert(typeof(target) == "Instance", "Bad target")
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")
	assert(type(fadeTime) == "number" or fadeTime == nil, "Bad fadeTime")
	assert(type(weight) == "number" or weight == nil, "Bad weight")
	assert(type(speed) == "number" or speed == nil, "Bad speed")
	assert(priority == nil or EnumUtils.isOfType(Enum.AnimationPriority, priority), "Bad priority")

	local animationTrack = AnimationUtils.getOrCreateAnimationTrack(target, id, priority)

	if animationTrack then
		animationTrack:Play(fadeTime, weight, speed)

		if priority then
			animationTrack.Priority = priority
		end
	else
		warn(string.format("[AnimationUtils] - Failed to play animationTrack %q", tostring(id)))
	end

	return animationTrack
end

--[=[
	Stops the animation on the target instance.
]=]
function AnimationUtils.stopAnimation(
	target: Animator | Player | Model | AnimationController,
	id: string | number,
	fadeTime: number?
): AnimationTrack?
	assert(typeof(target) == "Instance", "Bad target")
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")
	assert(type(fadeTime) == "number" or fadeTime == nil, "Bad fadeTime")

	local animationTrack = AnimationUtils.findAnimationTrack(target, id)

	if animationTrack then
		animationTrack:Stop(fadeTime)
	end

	return animationTrack
end

--[=[
	Gets or creates an animation track for the player
]=]
function AnimationUtils.getOrCreateAnimationTrack(
	target: Animator | Player | Model | AnimationController,
	id: string | number,
	priority: Enum.AnimationPriority?
): AnimationTrack?
	assert(typeof(target) == "Instance", "Bad target")
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")
	assert(priority == nil or EnumUtils.isOfType(Enum.AnimationPriority, priority), "Bad priority")

	local animator = AnimationUtils.getOrCreateAnimator(target)
	if not animator then
		return nil
	end

	assert(typeof(animator) == "Instance" and animator:IsA("Animator"), "Bad animator")

	local foundAnimationTrack = AnimationUtils.findAnimationTrackInAnimator(animator, id)
	if foundAnimationTrack then
		return foundAnimationTrack
	end

	local animation = AnimationUtils.getOrCreateAnimationFromIdInAnimator(animator, id)

	local animationTrack
	local ok, err = pcall(function()
		animationTrack = animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(
			string.format(
				"[AnimationUtils] - Failed to load animation with id %q due to %q",
				tostring(id),
				tostring(err)
			)
		)
		return nil
	end

	return animationTrack
end

--[=[
	Gets or creates an animation from the id in the animator
]=]
function AnimationUtils.getOrCreateAnimationFromIdInAnimator(animator: Animator, id: string | number): Animation
	assert(typeof(animator) == "Instance" and animator:IsA("Animator"), "Bad animator")
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")

	local animationId = RbxAssetUtils.toRbxAssetId(id)
	for _, animation in animator:GetChildren() do
		if animation:IsA("Animation") then
			if animation.AnimationId == animationId then
				return animation
			end
		end
	end

	local animation = AnimationUtils.createAnimationFromId(id)
	animation.Parent = animator

	return animation
end

--[=[
	Finds an animation track
]=]
function AnimationUtils.findAnimationTrack(
	target: Animator | Player | Model | AnimationController,
	id: string | number
): AnimationTrack?
	assert(typeof(target) == "Instance", "Bad target")
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")

	local animator = AnimationUtils.getOrCreateAnimator(target)
	if not animator then
		return nil
	end

	return AnimationUtils.findAnimationTrackInAnimator(animator, id)
end

--[=[
	Finds an animation track in an animator
]=]
function AnimationUtils.findAnimationTrackInAnimator(animator: Animator, id: string | number): AnimationTrack?
	assert(typeof(animator) == "Instance" and animator:IsA("Animator"), "Bad animator")
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")

	local animationId = RbxAssetUtils.toRbxAssetId(id)

	for _, animationTrack in animator:GetPlayingAnimationTracks() do
		local animation = animationTrack.Animation
		if animation and animation.AnimationId == animationId then
			return animationTrack
		end
	end

	return nil
end

--[=[
	Finds an animator for the current instance
]=]
function AnimationUtils.getOrCreateAnimator(target: Animator | Player | Model | AnimationController): Animator?
	assert(typeof(target) == "Instance", "Bad target")

	if target:IsA("Animator") then
		return target
	elseif target:IsA("Humanoid") then
		return HumanoidAnimatorUtils.getOrCreateAnimator(target)
	elseif target:IsA("AnimationController") then
		return HumanoidAnimatorUtils.getOrCreateAnimator(target)
	elseif target:IsA("Player") then
		local character = target.Character
		if not character then
			return nil
		end

		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then
			return nil
		end

		return HumanoidAnimatorUtils.getOrCreateAnimator(humanoid)
	elseif target:IsA("Model") then
		local humanoid = target:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			return HumanoidAnimatorUtils.getOrCreateAnimator(humanoid)
		end

		local animationController = target:FindFirstChildWhichIsA("AnimationController")
		if animationController then
			return HumanoidAnimatorUtils.getOrCreateAnimator(animationController)
		end

		return nil
	else
		return nil
	end
end

--[=[
	Gets a specific animation name for an animation id
]=]
function AnimationUtils.getAnimationName(animationId: string): string
	return string.format("Animation_%s", animationId)
end

--[=[
	Creates a new animation object from the given id
]=]
function AnimationUtils.createAnimationFromId(id: string | number): Animation
	assert(RbxAssetUtils.isConvertableToRbxAsset(id), "Bad id")

	local animationId = RbxAssetUtils.toRbxAssetId(id)
	assert(type(animationId) == "string", "Bad id")

	local animation = Instance.new("Animation")
	animation.Name = AnimationUtils.getAnimationName(animationId)
	animation.AnimationId = animationId
	animation.Archivable = false

	return animation
end

return AnimationUtils
