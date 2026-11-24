--!strict
--[=[
	Helps to run animations in hoarcekat or in Studio when the game isn't running.

	```lua
	maid:GiveTask(StudioRigAnimator.new(humanoid))
	```

	@class StudioRigAnimator
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local AnimationUtils = require("AnimationUtils")
local BaseObject = require("BaseObject")
local Signal = require("Signal")

local StudioRigAnimator = setmetatable({}, BaseObject)
StudioRigAnimator.ClassName = "StudioRigAnimator"
StudioRigAnimator.__index = StudioRigAnimator

export type StudioRigAnimator =
	typeof(setmetatable(
		{} :: {
			AnimationsStepped: Signal.Signal<number>,
			_animator: Animator?,
			_obj: AnimationUtils.AnimationTarget,
			_lastTime: number,
		},
		{} :: typeof({ __index = StudioRigAnimator })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new rig animator which will play the animations for the lifetime of the
	object.

	@param animationTarget AnimationUtils.AnimationTarget
	@return StudioRigAnimator
]=]
function StudioRigAnimator.new(animationTarget: AnimationUtils.AnimationTarget): StudioRigAnimator
	local self: StudioRigAnimator = setmetatable(BaseObject.new(animationTarget) :: any, StudioRigAnimator)

	self._lastTime = 0

	--[=[
		Fires with the delta time after the animator steps, so other animation layers can step on top.

		@prop AnimationsStepped Signal<number>
		@within StudioRigAnimator
	]=]
	self.AnimationsStepped = self._maid:Add(Signal.new() :: any)

	if RunService:IsStudio() and not RunService:IsRunning() then
		self:_setupStudio()
	end

	return self
end

function StudioRigAnimator._setupStudio(self: StudioRigAnimator): ()
	self._animator = AnimationUtils.getOrCreateAnimator(self._obj)
	if not self._animator then
		return
	end

	self._lastTime = os.clock()

	self._maid:GiveTask(RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local delta = now - self._lastTime
		self._lastTime = now

		self._animator:StepAnimations(delta)
		self.AnimationsStepped:Fire(delta)
	end))
end

return StudioRigAnimator
