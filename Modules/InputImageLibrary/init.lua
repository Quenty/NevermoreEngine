--- Input image library
-- @module InputImageLibrary

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local InputImageLibrary = {}
InputImageLibrary.ClassName = "InputImageLibrary"
InputImageLibrary.__index = InputImageLibrary

function InputImageLibrary.new(parentFolder)
	local self = setmetatable({}, InputImageLibrary)

	self._spritesheets = {}
	self:_loadSpriteSheets(parentFolder)

	return self
end

function InputImageLibrary:_loadSpriteSheets(parentFolder)
	for _, platform in pairs(parentFolder:GetChildren()) do
		self._spritesheets[platform.Name] = {}
		for _, style in pairs(platform:GetChildren()) do
			if style:IsA("ModuleScript") then
				self._spritesheets[platform.Name][style.Name] = require(style).new()
			end
		end
	end
end

---
-- @treturn Sprite
function InputImageLibrary:GetSprite(index, preferredStyle, preferredPlatform)
	local sheet = self:_pickSheet(index, preferredStyle, preferredPlatform)
	if sheet then
		return sheet:GetSprite(index)
	end

	return nil
end

function InputImageLibrary:GetScaledImageLabel(keyCode, preferredStyle, preferredPlatform)
	local image = self:_getImageInstance("ImageLabel", keyCode, preferredStyle or "Dark", preferredPlatform)
	if not image then
		return nil
	end

	local size = image.Size
	local ratio = size.Y.Offset/size.X.Offset

	local uiAspectRatio = Instance.new("UIAspectRatioConstraint")
	uiAspectRatio.DominantAxis = Enum.DominantAxis.Height
	uiAspectRatio.AspectRatio = ratio
	uiAspectRatio.Parent = image

	image.Size = UDim2.new(1, 0, 1, 0)

	return image
end

function InputImageLibrary:_pickSheet(index, preferredStyle, preferredPlatform)
	local function findSheet(platformSheets)
		local preferredSheet = platformSheets[preferredStyle]
		if preferredSheet and preferredSheet:HasSprite(index) then
			return preferredSheet
		end

		-- otherwise search (yes, we double hit a sheet)
		for _, sheet in pairs(platformSheets) do
			if sheet:HasSprite(index) then
				return sheet
			end
		end
	end

	local sheet = self._spritesheets[preferredPlatform]
	local preferredSheet = sheet and findSheet(sheet)
	if preferredSheet then
		return preferredSheet
	end

	-- otherwise search (repeats preferred :/ )
	for _, platformSheets in pairs(self._spritesheets) do
		local foundSheet = findSheet(platformSheets)
		if foundSheet then
			return foundSheet
		end
	end

	warn("[InputImageLibrary] - Unable to find sprite for", tostring(index), "type", typeof(index))

	return nil
end


function InputImageLibrary:_getImageInstance(instanceType, index, preferredStyle, preferredPlatform)
	local sheet = self:_pickSheet(index, preferredStyle, preferredPlatform)
	if sheet then
		return sheet:GetSprite(index):Get(instanceType)
	end

	return nil
end

return InputImageLibrary.new(script:WaitForChild("Spritesheets"))
