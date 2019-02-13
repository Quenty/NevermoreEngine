--- Makes transitions between states easier. Uses the `CameraStack` to tween in and
-- out a new camera state Call `:Show()` and `:Hide()` to do so, and make sure to
-- call `:Destroy()` after usage
-- @classmod CameraStateTweener

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraStack = require("CameraStack")
local FadeBetweenCamera = require("FadeBetweenCamera")
local Maid = require("Maid")

local CameraStateTweener = {}
CameraStateTweener.ClassName = "CameraStateTweener"
CameraStateTweener.__index = CameraStateTweener

--- Constructs a new camera state tweener
-- @tparam ICameraEffect cameraEffect A camera effect
-- @tparam[opt=20] number speed that the camera tweener tweens at
function CameraStateTweener.new(cameraEffect, speed)
	local self = setmetatable({}, CameraStateTweener)

	self._maid = Maid.new()
	local cameraBelow, assign = CameraStack:GetNewStateBelow()
	self._cameraBelow = cameraBelow
	self._fadeBetween = FadeBetweenCamera.new(cameraBelow, cameraEffect)
	assign(self._fadeBetween)

	CameraStack:Add(self._fadeBetween)

	self._fadeBetween.Speed = speed or 20
	self._fadeBetween.Target = 0
	self._fadeBetween.Value = 0

	self._maid:GiveTask(function()
		CameraStack:Remove(self._fadeBetween)
	end)

	return self
end

function CameraStateTweener:Show(doNotAnimate)
	self:SetTarget(1, doNotAnimate)
end


function CameraStateTweener:Hide(doNotAnimate)
	self:SetTarget(0, doNotAnimate)
end

function CameraStateTweener:Finish(doNotAnimate, callback)
	self:Hide(doNotAnimate)

	if self._fadeBetween.HasReachedTarget then
		callback()
	else
		spawn(function()
			while not self._fadeBetween.HasReachedTarget do
				wait(0.05)
			end
			callback()
		end)
	end
end

function CameraStateTweener:GetCameraBelow()
	return self._cameraBelow
end

function CameraStateTweener:SetTarget(target, doNotAnimate)
	self._fadeBetween.Target = target or error("No target")
	if doNotAnimate then
		self._fadeBetween.Value = self._fadeBetween.Target
		self._fadeBetween.Velocity = 0
	end
	return self
end

function CameraStateTweener:SetSpeed(speed)
	self._fadeBetween.Speed = speed

	return self
end

function CameraStateTweener:SetVisible(isVisible, doNotAnimate)
	if isVisible then
		self:Show(doNotAnimate)
	else
		self:Hide(doNotAnimate)
	end
end

function CameraStateTweener:GetFader()
	return self._fadeBetween
end

function CameraStateTweener:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return CameraStateTweener