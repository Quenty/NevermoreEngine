--[=[
	InputImageLibrary with a variety of dark and light themed icons for inputs on keyboard, xbox, touched events,
	mouse, and more.

	@class InputImageLibrary
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")

local SUPRESS_UNFOUND_IMAGE_WARNING = true

local InputImageLibrary = {}
InputImageLibrary.ClassName = "InputImageLibrary"
InputImageLibrary.__index = InputImageLibrary

function InputImageLibrary.new(parentFolder)
	local self = setmetatable({}, InputImageLibrary)

	self._spritesheets = {} -- [platform][style] = sheet
	self:_loadSpriteSheets(parentFolder)

	return self
end

--[=[
	Retrieves all the asset ids to preload

	@return { string }
]=]
function InputImageLibrary:GetPreloadAssetIds(): { string }
	local assets = {}
	for _, platformSheets in self._spritesheets do
		for _, sheet in platformSheets do
			table.insert(assets, sheet:GetPreloadAssetId())
		end
	end
	return assets
end

function InputImageLibrary:_loadSpriteSheets(parentFolder: Instance)
	assert(typeof(parentFolder) == "Instance", "Bad parentFolder")

	for _, platform in parentFolder:GetChildren() do
		self._spritesheets[platform.Name] = {}
		for _, style in platform:GetChildren() do
			if style:IsA("ModuleScript") then
				self._spritesheets[platform.Name][style.Name] = require(style).new()
			end
		end
	end
end

--[=[
	Retrieves a sprite from the library

	@param keyCode any -- The sprite keyCode to get
	@param preferredStyle string? -- The preferred style type to retrieve this in
	@param preferredPlatform string? -- The preferred platform to get the sprite for
	@return Sprite
]=]
function InputImageLibrary:GetSprite(keyCode, preferredStyle: string?, preferredPlatform: string?)
	assert(keyCode ~= nil, "Bad keyCode")
	assert(type(preferredStyle) == "string" or preferredStyle == nil, "Bad preferredStyle")
	assert(type(preferredPlatform) == "string" or preferredPlatform == nil, "Bad preferredPlatform")

	local sheet = self:PickSheet(keyCode, preferredStyle, preferredPlatform)
	if sheet then
		return sheet:GetSprite(keyCode)
	end

	return nil
end

--[=[
	Styles a GUI for a specific keycode

	```lua
	local InputImageLibrary = require("InputImageLibrary")
	InputImageLibrary:StyleImage(script.Parent, Enum.KeyCode.ButtonA)
	```

	@param gui ImageLabel | ImageButton
	@param keyCode any -- The sprite keyCode to get
	@param preferredStyle string? -- The preferred style type to retrieve this in
	@param preferredPlatform string? -- The preferred platform to get the sprite for
	@return Sprite
]=]
function InputImageLibrary:StyleImage(gui, keyCode, preferredStyle: string?, preferredPlatform: string?)
	assert(typeof(gui) == "Instance" and (gui:IsA("ImageLabel") or gui:IsA("ImageButton")), "Bad gui")
	assert(keyCode ~= nil, "Bad keyCode")
	assert(type(preferredStyle) == "string" or preferredStyle == nil, "Bad preferredStyle")
	assert(type(preferredPlatform) == "string" or preferredPlatform == nil, "Bad preferredPlatform")

	local sheet = self:PickSheet(keyCode, preferredStyle, preferredPlatform)
	if sheet then
		return sheet:GetSprite(keyCode):Style(gui)
	end

	return nil
end

function InputImageLibrary:_getDefaultPreferredPlatform()
	-- Hack to select the right preferred platform
	-- TODO: Maybe pass this into our selector?
	local result = UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonA)
	if not result then
		return nil
	end

	if string.find(result, "PlayStation", nil, true) then
		return "PlayStation"
	elseif string.find(result, "Xbox", nil, true) then
		return "XBox"
	else
		return "XBox"
	end
end

function InputImageLibrary:GetScaledImageLabel(keyCode, preferredStyle: string?, preferredPlatform: string?)
	assert(keyCode ~= nil, "Bad keyCode")
	assert(type(preferredStyle) == "string" or preferredStyle == nil, "Bad preferredStyle")
	assert(type(preferredPlatform) == "string" or preferredPlatform == nil, "Bad preferredPlatform")

	local image = self:_getImageInstance("ImageLabel", keyCode, preferredStyle or "Dark", preferredPlatform)
	if not image then
		return nil
	end

	local size = image.Size
	local ratio = size.Y.Offset / size.X.Offset

	local uiAspectRatio = Instance.new("UIAspectRatioConstraint")
	uiAspectRatio.DominantAxis = Enum.DominantAxis.Height
	uiAspectRatio.AspectRatio = ratio
	uiAspectRatio.Parent = image

	image.Size = UDim2.new(1, 0, 1, 0)

	return image
end

function InputImageLibrary:PickSheet(keyCode, preferredStyle: string?, preferredPlatform: string?)
	assert(keyCode ~= nil, "Bad keyCode")
	assert(type(preferredStyle) == "string" or preferredStyle == nil, "Bad preferredStyle")
	assert(type(preferredPlatform) == "string" or preferredPlatform == nil, "Bad preferredPlatform")

	local function findSheet(platformSheets)
		local preferredSheet = platformSheets[preferredStyle]
		if preferredSheet and preferredSheet:HasSprite(keyCode) then
			return preferredSheet
		end

		-- otherwise search (yes, we double hit a sheet)
		for _, sheet in platformSheets do
			if sheet:HasSprite(keyCode) then
				return sheet
			end
		end

		return nil
	end

	preferredPlatform = preferredPlatform or self:_getDefaultPreferredPlatform()

	if preferredPlatform then
		local sheet = self._spritesheets[preferredPlatform]
		local preferredSheet = sheet and findSheet(sheet)
		if preferredSheet and preferredSheet:HasSprite(keyCode) then
			return preferredSheet
		end
	end

	-- otherwise search (repeats preferred :/ )
	for _, platformSheets in self._spritesheets do
		local foundSheet = findSheet(platformSheets)
		if foundSheet then
			return foundSheet
		end
	end

	if not SUPRESS_UNFOUND_IMAGE_WARNING then
		warn("[InputImageLibrary] - Unable to find sprite for", tostring(keyCode), "type", typeof(keyCode))
	end

	return nil
end


function InputImageLibrary:_getImageInstance(instanceType, keyCode, preferredStyle, preferredPlatform)
	assert(type(instanceType) == "string", "Bad instanceType")
	assert(keyCode ~= nil, "Bad keyCode")
	assert(type(preferredStyle) == "string" or preferredStyle == nil, "Bad preferredStyle")
	assert(type(preferredPlatform) == "string" or preferredPlatform == nil, "Bad preferredPlatform")

	local sheet = self:PickSheet(keyCode, preferredStyle, preferredPlatform)
	if sheet then
		return sheet:GetSprite(keyCode):Get(instanceType)
	end

	return nil
end

return InputImageLibrary.new(script:WaitForChild("Spritesheets"))
