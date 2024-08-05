--[=[
	Makes transitions between states easier. Uses the `CameraStackService` to tween in and
	out a new camera state Call `:Show()` and `:Hide()` to do so, and make sure to
	call `:Destroy()` after usage

	@class CameraStateTweener
]=]

local require = require(script.Parent.loader).load(script)

local CameraStackService = require("CameraStackService")
local FadeBetweenCamera3 = require("FadeBetweenCamera3")
local ServiceBag = require("ServiceBag")
local BaseObject = require("BaseObject")
local CameraStack = require("CameraStack")

local CameraStateTweener = setmetatable({}, BaseObject)
CameraStateTweener.ClassName = "CameraStateTweener"
CameraStateTweener.__index = CameraStateTweener

--[=[
	Constructs a new camera state tweener

	@param serviceBagOrCameraStack ServiceBag | CameraStack -- Service bag to find the CameraStackService in
	@param cameraEffect CameraLike -- A camera effect
	@param speed number? -- Speed that the camera tweener tweens at. Defaults to 20
	@return CameraStateTweener
]=]
function CameraStateTweener.new(serviceBagOrCameraStack, cameraEffect, speed)
	local self = setmetatable(BaseObject.new(), CameraStateTweener)

	assert(cameraEffect, "No cameraEffect")

	if ServiceBag.isServiceBag(serviceBagOrCameraStack) then
		self._cameraStack = serviceBagOrCameraStack:GetService(CameraStackService):GetCameraStack()
	elseif CameraStack.isCameraStack(serviceBagOrCameraStack) then
		self._cameraStack = serviceBagOrCameraStack
	else
		error("Bad serviceBagOrCameraStack")
	end

	assert(self._cameraStack, "No CameraStack")

	local cameraBelow, assign = self._cameraStack:GetNewStateBelow()

	self._cameraEffect = cameraEffect
	self._cameraBelow = cameraBelow
	self._fadeBetween = FadeBetweenCamera3.new(cameraBelow, cameraEffect)
	assign(self._fadeBetween)

	self._cameraStack:Add(self._fadeBetween)

	self._fadeBetween.Speed = speed or 20
	self._fadeBetween.Target = 0
	self._fadeBetween.Value = 0

	self._maid:GiveTask(function()
		self._cameraStack:Remove(self._fadeBetween)
	end)

	return self
end

--[=[
	Returns percent visible, from 0 to 1.
	@return number
]=]
function CameraStateTweener:GetPercentVisible()
	return self._fadeBetween.Value
end

--[=[
	Shows the camera to fade in.
	@param doNotAnimate? boolean -- Optional, defaults to animating
]=]
function CameraStateTweener:Show(doNotAnimate)
	self:SetTarget(1, doNotAnimate)
end

--[=[
	Hides the camera to fade in.
	@param doNotAnimate? boolean -- Optional, defaults to animating
]=]
function CameraStateTweener:Hide(doNotAnimate)
	self:SetTarget(0, doNotAnimate)
end

--[=[
	Returns true if we're done hiding
	@return boolean
]=]
function CameraStateTweener:IsFinishedHiding()
	return self._fadeBetween.HasReachedTarget and self._fadeBetween.Target == 0
end

--[=[
	Returns true if we're done showing
	@return boolean
]=]
function CameraStateTweener:IsFinishedShowing()
	return self._fadeBetween.HasReachedTarget and self._fadeBetween.Target == 1
end

--[=[
	Hides the tweener, and invokes the callback once the tweener
	is finished hiding.
	@param doNotAnimate boolean? -- Optional, defaults to animating
	@param callback function
]=]
function CameraStateTweener:Finish(doNotAnimate, callback)
	assert(type(callback) == "function", "Bad callback")

	self:Hide(doNotAnimate)

	if self._fadeBetween.HasReachedTarget then
		callback()
	else
		task.spawn(function()
			while not self._fadeBetween.HasReachedTarget do
				task.wait(0.05)
			end
			callback()
		end)
	end
end

--[=[
	Gets the current effect we're tweening
	@return CameraEffect
]=]
function CameraStateTweener:GetCameraEffect()
	return self._cameraEffect
end

--[=[
	Gets the camera below this camera on the camera stack
	@return CameraEffect
]=]
function CameraStateTweener:GetCameraBelow()
	return self._cameraBelow
end

--[=[
	Sets the percent visible target
	@param target number
	@param doNotAnimate boolean? -- Optional, defaults to animating
	@return CameraStateTweener -- self
]=]
function CameraStateTweener:SetTarget(target, doNotAnimate)
	self._fadeBetween.Target = target or error("No target")
	if doNotAnimate then
		self._fadeBetween.Value = self._fadeBetween.Target
		self._fadeBetween.Velocity = 0
	end
	return self
end

--[=[
	Sets the speed of transition
	@param speed number
	@return CameraStateTweener -- self
]=]
function CameraStateTweener:SetSpeed(speed)
	assert(type(speed) == "number", "Bad speed")

	self._fadeBetween.Speed = speed

	return self
end

--[=[
	Sets whether the tweener is visible
	@param isVisible boolean
	@param doNotAnimate boolean? -- Optional, defaults to animating
]=]
function CameraStateTweener:SetVisible(isVisible, doNotAnimate)
	if isVisible then
		self:Show(doNotAnimate)
	else
		self:Hide(doNotAnimate)
	end
end

--[=[
	Retrieves the fading camera being used to interpolate.
	@return CameraEffect
]=]
function CameraStateTweener:GetFader()
	return self._fadeBetween
end

return CameraStateTweener