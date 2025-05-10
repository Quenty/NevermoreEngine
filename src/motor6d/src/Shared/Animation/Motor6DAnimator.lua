--[=[
	@class Motor6DAnimator
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local CFrameUtils = require("CFrameUtils")
local Maid = require("Maid")
local StepUtils = require("StepUtils")
local Symbol = require("Symbol")

local Motor6DAnimator = setmetatable({}, BaseObject)
Motor6DAnimator.ClassName = "Motor6DAnimator"
Motor6DAnimator.__index = Motor6DAnimator

function Motor6DAnimator.new(motor6D)
	local self = setmetatable(BaseObject.new(motor6D), Motor6DAnimator)

	self._stack = {}

	self._startAnimation, self._maid._stopAnimate = StepUtils.bindToSignal(RunService.Stepped, self._updateStepped)
	self:_startAnimation()

	return self
end

function Motor6DAnimator:Push(transformer)
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

function Motor6DAnimator:_getTransformResult(stackEntry, defaultTransform)
	return stackEntry:Transform(function()
		local index = table.find(self._stack, stackEntry)
		if not index then
			warn("[Motor6DAnimator] - Item is not in stack")
			return defaultTransform
		end

		local belowIndex = index - 1
		if self._stack[belowIndex] then
			local belowResult = self:_getTransformResult(self._stack[belowIndex], defaultTransform)
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

function Motor6DAnimator:_updateStepped()
	debug.profilebegin("motor6danimator")
	local current = self._stack[#self._stack]

	-- Detect animation
	local currentTransform = self._obj.Transform
	local unmodifiedTransform = currentTransform
	if self._lastSetTransform then
		local didAnimationPlay = not CFrameUtils.areClose(self._lastSetTransform, currentTransform, 1e-3)
		if didAnimationPlay or not self._previousTransform then
			self._previousTransform = currentTransform
		end

		if not didAnimationPlay then
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

	local result = self:_getTransformResult(current, unmodifiedTransform)
	if result then
		self._lastSetTransform = result
		self._obj.Transform = result
		debug.profileend()
		return true
	else
		self:_resetTransform(unmodifiedTransform)
		debug.profileend()
		-- let it finish
		return true
	end
end

function Motor6DAnimator:_resetTransform(unmodifiedTransform)
	self._obj.Transform = unmodifiedTransform
	self._lastSetTransform = nil
	self._previousTransform = nil
end

return Motor6DAnimator
