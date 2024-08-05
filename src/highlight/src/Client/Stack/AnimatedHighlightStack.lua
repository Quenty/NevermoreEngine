--[=[
	@class AnimatedHighlightStack
]=]

local require = require(script.Parent.loader).load(script)

local AnimatedHighlight = require("AnimatedHighlight")
local AnimatedHighlightModel = require("AnimatedHighlightModel")
local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Rx = require("Rx")
local Signal = require("Signal")
local ObservableSortedList = require("ObservableSortedList")
local ValueObject = require("ValueObject")
local DuckTypeUtils = require("DuckTypeUtils")

local AnimatedHighlightStack = setmetatable({}, BaseObject)
AnimatedHighlightStack.ClassName = "AnimatedHighlightStack"
AnimatedHighlightStack.__index = AnimatedHighlightStack

function AnimatedHighlightStack.new(adornee, defaultModelValues)
	local self = setmetatable(BaseObject.new(), AnimatedHighlightStack)

	self._adornee = assert(adornee, "No adornee")

	self._defaultModelValues = assert(defaultModelValues, "No defaultModelValues")

	self._list = self._maid:Add(ObservableSortedList.new())
	self._currentModel = self._maid:Add(AnimatedHighlightModel.new())
	self._hasEntries = self._maid:Add(ValueObject.new(false, "boolean"))

	self.Done = self._maid:Add(Signal.new())

	self._maid:GiveTask(self._list:ObserveCount():Pipe({
		Rx.switchMap(function(count)
			if count == 0 then
				return Rx.of(nil)
			else
				return self._list:ObserveAtIndex(count)
			end
		end);
		Rx.distinct()
	}):Subscribe(function(currentModel)
		if currentModel then
			self._maid._current = self:_setupModel(currentModel)
			self._hasEntries.Value = true
		else
			self._hasEntries.Value = false
			self._maid._current = nil
		end
	end))

	self:_setupHighlight()

	self._maid:GiveTask(self._hasEntries:Observe():Subscribe(function(isEnabled)
		if isEnabled then
			self._highlight:Show()
			self._maid._done = nil
		else
			self._highlight:Hide()
			self._maid._done = task.delay(1, function()
				self.Done:Fire()
			end)
		end
	end))

	self.Destroying = Signal.new()
	self._maid:GiveTask(function()
		self.Destroying:Fire()
		self.Destroying:Destroy()
	end)

	return self
end

--[=[
	Returns true if the value is an animated highlight stack

	@param value any
	@return boolean
]=]
function AnimatedHighlightStack.isAnimatedHighlightStack(value)
	return DuckTypeUtils.isImplementation(AnimatedHighlightStack, value)
end

--[=[
	Sets the stacks initial properties to mirror the given stacks

	@param source AnimatedHighlightStack
]=]
function AnimatedHighlightStack:SetPropertiesFrom(source)
	assert(AnimatedHighlightStack.isAnimatedHighlightStack(source), "Bad source")

	self._highlight:SetPropertiesFrom(source._highlight)
end

--[=[
	@return Observable<boolean>
]=]
function AnimatedHighlightStack:ObserveHasEntries()
	return self._hasEntries:Observe()
end

function AnimatedHighlightStack:_setupHighlight()
	local maid = Maid.new()

	self._highlight = AnimatedHighlight.new()
	self._highlight:SetAdornee(self._adornee)
	self._maid:GiveTask(self._highlight)

	maid:GiveTask(self._currentModel.HighlightDepthMode:Observe():Subscribe(function(value)
		if value then
			self._highlight:SetHighlightDepthMode(value)
		end
	end))
	maid:GiveTask(self._currentModel.FillColor:Observe():Subscribe(function(value, doNotAnimate)
		if value then
			self._highlight:SetFillColor(value, doNotAnimate)
		end
	end))
	maid:GiveTask(self._currentModel.OutlineColor:Observe():Subscribe(function(value, doNotAnimate)
		if value then
			self._highlight:SetOutlineColor(value, doNotAnimate)
		end
	end))
	maid:GiveTask(self._currentModel.FillTransparency:Observe():Subscribe(function(value, doNotAnimate)
		if value then
			self._highlight:SetFillTransparency(value, doNotAnimate)
		end
	end))
	maid:GiveTask(self._currentModel.OutlineTransparency:Observe():Subscribe(function(value, doNotAnimate)
		if value then
			self._highlight:SetOutlineTransparency(value, doNotAnimate)
		end
	end))
	maid:GiveTask(self._currentModel.ColorSpeed:Observe():Subscribe(function(value)
		if value then
			self._highlight:SetColorSpeed(value)
		end
	end))

	maid:GiveTask(self._currentModel.Speed:Observe():Subscribe(function(value)
		if value then
			self._highlight:SetSpeed(value)
		end
	end))
	maid:GiveTask(self._currentModel.TransparencySpeed:Observe():Subscribe(function(value)
		if value then
			self._highlight:SetTransparencySpeed(value)
		end
	end))

	return maid
end

function AnimatedHighlightStack:_setupModel(model)
	local maid = Maid.new()

	-- TODO: Default to default value instead
	local function filterNil(observeDefaultValue, observable)
		return observable:Pipe({
			Rx.switchMap(function(value)
				if value ~= nil then
					return Rx.of(value)
				else
					return observeDefaultValue
				end
			end);
			Rx.where(function(value)
				return value ~= nil
			end)
		})
	end

	maid:GiveTask(self._currentModel.HighlightDepthMode:Mount(filterNil(
		self._defaultModelValues.HighlightDepthMode:Observe(),
		model.HighlightDepthMode:Observe())))
	maid:GiveTask(self._currentModel.FillColor:Mount(filterNil(
		self._defaultModelValues.FillColor:Observe(),
		model.FillColor:Observe())))
	maid:GiveTask(self._currentModel.OutlineColor:Mount(filterNil(
		self._defaultModelValues.OutlineColor:Observe(),
		model.OutlineColor:Observe())))
	maid:GiveTask(self._currentModel.FillTransparency:Mount(filterNil(
		self._defaultModelValues.FillTransparency:Observe(),
		model.FillTransparency:Observe())))
	maid:GiveTask(self._currentModel.OutlineTransparency:Mount(filterNil(
		self._defaultModelValues.OutlineTransparency:Observe(),
		model.OutlineTransparency:Observe())))
	maid:GiveTask(self._currentModel.Speed:Mount(filterNil(
		self._defaultModelValues.Speed:Observe(),
		model.Speed:Observe())))
	maid:GiveTask(self._currentModel.TransparencySpeed:Mount(filterNil(
		self._defaultModelValues.TransparencySpeed:Observe(),
		model.TransparencySpeed:Observe())))

	return maid
end

--[=[
	Gets a new handle for the stack

	@param observeScore Observable<number>
	@return AnimatedHighlightModel
]=]
function AnimatedHighlightStack:GetHandle(observeScore)
	assert(observeScore, "No observeScore")

	local maid = Maid.new()

	local model = AnimatedHighlightModel.new()
	maid:GiveTask(model)

	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	maid:GiveTask(self._list:Add(model, observeScore))

	maid:GiveTask(model.Destroying:Connect(function()
		self._maid[maid] = nil
	end))

	return model
end

return AnimatedHighlightStack