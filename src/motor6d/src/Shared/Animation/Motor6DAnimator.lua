--!strict
--[=[
	@class Motor6DAnimator
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local CFrameUtils = require("CFrameUtils")
local Draw = require("Draw")
local Maid = require("Maid")
local Motor6DTransformer = require("Motor6DTransformer")
local StepUtils = require("StepUtils")
local Symbol = require("Symbol")

local DEBUG_VISUALIZE = false

local Motor6DAnimator = setmetatable({}, BaseObject)
Motor6DAnimator.ClassName = "Motor6DAnimator"
Motor6DAnimator.__index = Motor6DAnimator

export type Motor6DAnimator =
	typeof(setmetatable(
		{} :: {
			_obj: Motor6D,
			_debugAttachment: Attachment?,
			_lastSetTransform: CFrame?,
			_previousTransform: CFrame?,
			_stack: { Motor6DTransformer.Motor6DTransformer },
			_startAnimation: (self: Motor6DAnimator) -> (),
		},
		{} :: typeof({ __index = Motor6DAnimator })
	))
	& BaseObject.BaseObject

function Motor6DAnimator.new(motor6D: Motor6D): Motor6DAnimator
	local self = setmetatable(BaseObject.new(motor6D) :: any, Motor6DAnimator)

	self._stack = {}

	self._startAnimation, self._maid._stopAnimate =
		StepUtils.bindToSignal(RunService.PreSimulation, self._updateStepped)
	self:_startAnimation()

	return self
end

--[=[
	Pushes a Motor6DTransformer onto the animation stack.

	@param transformer Motor6DTransformer -- The transformer to push.
	@return () -> () -- A function to remove the transformer from the stack.
]=]
function Motor6DAnimator.Push(self: Motor6DAnimator, transformer: Motor6DTransformer.Motor6DTransformer): () -> ()
	assert(transformer, "No transformer")

	local symbol = Symbol.named("transformer")

	local maid = Maid.new()

	maid:GiveTask(transformer.Finished:Connect(function()
		self._maid[symbol] = nil
	end))

	maid:GiveTask(function()
		local index = table.find(self._stack, transformer)
		if index then
			table.remove(self._stack, index)
		end
		self:_startAnimation()
	end)

	if #self._stack > 10 then
		warn(string.format("[Motor6DAnimator] - Motor stack overflow (%d)", #self._stack))
	end

	self._maid[symbol] = maid

	table.insert(self._stack, transformer)
	self:_startAnimation()

	return function()
		self._maid[symbol] = nil
	end
end

function Motor6DAnimator._computeNewTransform(
	self: Motor6DAnimator,
	stackEntry: Motor6DTransformer.Motor6DTransformer,
	defaultTransform: CFrame
): CFrame?
	return stackEntry:Transform(function()
		local index = table.find(self._stack, stackEntry)
		if not index then
			warn("[Motor6DAnimator] - Item is not in stack")
			return defaultTransform
		end

		local belowIndex = index - 1
		if self._stack[belowIndex] then
			local belowResult = self:_computeNewTransform(self._stack[belowIndex], defaultTransform)
			if belowResult then
				return belowResult
			else
				return defaultTransform
			end
		else
			return defaultTransform
		end
	end)
end

function Motor6DAnimator._updateStepped(self: Motor6DAnimator): ()
	debug.profilebegin("motor6danimator")
	local current: Motor6DTransformer.Motor6DTransformer? = self._stack[#self._stack] :: any

	if DEBUG_VISUALIZE then
		local maid = Maid.new()

		self._debugAttachment = self._debugAttachment or Instance.new("Attachment")
		assert(self._debugAttachment, "No debug attachment")
		self._debugAttachment.Archivable = false
		self._debugAttachment.Name = "Motor6DAnimatorDebug"
		self._debugAttachment.CFrame = self._obj.C0
		self._debugAttachment.Parent = self._obj.Part0

		local billBoard: BillboardGui =
			maid:Add(Draw.text(self._debugAttachment, if current then "Animating" else "Idle")) :: any
		billBoard.Size = UDim2.fromScale(billBoard.Size.X.Scale / 5, billBoard.Size.Y.Scale / 5)

		self._maid._debugState = maid
	end

	-- Detect animation
	local currentTransform = self._obj.Transform
	local unmodifiedTransform = currentTransform
	if self._lastSetTransform then
		local didAnimationPlay = not CFrameUtils.areClose(self._lastSetTransform, currentTransform, 1e-3)
		if didAnimationPlay or not self._previousTransform then
			self._previousTransform = currentTransform
		end

		if not didAnimationPlay then
			assert(self._previousTransform, "No previous transform")
			unmodifiedTransform = self._previousTransform
		end
	else
		self._previousTransform = currentTransform
	end

	if not current then
		self:_resetTransform(unmodifiedTransform)
		debug.profileend()
		return false
	end

	local transformOverride: CFrame? = self:_computeNewTransform(current, unmodifiedTransform)
	if transformOverride then
		self._lastSetTransform = transformOverride
		self._obj.Transform = transformOverride
		debug.profileend()
		return true
	else
		self:_resetTransform(unmodifiedTransform)
		debug.profileend()
		-- let it finish
		return true
	end
end

function Motor6DAnimator._resetTransform(self: Motor6DAnimator, unmodifiedTransform: CFrame): ()
	self._obj.Transform = unmodifiedTransform
	self._lastSetTransform = nil
	self._previousTransform = nil
end

return Motor6DAnimator
