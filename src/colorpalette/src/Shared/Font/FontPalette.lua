--[=[
	Holds fonts for reuse by giving fonts a semantic name. This makes theming easier in general.

	@class FontPalette
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Rx = require("Rx")
local ValueObject = require("ValueObject")
local ObservableSet = require("ObservableSet")
local _Observable = require("Observable")

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
	self._fontFaces = {}
	self._defaultFontMap = {} -- [name] = Enum.Font.?

	self._fontKeys = self._maid:Add(ObservableSet.new())

	self.FontAdded = assert(self._fontKeys.ItemAdded, "No ItemAdded") -- :Fire(name)

	return self
end

--[=[
	Gets all available font names

	@return { string }
]=]
function FontPalette:GetFontNames(): { string }
	return self._fontKeys:GetList()
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
		end),
	})
end

--[=[
	Observes all available font names as they are added starting with
	existing fonts.

	@return Observable<Brio<string>>
]=]
function FontPalette:ObserveFontNamesBrio()
	return self._fontKeys:ObserveItemsBrio()
end

--[=[
	Gets a font from name

	@param fontName string
	@return Enum.Font
]=]
function FontPalette:GetFont(fontName: string): Enum.Font
	assert(type(fontName) == "string", "Bad fontName")

	return self:GetFontValue(fontName).Value
end

--[=[
	Observes a font from name

	@param fontName string
	@return Observe<Enum.Font>
]=]
function FontPalette:ObserveFont(fontName: string): _Observable.Observable<Enum.Font>
	assert(type(fontName) == "string", "Bad fontName")

	return self:GetFontValue(fontName):Observe()
end

--[=[
	Observes the curent font face defined for the font name

	@param fontName string
	@param weight (FontWeight | Observable<FontWeight>)?
	@param style (FontStyle | Observable<FontStyle>)?
	@return Observable<Font>
]=]
function FontPalette:ObserveFontFace(
	fontName: string,
	weight: (Enum.FontWeight | _Observable.Observable<Enum.FontWeight>)?,
	style: (Enum.FontStyle | _Observable.Observable<Enum.FontWeight>)?
)
	assert(type(fontName) == "string", "Bad fontName")

	if weight == nil and style == nil then
		return self:GetFontFaceValue(fontName):Observe()
	end

	return Rx.combineLatest({
		font = self:GetFontFaceValue(fontName):Observe(),
		weight = weight,
		style = style,
	}):Pipe({
		Rx.map(function(state)
			return Font.new(state.font.Family, state.weight or state.font.Weight, state.style or state.font.Style)
		end),
	})
end

--[=[
	Gets a font value object for a given font.

	@param fontName string
	@return ValueObject<Font>
]=]
function FontPalette:GetFontFaceValue(fontName: string): Font
	assert(type(fontName) == "string", "Bad fontName")

	local fontValue = self._fontFaces[fontName]
	if not fontValue then
		error(string.format("No font with name %q", fontName))
	end

	return fontValue
end

--[=[
	Gets a font value object for a given font.

	@param fontName string
	@return ValueObject<Font>
]=]
function FontPalette:GetFontValue(fontName: string): ValueObject.ValueObject<Enum.Font>
	assert(type(fontName) == "string", "Bad fontName")

	local fontValue = self._fonts[fontName]
	if not fontValue then
		error(string.format("No font with name %q", fontName))
	end

	return fontValue
end

--[=[
	Gets the default font map
	@return { string: Font }
]=]
function FontPalette:GetDefaultFontMap(): { string: Font }
	return self._defaultFontMap
end

--[=[
	Defines a new font into the palette which can be changed over time.

	@param fontName string
	@param defaultFont Enum.Font | Font
	@return ValueObject<Enum.Font | Font>
]=]
function FontPalette:DefineFont(fontName: string, defaultFont: Enum.Font | Font): ValueObject.ValueObject<Enum.Font | Font>?
	assert(type(fontName) == "string", "Bad fontName")
	assert(typeof(defaultFont) == "EnumItem" or typeof(defaultFont) == "Font", "Bad defaultFont")

	if self._fonts[fontName] then
		warn(string.format("Already defined defaultFont of name %q", fontName))
		return nil
	end

	local defaultFontEnum
	local defaultFontFace
	if typeof(defaultFont) == "EnumItem" then
		defaultFontEnum = defaultFont
		defaultFontFace = Font.fromEnum(defaultFont)
	elseif typeof(defaultFont) == "Font" then
		defaultFontEnum = defaultFont
		defaultFontFace = defaultFont
	else
		error("Bad defaultFont")
	end

	local fontValue = self._maid:Add(ValueObject.new(defaultFontEnum))
	local fontFaceValue = self._maid:Add(ValueObject.new(defaultFontFace))

	self._fonts[fontName] = fontValue
	self._fontFaces[fontName] = fontFaceValue
	self._defaultFontMap[fontName] = defaultFont

	self._maid:GiveTask(fontFaceValue.Changed:Connect(function(fontFace)
		fontValue.Value = self:_tryToGetFontFace(fontFace)
	end))

	self._maid:GiveTask(fontValue.Changed:Connect(function(fontEnum)
		-- Assume fontFace is set with something reasonable
		if fontEnum ~= Enum.Font.Unknown then
			local font = Font.fromEnum(fontEnum)
			local current = fontFaceValue.Value
			fontFaceValue.Value = Font.new(font.Family, current.Weight, current.Style)
		end
	end))

	self._fontKeys:Add(fontName)

	return fontValue
end

function FontPalette:_tryToGetFontFace(fontFace: Font)
	local assetName = string.gmatch(fontFace.Family, "rbxasset://fonts/families/([%w]+).json$")()

	local fontEnum
	pcall(function()
		fontEnum = Enum.Font[assetName]
	end)

	if fontEnum then
		return fontEnum
	else
		return Enum.Font.Unknown
	end
end

return FontPalette