--!strict
--[=[
	Makes transitions between states easier. Uses the `CameraStackService` to tween in and
	out a new camera state. Call `:Show()` and `:Hide()` to do so, and make sure to
	call `:Destroy()` after usage.

	Inherits from [TransitionModel]. See for more API.

	@class CameraStateTweener
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraStack = require("CameraStack")
local CameraStackService = require("CameraStackService")
local DuckTypeUtils = require("DuckTypeUtils")
local FadeBetweenCamera3 = require("FadeBetweenCamera3")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local StepUtils = require("StepUtils")
local TransitionModel = require("TransitionModel")
local ValueObject = require("ValueObject")

local CameraStateTweener = setmetatable({}, TransitionModel)
CameraStateTweener.ClassName = "CameraStateTweener"
CameraStateTweener.__index = CameraStateTweener

export type CameraStateTweener =
	typeof(setmetatable(
		{} :: {
			_cameraStack: CameraStack.CameraStack,
			_cameraEffect: any,
			_cameraBelow: any,
			_fadeBetween: FadeBetweenCamera3.FadeBetweenCamera3,
			_shownTarget: ValueObject.ValueObject<number>,
		},
		{} :: typeof({ __index = CameraStateTweener })
	))
	& TransitionModel.TransitionModel

--[=[
	Constructs a new camera state tweener

	@param serviceBagOrCameraStack ServiceBag | CameraStack -- Service bag to find the CameraStackService in
	@param cameraEffect CameraLike -- A camera effect
	@param speed number? -- Speed that the camera tweener tweens at. Defaults to 20
	@return CameraStateTweener
]=]
function CameraStateTweener.new(
	serviceBagOrCameraStack: ServiceBag.ServiceBag | CameraStack.CameraStack,
	cameraEffect,
	speed: number?
): CameraStateTweener
	assert(cameraEffect, "No cameraEffect")

	local cameraStack: CameraStack.CameraStack
	if ServiceBag.isServiceBag(serviceBagOrCameraStack) then
		cameraStack = (serviceBagOrCameraStack :: any):GetService(CameraStackService):GetCameraStack()
	elseif CameraStack.isCameraStack(serviceBagOrCameraStack) then
		cameraStack = serviceBagOrCameraStack :: any
	else
		error("Bad serviceBagOrCameraStack")
	end

	assert(cameraStack, "No CameraStack")

	local self: CameraStateTweener = setmetatable(TransitionModel.new() :: any, CameraStateTweener)

	self._cameraStack = cameraStack

	local cameraBelow, assign = self._cameraStack:GetNewStateBelow()

	self._cameraEffect = cameraEffect
	self._cameraBelow = cameraBelow
	self._fadeBetween = FadeBetweenCamera3.new(cameraBelow, cameraEffect)
	assign(self._fadeBetween)

	self._cameraStack:Add(self._fadeBetween)

	self._fadeBetween.Speed = speed or 20
	self._fadeBetween.Target = 0
	self._fadeBetween.Value = 0

	self._shownTarget = self._maid:Add(ValueObject.new(1, "number"))

	self:SetPromiseShow(function(maid, doNotAnimate)
		return self:_promiseFadeTo(maid, self._shownTarget.Value, doNotAnimate)
	end)
	self:SetPromiseHide(function(maid, doNotAnimate)
		return self:_promiseFadeTo(maid, 0, doNotAnimate)
	end)

	-- Retarget while shown. Visibility has not changed, so nothing would restart the fade
	-- on its own, and the completion signals would report the transition that no longer applies.
	self._maid:GiveTask(self._shownTarget.Changed:Connect(function()
		if self:IsVisible() then
			self:_restartTransition()
		end
	end))

	self._maid:GiveTask(function()
		self._cameraStack:Remove(self._fadeBetween)
	end)

	return self
end

--[=[
	Returns true if it's a camera state tweener

	@param value any
	@return boolean
]=]
function CameraStateTweener.isCameraStateTweener(value: any): boolean
	return DuckTypeUtils.isImplementation(CameraStateTweener, value)
end

--[=[
	Returns percent visible, from 0 to 1.
	@return number
]=]
function CameraStateTweener.GetPercentVisible(self: CameraStateTweener): number
	return self._fadeBetween.Value
end

--[=[
	Returns true if we're done hiding

	@deprecated 14.52.0 -- Use TransitionModel.IsHidingComplete
	@return boolean
]=]
function CameraStateTweener.IsFinishedHiding(self: CameraStateTweener): boolean
	return self:IsHidingComplete()
end

--[=[
	Returns true if we're done showing

	@deprecated 14.52.0 -- Use TransitionModel.IsShowingComplete
	@return boolean
]=]
function CameraStateTweener.IsFinishedShowing(self: CameraStateTweener): boolean
	return self:IsShowingComplete()
end

--[=[
	Hides the tweener, and invokes the callback once the tweener
	is finished hiding.

	@deprecated 14.52.0 -- Use TransitionModel.PromiseHide, which also surfaces the tween being interrupted
	@param doNotAnimate boolean? -- Optional, defaults to animating
	@param callback function
]=]
function CameraStateTweener.Finish(self: CameraStateTweener, doNotAnimate: boolean?, callback: () -> ())
	assert(type(callback) == "function", "Bad callback")

	self._maid:GivePromise(self:PromiseHide(doNotAnimate)):Then(callback)
end

--[=[
	Gets the current effect we're tweening
	@return CameraEffect
]=]
function CameraStateTweener.GetCameraEffect(self: CameraStateTweener): CameraEffectUtils.CameraEffect
	return self._cameraEffect
end

--[=[
	Gets the camera below this camera on the camera stack
	@return CameraEffect
]=]
function CameraStateTweener.GetCameraBelow(self: CameraStateTweener): CameraEffectUtils.CameraEffect
	return self._cameraBelow
end

--[=[
	Sets the epsilon to stop animating
	@param epsilon number?
]=]
function CameraStateTweener.SetEpsilon(self: CameraStateTweener, epsilon: number?)
	self._fadeBetween.Epsilon = epsilon
end

--[=[
	Sets how far the camera effect fades in when shown. Defaults to 1, fully faded in.

	Changing this while shown retargets the fade and runs the show transition again, so
	[TransitionModel.ShowingComplete] fires for the transition that actually happened.

	@param shownTarget number | Observable<number> | ValueObject<number>
	@return function -- Cleanup function
]=]
function CameraStateTweener.SetShownTarget(
	self: CameraStateTweener,
	shownTarget: ValueObject.Mountable<number>
): () -> ()
	return self._shownTarget:Mount(shownTarget)
end

--[=[
	Gets how far the camera effect fades in when shown.
	@return number
]=]
function CameraStateTweener.GetShownTarget(self: CameraStateTweener): number
	return self._shownTarget.Value
end

--[=[
	Observes how far the camera effect fades in when shown.
	@return Observable<number>
]=]
function CameraStateTweener.ObserveShownTarget(self: CameraStateTweener): Observable.Observable<number>
	return self._shownTarget:Observe()
end

--[=[
	Sets the percent visible target.

	A target of 0 hides the tweener and leaves the shown target alone, so a later
	[BasicPane.Show] returns to where it was. Any other target becomes the new shown
	target and shows the tweener.

	@param target number
	@param doNotAnimate boolean? -- Optional, defaults to animating
	@return CameraStateTweener -- self
]=]
function CameraStateTweener.SetTarget(
	self: CameraStateTweener,
	target: number,
	doNotAnimate: boolean?
): CameraStateTweener
	assert(type(target) == "number", "Bad target")

	if target == 0 then
		self:Hide(doNotAnimate)
	else
		self._shownTarget.Value = target
		self:Show(doNotAnimate)
	end

	return self
end

--[=[
	Sets the speed of transition
	@param speed number
	@return CameraStateTweener -- self
]=]
function CameraStateTweener.SetSpeed(self: CameraStateTweener, speed: number): CameraStateTweener
	assert(type(speed) == "number", "Bad speed")

	self._fadeBetween.Speed = speed

	return self
end

--[=[
	Retrieves the fading camera being used to interpolate.
	@return CameraEffect
]=]
function CameraStateTweener.GetFader(self: CameraStateTweener): CameraEffectUtils.CameraEffect
	return self._fadeBetween
end

function CameraStateTweener._promiseFadeTo(
	self: CameraStateTweener,
	maid: Maid.Maid,
	target: number,
	doNotAnimate: boolean?
): Promise.Promise<()>
	self._fadeBetween.Target = target

	if doNotAnimate then
		self._fadeBetween.Value = target
		self._fadeBetween.Velocity = 0
	end

	if self._fadeBetween.HasReachedTarget then
		return Promise.resolved()
	end

	local promise = maid:Add(Promise.new())

	-- TODO: Mathematical solution? The spring has no completion event to hook.
	local startAnimate, stopAnimate = StepUtils.bindToRenderStep(function()
		if self._fadeBetween.HasReachedTarget then
			promise:Resolve()
			return false
		end

		return true
	end)

	maid:GiveTask(stopAnimate)
	startAnimate()

	return promise
end

return CameraStateTweener
