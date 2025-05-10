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

local BaseObject = require("BaseObject")
local AnimationUtils = require("AnimationUtils")

local StudioRigAnimator = setmetatable({}, BaseObject)
StudioRigAnimator.ClassName = "StudioRigAnimator"
StudioRigAnimator.__index = StudioRigAnimator

export type StudioRigAnimator = typeof(setmetatable(
	{} :: {
		_animator: Animator?,
		_obj: Animator | Humanoid,
		_lastTime: number,
	},
	{} :: typeof({ __index = StudioRigAnimator })
)) & BaseObject.BaseObject

--[=[
	Constructs a new rig animator which will play the animations for the lifetime of the
	object.

	@param animatorOrHumanoid Animator | Humanoid
	@return StudioRigAnimator
]=]
function StudioRigAnimator.new(animatorOrHumanoid: Animator | Humanoid): StudioRigAnimator
	local self: StudioRigAnimator = setmetatable(BaseObject.new(animatorOrHumanoid) :: any, StudioRigAnimator)

	self._lastTime = 0

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
	end))
end

return StudioRigAnimator
