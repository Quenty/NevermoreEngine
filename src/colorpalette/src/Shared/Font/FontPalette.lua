--[=[
	Holds fonts for reuse by giving fonts a semantic name. This makes theming easier in general.

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

--[=[
	Constructs a new font palette.

	@return FontPallete
]=]
function FontPalette.new()
	local self = setmetatable(BaseObject.new(), FontPalette)

	self._fonts = {}
	self._defaultFontMap = {} -- [name] = Enum.Font.?

	self.FontAdded = Signal.new() -- :Fire(name)
	self._maid:GiveTask(self.FontAdded)

	return self
end

--[=[
	Gets all available font names

	@return { string }
]=]
function FontPalette:GetFontNames()
	return Table.keys(self._fonts)
end

--[=[
	Observes all available font names as they are added starting with
	existing fonts.

	@return Observable<string>
]=]
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

--[=[
	Gets a font from name

	@param fontName string
	@return Enum.Font
]=]
function FontPalette:GetFont(fontName)
	assert(type(fontName) == "string", "Bad fontName")

	return self:GetFontValue(fontName).Value
end

--[=[
	Observes a font from name

	@param fontName string
	@return Observe<Enum.Font>
]=]
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

--[=[
	Gets a font value object for a given font.

	@param fontName string
	@return ValueObject<Enum.Font>
]=]
function FontPalette:GetFontValue(fontName)
	assert(type(fontName) == "string", "Bad fontName")

	local font = self._fonts[fontName]
	if not font then
		error(("No font with name %q"):format(fontName))
	end

	return font
end

--[=[
	Gets the default font map
	@return { string: Font }
]=]
function FontPalette:GetDefaultFontMap()
	return self._defaultFontMap
end

--[=[
	Defines a new font into the palette which can be changed over time.

	@param fontName string
	@param font Font
	@return ValueObject<Enum.Font>
]=]
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