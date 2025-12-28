--!strict
--[=[
	@class ColorPalette
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Blend = require("Blend")
local Brio = require("Brio")
local ColorGradePalette = require("ColorGradePalette")
local ColorGradeUtils = require("ColorGradeUtils")
local ColorSwatch = require("ColorSwatch")
local LuvColor3Utils = require("LuvColor3Utils")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local Rx = require("Rx")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local ColorPalette = setmetatable({}, BaseObject)
ColorPalette.ClassName = "ColorPalette"
ColorPalette.__index = ColorPalette

export type ColorPalette =
	typeof(setmetatable(
		{} :: {
			_swatches: { ColorSwatch.ColorSwatch },
			_gradePalette: ColorGradePalette.ColorGradePalette,
			_swatchMap: any,
			_colorGradeMap: any,
			_colorValues: { [string]: ValueObject.ValueObject<Color3> },
			_vividnessValues: { [string]: ValueObject.ValueObject<number> },

			ColorSwatchAdded: Signal.Signal<string>,
			ColorGradeAdded: Signal.Signal<string>,
		},
		{} :: typeof({ __index = ColorPalette })
	))
	& BaseObject.BaseObject

function ColorPalette.new(): ColorPalette
	local self: ColorPalette = setmetatable(BaseObject.new() :: any, ColorPalette)

	self._gradePalette = self._maid:Add(ColorGradePalette.new())

	self._swatchMap = self._maid:Add(ObservableMap.new())
	self._colorGradeMap = self._maid:Add(ObservableMap.new())
	self._colorValues = {}
	self._vividnessValues = {}

	self.ColorSwatchAdded = assert(self._swatchMap.KeyAdded, "No KeyAdded") -- :Fire(name)
	self.ColorGradeAdded = assert(self._colorGradeMap.KeyAdded, "No KeyAdded") -- :Fire(name)

	return self
end

function ColorPalette.GetSwatchNames(self: ColorPalette): { string }
	return self._swatchMap:GetKeyList()
end

function ColorPalette.ObserveSwatchNames(self: ColorPalette): Observable.Observable<{ string }>
	return Rx.fromSignal(self.ColorSwatchAdded :: any):Pipe({
		Rx.startFrom(function()
			return self:GetSwatchNames()
		end) :: any,
	}) :: any
end

function ColorPalette.ObserveSwatchNameList(self: ColorPalette): Observable.Observable<{ string }>
	return self._swatchMap:ObserveKeyList()
end

function ColorPalette.ObserveSwatchNamesBrio(self: ColorPalette)
	return self._swatchMap:ObserveKeysBrio()
end

function ColorPalette.GetGradeNames(self: ColorPalette): { string }
	return self._colorGradeMap:GetKeyList()
end

function ColorPalette.ObserveGradeNameList(self: ColorPalette)
	return self._colorGradeMap:ObserveKeyList()
end

function ColorPalette.ObserveGradeNames(self: ColorPalette): Observable.Observable<{ string }>
	return Rx.fromSignal(self.ColorGradeAdded :: any):Pipe({
		Rx.startFrom(function()
			return self:GetGradeNames()
		end) :: any,
	}) :: any
end

function ColorPalette.ObserveGradeNamesBrio(self: ColorPalette): Observable.Observable<Brio.Brio<string>>
	return self._colorGradeMap:ObserveKeysBrio()
end

function ColorPalette.GetColorValues(self: ColorPalette)
	return self._colorValues
end

function ColorPalette.GetColor(self: ColorPalette, color, grade, vividness)
	if type(color) == "string" then
		return self:GetColorSwatch(color)
			:GetGraded(self:_toGrade(grade, color), self:_toVividness(vividness, grade, color))
	elseif typeof(color) == "Color3" then
		return ColorGradeUtils.getGradedColor(
			color,
			self:_toGrade(grade, color),
			self:_toVividness(vividness, grade, color)
		)
	elseif typeof(color) == "Instance" and color:IsA("Color3Value") then
		return ColorGradeUtils.getGradedColor(
			color.Value,
			self:_toGrade(grade, color),
			self:_toVividness(vividness, grade, color)
		)
	else
		error("Bad color")
	end
end

function ColorPalette.ObserveColor(self: ColorPalette, color, grade, vividness): Observable.Observable<Color3>
	-- assert(type(color) == "string", "Bad color")

	if type(color) == "string" then
		return self:GetColorSwatch(color):ObserveGraded(
			self:_toGradeObservable(grade, color),
			self:_toVividnessObservable(vividness, grade, color)
		)
	end

	-- handle observable of color. this is for custom colors.
	local colorOrObservable
	if typeof(color) == "Color3" then
		colorOrObservable = color
	else
		colorOrObservable = Blend.toPropertyObservable(color)
	end

	-- compute graded color for custom color, but specific grades or vividness
	if colorOrObservable then
		if grade == nil and vividness == nil then
			-- no modification needed
			return colorOrObservable :: any
		end

		-- TODO: Optimize this potentially
		return Rx.combineLatest({
			baseColor = colorOrObservable,
			colorGrade = self:_toGradeObservable(grade, colorOrObservable),
			vividness = self:_toVividnessObservable(vividness, grade, colorOrObservable),
		}):Pipe({
			Rx.map(function(state)
				return ColorGradeUtils.getGradedColor(state.baseColor, state.colorGrade, state.vividness)
			end) :: any,
		}) :: any
	else
		error("Bad color")
	end
end

function ColorPalette.SetDefaultSurfaceName(self: ColorPalette, surfaceName: string)
	assert(type(surfaceName) == "string", "Bad surfaceName")

	self._gradePalette:SetDefaultSurfaceName(surfaceName)
end

function ColorPalette.GetColorSwatch(self: ColorPalette, colorName: string)
	local swatch = self._swatchMap:Get(colorName)
	if not swatch then
		error(string.format("No swatch with name %q", colorName))
	end

	return swatch
end

function ColorPalette.ObserveGradeOn(self: ColorPalette, colorName: string, newSurfaceName, baseSurfaceName)
	return self._gradePalette:ObserveOn(colorName, newSurfaceName, baseSurfaceName)
end

function ColorPalette._toGradeObservable(self: ColorPalette, grade, fallbackColorSource)
	if type(grade) == "string" then
		return (self._gradePalette:ObserveGrade(grade))
	elseif type(grade) == "number" then
		return Rx.of(grade)
	elseif Observable.isObservable(grade) then
		return grade
	else
		local propertyObservable = Blend.toPropertyObservable(grade)
		if propertyObservable then
			return propertyObservable
		end
	end

	-- Fallback
	if type(fallbackColorSource) == "string" then
		return (self._gradePalette:ObserveGrade(fallbackColorSource))
	elseif typeof(fallbackColorSource) == "Color3" then
		local luvColor = LuvColor3Utils.fromColor3(fallbackColorSource)
		return Rx.of(luvColor[3])
	elseif Observable.isObservable(fallbackColorSource) then
		return fallbackColorSource:Pipe({
			Rx.map(function(value)
				local luvColor = LuvColor3Utils.fromColor3(value)
				return luvColor[3]
			end),
		})
	else
		error("Bad fallbackColorSource argument")
	end
end

function ColorPalette._toVividnessObservable(self: ColorPalette, vividness, grade, colorOrObservable)
	if type(vividness) == "string" then
		return self._gradePalette:ObserveVividness(vividness)
	elseif type(vividness) == "number" then
		return Rx.of(vividness)
	elseif Observable.isObservable(vividness) then
		return vividness
	end

	local propertyObservable = Blend.toPropertyObservable(vividness)
	if propertyObservable then
		return propertyObservable
	end

	if type(grade) == "string" then
		-- Fall back to the grade value's vividness
		return self._gradePalette:ObserveVividness(grade)
	elseif type(colorOrObservable) == "string" then
		-- Fall back to color
		return self._gradePalette:ObserveVividness(colorOrObservable)
	else
		-- Vividness is pretty optional
		return Rx.of(nil)
	end
end

function ColorPalette._toGrade(self: ColorPalette, grade, name): number
	if type(grade) == "string" then
		return self._gradePalette:GetGrade(grade)
	elseif type(grade) == "number" then
		return grade
	else
		return self._gradePalette:GetGrade(name)
	end
end

function ColorPalette._toVividness(self: ColorPalette, vividness, grade, name): number
	if type(vividness) == "string" then
		return self._gradePalette:GetVividness(vividness)
	elseif type(vividness) == "number" then
		return vividness
	elseif type(grade) == "string" then
		-- Fall back to the grade value
		return self._gradePalette:GetVividness(grade)
	else
		-- Otherwise fall back to name of color
		return self._gradePalette:GetVividness(name)
	end
end

function ColorPalette.GetColorValue(self: ColorPalette, colorName: string)
	assert(type(colorName) == "string", "Bad colorName")

	local colorValue = self._colorValues[colorName]
	if not colorValue then
		error(string.format("No color with name %q", colorName))
	end

	return colorValue
end

function ColorPalette.GetGradeValue(self: ColorPalette, gradeName: string): ValueObject.ValueObject<number>
	local gradeValue = self._colorGradeMap:Get(gradeName)
	if not gradeValue then
		error(string.format("No grade with name %q", gradeName))
	end

	return gradeValue
end

function ColorPalette.GetVividnessValue(self: ColorPalette, gradeName: string): ValueObject.ValueObject<number>
	local vividnessValue = self._vividnessValues[gradeName]
	if not vividnessValue then
		error(string.format("No grade with name %q", gradeName))
	end

	return vividnessValue
end

function ColorPalette.ObserveModifiedGrade(self: ColorPalette, gradeName, amount, multiplier)
	return self._gradePalette:ObserveModified(gradeName, amount, multiplier)
end

function ColorPalette.ObserveGrade(self: ColorPalette, name)
	return self._gradePalette:ObserveGrade(name)
end

function ColorPalette.ObserveVividness(self: ColorPalette, name)
	return self._gradePalette:ObserveVividness(name)
end

function ColorPalette.GetSwatch(self: ColorPalette, swatchName: string)
	assert(type(swatchName) == "string", "Bad swatchName")

	local swatch = self._swatchMap:Get(swatchName)
	if not swatch then
		error(string.format("No swatch with name %q", swatchName))
	end

	return swatch
end

--[=[
	@param colorName string
	@param color Observable<Color3> | Color3
]=]
function ColorPalette.SetColor(self: ColorPalette, colorName, color)
	assert(type(colorName) == "string", "Bad colorName")

	if not self._colorValues[colorName] then
		error(string.format("No color grade with name %q", colorName))
	end

	return self._colorValues[colorName]:Mount(color)
end

function ColorPalette.SetVividness(self: ColorPalette, gradeName, vividness)
	assert(type(gradeName) == "string", "Bad colorName")

	if not self._vividnessValues[gradeName] then
		error(string.format("No vividness with name %q", gradeName))
	end

	return self._vividnessValues[gradeName]:Mount(vividness)
end

function ColorPalette.SetColorGrade(self: ColorPalette, gradeName, grade)
	assert(type(gradeName) == "string", "Bad colorName")
	assert(grade, "Bad grade")

	local gradeValue = self._colorGradeMap:Get(gradeName)
	if not gradeValue then
		error(string.format("No color grade with name %q", gradeName))
	end

	return gradeValue:Mount(grade)
end

function ColorPalette.ObserveColorBaseGradeBetween(self: ColorPalette, colorName, low, high)
	assert(type(colorName) == "string", "Bad colorName")

	return self:GetSwatch(colorName):ObserveBaseGradeBetween(low, high)
end

function ColorPalette.DefineColorGrade(self: ColorPalette, gradeName, gradeValue, vividnessValue)
	assert(type(gradeName) == "string", "Bad gradeName")

	if self._colorGradeMap:Get(gradeName) then
		warn(string.format("[ColorPalette.DefineColorGrade] - Already defined grade of name %q", gradeName))
		return
	end

	local colorGrade = self._maid:Add(ValueObject.new(0, "number"))
	colorGrade:Mount(gradeValue or 0)

	local vividness = self._maid:Add(ValueObject.new(nil))
	vividness:Mount(vividnessValue)

	self._vividnessValues[gradeName] = vividness

	self._gradePalette:Add(gradeName, colorGrade, vividness)
	self._colorGradeMap:Set(gradeName, colorGrade)

	return colorGrade
end

function ColorPalette.DefineColorSwatch(self: ColorPalette, colorName, value)
	assert(type(colorName) == "string", "Bad colorName")

	if self._swatchMap:Get(colorName) then
		warn(string.format("[ColorPalette.DefineColorGrade] -Already defined color of name %q", colorName))
		return
	end

	local colorValue = self._maid:Add(ValueObject.new(value or Color3.new(0, 0, 0), "Color3"))
	local colorSwatch = self._maid:Add(ColorSwatch.new(colorValue :: any))

	self._colorValues[colorName] = colorValue

	self._swatchMap:Set(colorName, colorSwatch)

	return colorSwatch
end

return ColorPalette
