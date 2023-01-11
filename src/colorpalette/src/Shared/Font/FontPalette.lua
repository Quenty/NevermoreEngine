--[=[
	@class FontPalette
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Signal = require("Signal")
local Table = require("Table")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local FontPalette = setmetatable({}, BaseObject)
FontPalette.ClassName = "FontPalette"
FontPalette.__index = FontPalette

function FontPalette.new()
	local self = setmetatable(BaseObject.new(), FontPalette)

	self._fonts = {}
	self._defaultFontMap = {} -- [name] = Enum.Font.?

	self.FontAdded = Signal.new() -- :Fire(name)
	self._maid:GiveTask(self.FontAdded)

	return self
end

function FontPalette:GetFontNames()
	return Table.keys(self._fonts)
end

function FontPalette:ObserveFontNames()
	return Rx.fromSignal(self.FontAdded):Pipe({
		Rx.startFrom(function()
			if self.Destroy then
				return self:GetFontNames()
			else
				warn("[FontPalette.ObserveFontNames] - Calling when FontPalette is already dead")
				return {}
			end
		end)
	})
end

function FontPalette:GetFont(fontName)
	assert(type(fontName) == "string", "Bad fontName")

	return self:GetFontValue(fontName).Value
end

function FontPalette:ObserveFont(fontName)
	assert(type(fontName) == "string", "Bad fontName")

	return self:GetFontValue(fontName):Observe()
end

--[=[
	Observes the curent font face defined for the font name

	@param fontName string
	@param weight FontWeight | Observable<FontWeight> | nil
	@param style FontStyle | Observable<FontStyle> | nil
	@return Observable<Font>
]=]
function FontPalette:ObserveFontFace(fontName, weight, style)
	assert(type(fontName) == "string", "Bad fontName")

	return Rx.combineLatest({
		family = self:GetFontValue(fontName):Observe():Pipe({
			Rx.map(function(fontEnum)
				return Font.fromEnum(fontEnum).Family
			end);
		});
		weight = weight or Enum.FontWeight.Regular;
		style = style or Enum.FontStyle.Normal;
	}):Pipe({
		Rx.map(function(state)
			return Font.new(state.family, state.weight, state.style)
		end);
	})
end

function FontPalette:GetFontValue(fontName)
	assert(type(fontName) == "string", "Bad fontName")

	local font = self._fonts[fontName]
	if not font then
		error(("No font with name %q"):format(fontName))
	end

	return font
end

function FontPalette:GetDefaultFontMap()
	return self._defaultFontMap
end

function FontPalette:DefineFont(fontName, font)
	assert(type(fontName) == "string", "Bad fontName")
	assert(typeof(font) == "EnumItem", "Bad font")

	if self._fonts[fontName] then
		warn(("Already defined font of name %q"):format(fontName))
		return
	end

	local fontValue = ValueObject.new(font)
	self._maid:GiveTask(fontValue)

	self._fonts[fontName] = fontValue
	self._defaultFontMap[fontName] = font

	self.FontAdded:Fire(fontName)

	return fontValue
end

return FontPalette