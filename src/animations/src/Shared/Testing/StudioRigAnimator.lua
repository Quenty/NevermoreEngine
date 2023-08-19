--[=[
	Ship to run animations in hoarcekat

	@class StudioRigAnimator
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local AnimationUtils = require("AnimationUtils")

local StudioRigAnimator = setmetatable({}, BaseObject)
StudioRigAnimator.ClassName = "StudioRigAnimator"
StudioRigAnimator.__index = StudioRigAnimator

function StudioRigAnimator.new(animatorOrHumanoid)
	local self = setmetatable(BaseObject.new(animatorOrHumanoid), StudioRigAnimator)

	if RunService:IsStudio() and not RunService:IsRunning() then
		self:_setupStudio()
	end

	return self
end

function StudioRigAnimator:_setupStudio()
	self._animator = AnimationUtils.getOrCreateAnimator(self._obj)
	self._lastTime = os.clock()

	self._maid:GiveTask(RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local delta = now - self._lastTime
		self._lastTime = now

		self._animator:StepAnimations(delta)
	end))
end

return StudioRigAnimator