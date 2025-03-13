--[=[
	Provides variants of a given color. In painting a swatch contains different shades of the same color.
	The same idea is here, except we can provide many variants of a color, with different vividness and brightness
	grades.

	@class ColorSwatch
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local Blend = require("Blend")
local LuvColor3Utils = require("LuvColor3Utils")
local ColorGradeUtils = require("ColorGradeUtils")
local Rx = require("Rx")
local Observable = require("Observable")

local ColorSwatch = setmetatable({}, BaseObject)
ColorSwatch.ClassName = "ColorSwatch"
ColorSwatch.__index = ColorSwatch

function ColorSwatch.new(color, vividness)
	local self = setmetatable(BaseObject.new(), ColorSwatch)

	self._color = ValueObject.new(Color3.new(0, 0, 0))
	self._maid:GiveTask(self._color)

	self._vividness = self._maid:Add(ValueObject.new(nil))

	self:SetBaseColor(color)
	self:SetVividness(vividness)

	self.Changed = self._color.Changed

	return self
end

function ColorSwatch:GetGraded(colorGrade: number)
	assert(type(colorGrade) == "number", "Bad colorGrade")

	return ColorGradeUtils.getGradedColor(self._color.Value, colorGrade, self._vividness.Value)
end

function ColorSwatch:ObserveGraded(colorGrade, vividness)
	assert(type(colorGrade) == "number" or Observable.isObservable(colorGrade), "Bad colorGrade")

	local observeColorGrade = Blend.toPropertyObservable(colorGrade) or Rx.of(colorGrade)

	local observeVividness
	if vividness then
		observeVividness = Blend.toPropertyObservable(vividness) or Rx.of(vividness)
	else
		observeVividness = self:ObserveVividness()
	end

	return Rx.combineLatest({
		colorGrade = observeColorGrade;
		vividness = observeVividness;
		baseColor = self:ObserveBaseColor()
	}):Pipe({
		Rx.map(function(state)
			return ColorGradeUtils.getGradedColor(state.baseColor, state.colorGrade, state.vividness)
		end);
	})
end

function ColorSwatch:ObserveBaseColor()
	return self._color:Observe()
end

function ColorSwatch:ObserveVividness()
	return self._vividness:Observe()
end

function ColorSwatch:GetBaseColor()
	return self._color.Value
end

function ColorSwatch:GetBaseGrade()
	return 100 - LuvColor3Utils.fromColor3(self._color.Value)[3]
end

function ColorSwatch:ObserveBaseGrade()
	return self._color:Observe():Pipe({
		Rx.map(function(color)
			return 100 - LuvColor3Utils.fromColor3(color)[3]
		end)
	})
end

function ColorSwatch:ObserveBaseGradeBetween(low, high)
	return self:ObserveBaseGrade():Pipe({
		Rx.map(function(grade)
			return math.clamp(grade, low, high)
		end)
	})
end

function ColorSwatch:GetVividness()
	return self._vividness.Value
end

function ColorSwatch:SetVividness(vividness)
	if type(vividness) == "number" then
		self._vividness.Value = vividness
		self._maid._currentVividness = nil
		return
	end


	local observable = Blend.toPropertyObservable(vividness)
	if not observable then
		self._maid._currentVividness = nil
		return
	end

	self._maid._currentColor = observable:Subscribe(function(value)
		if type(value) == "number" then
			self._vividness.Value = value
		else
			warn("[ColorSwatch.SetVividness] - Observed value was not a valid number")
		end
	end)
end

function ColorSwatch:SetBaseColor(color)
	if typeof(color) == "Color3" then
		self._color.Value = color
		self._maid._currentColor = nil
		return
	end

	local observable = Blend.toPropertyObservable(color)
	if not observable then
		self._maid._currentColor = nil
		return
	end

	self._maid._currentColor = observable:Subscribe(function(value)
		if typeof(value) == "Color3" then
			self._color.Value = value
		else
			warn("[ColorSwatch.SetBaseColor] - Resulting value was not a valid color")
		end
	end)
end

return ColorSwatch