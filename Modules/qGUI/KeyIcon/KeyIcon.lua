local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local FunctionMap        = LoadCustomLibrary("FunctionMap")
local qGUI               = LoadCustomLibrary("qGUI")

-- KeyIcon.lua
-- @author Quenty
-- This is a GUI element that indicates input (a key!) to a player.

local function Map(ItemList, Function, ...)
	-- @param ItemList The items to map the function to
	-- @param Function The function to be called
		-- Function(ItemInList, [...])
			-- @param ItemInList The item mapped to the function
			-- @param [...] Extra arguments passed into the map function
	-- @param [...] The extra arguments passed in after the Item in the function being mapped

	for _, Item in pairs(ItemList) do
		Function(Item, ...)
	end
end

local KeyIcon     = {}
KeyIcon.__index   = KeyIcon
KeyIcon.ClassName = "KeyIcon"

KeyIcon.DefaultIconData = {
	Image     = "rbxassetid://245857779";
	ImageSize = Vector2.new(30, 30);
}
KeyIcon.DefaultFillIconData = {
	Image     = "rbxassetid://245608758";
	ImageSize = Vector2.new(150, 150);
}

-- CONSTRUCTION

function KeyIcon.new(GUI, FillFrameTween)
	-- @param GUI The parent of both the outline and fillframe, the text of this label
	--            also forms the basis of a key icon. Assumedly a TextLabel, but it doesn't
	--            have to be
	-- @param OutlineTween The functionmap that tweens for the outline of the KeyIcon. Makes 
	--                     some more  assumptions that all of its GUIs are parented to it. This 
	--                     controlsanimations, using the Tween method, and can be combined however
	--                     one likes.
	-- @param FillFrames The same as the OutlineTween, but for the fill of the KeyIcon.

	local self = {}
	setmetatable(self, KeyIcon)

	self.GUI            = GUI
	--self.OutlineTween   = OutlineTween
	self.FillFrameTween = FillFrameTween

	self:RescaleWidth()

	return self
end

function KeyIcon.NewDefaultTextLabel(Height)
	--- Creates a new default text label to be used by the KeyIcon.

	Height = Height or 30

	local TextLabel                  = Instance.new("TextLabel")
	TextLabel.Name                   = "DefaultKeyIcon"
	TextLabel.Size                   = UDim2.new(0, Height, 0, Height)
	TextLabel.BackgroundTransparency = 1
	TextLabel.TextColor3             = Color3.new(1, 1, 1)
	TextLabel.BorderSizePixel        = 0
	TextLabel.Font                   = "Arial"
	TextLabel.FontSize               = "Size18"
	TextLabel.Text                   = "X"

	return TextLabel
end

function KeyIcon.NewDefaultImageLabel(Height, ImageURL)
	Height = Height or 30

	local ImageLabel                  = Instance.new("ImageLabel")
	ImageLabel.Name                   = "DefaultKeyIcon"
	ImageLabel.Size                   = UDim2.new(0, Height, 0, Height)
	ImageLabel.BackgroundTransparency = 1
	ImageLabel.BorderSizePixel        = 0
	ImageLabel.Image                  = ImageURL or error("No Image URL")

	return ImageLabel
end

function KeyIcon.NewDefault(Height, ImageData)
	--- Creates a new "default" KeyIcon to be used.
	-- @param [Height=30] The height of the icon
	-- @param [ImageData] The ImageData of the icon to use
	--                    Has two fields, "ImageData.Fill" and "ImageData.Default"
	-- @return The new KeyIcon produced


	if ImageData then
		local ImageLabel = KeyIcon.NewDefaultImageLabel(Height, ImageData.Default)
		return KeyIcon.FromBaseGUIImage(ImageLabel, ImageData)
	else
		local TextLabel = KeyIcon.NewDefaultTextLabel(Height)
		return KeyIcon.FromBaseGUI(TextLabel, KeyIcon.DefaultIconData, KeyIcon.DefaultFillIconData)
	end
end




local function TweenFunctionFactory(Properties, Function, Transform)
	-- Hardcore functional programming here.
	-- Properties is a table
	-- Function is the animation function
	-- Transform transforms the PercentTransparency per property...
	return function (Item, PercentTransparency, AnimationTime)

		local TweenData = {}
		for _, PropertyName in pairs(Properties) do
			TweenData[PropertyName] = Transform(PercentTransparency, PropertyName)
		end

		Function(Item, TweenData, AnimationTime, true)
	end
end


function KeyIcon.FromBaseGUIImage(GUI, ImageData)
	local Secondary = KeyIcon.NewDefaultImageLabel(nil, ImageData.Fill or error("No fill data"))
	Secondary.Size = UDim2.new(1, 0, 1, 0)
	Secondary.ZIndex = GUI.ZIndex - 1
	Secondary.Name = "FillIcon"
	Secondary.Parent = GUI
	Secondary.ImageTransparency = 1

	local FillMap = FunctionMap.new({Secondary},
		TweenFunctionFactory({"ImageTransparency"}, qGUI.TweenTransparency, 
			function(PercentTransparency, PropertyName)
				return PercentTransparency
			end))

	return KeyIcon.new(GUI, FillMap)
end

function KeyIcon.FromBaseGUI(GUI, OutlineImageData, FillImageData)
	--- Creates a new KeyIcon from a GUI and some OutlineImageData and FillImageData
	-- @param GUI The GUI to used as the base of the KeyIcon. Should include the actual icon image
	--            whether that be text or an image is up to the user. 
	-- @param OutlineImageData Table, The data to be used to generate a NinePatch from qGUI. Should
	--                         include ["Image"] = "rbxasset URL"; and ["ImageSize"] = number; for the
	--                         size in pixels of the image.
	-- @return The new KeyIcon that was produced

	local OutlineLabels = {qGUI.AddNinePatch(GUI, OutlineImageData.Image, OutlineImageData.ImageSize, 7, "ImageLabel")}
	local FillFrames    = {qGUI.AddNinePatch(GUI, FillImageData.Image, FillImageData.ImageSize, 7, "ImageLabel")}

	local function SetZIndex(Item)
		Item.ZIndex = GUI.ZIndex - 1
	end

	Map(OutlineLabels, SetZIndex)
	Map(FillFrames,    function(Item)
		SetZIndex(Item)
		Item.ImageTransparency = 1
	end)


	local FillMap = FunctionMap.new(FillFrames, 
		TweenFunctionFactory({"ImageTransparency"}, qGUI.TweenTransparency, 
			function(PercentTransparency, PropertyName)
				return PercentTransparency
			end))

	if GUI:IsA("TextLabel") then
		FillMap:AddChild(FunctionMap.new({GUI}, 
			TweenFunctionFactory({"TextColor3"}, qGUI.TweenColor3, 
				function(PercentTransparency, PropertyName)
					return Color3.new(PercentTransparency^2, PercentTransparency^2, PercentTransparency^2)
				end)))
	end

	--[[local OutlineMap = FunctionMap.new(OutlineLabels, 
		TweenFunctionFactory({"ImageTransparency"}, qGUI.TweenTransparency, 
			function(PercentTransparency, PropertyName)
				return PercentTransparency
			end)))--]]

	return KeyIcon.new(GUI, FillMap) --return KeyIcon.new(GUI, OutlineMap, FillMap)
end



-- METHODS

function KeyIcon:SetFillTransparency(PercentTransparency, AnimationTime)
	--- Sets the fill of the KeyIcon to a specific transparency. Used to indicate state. 
	-- @param PercentTransparency Number [0, 1], where 1 is completely transparency
	-- @param [AnimationTime] The time to animate the outline. Defaults at 0.2.

	AnimationTime = AnimationTime or 0.2 
	self.FillFrameTween:Map(PercentTransparency, AnimationTime, true)
end
--[[
function KeyIcon:SetOutlineTransparency(PercentTransparency, AnimationTime)
	--- Sets the outline of the KeyIcon to a specific transparency
	-- @param PercentTransparency Number [0, 1], where 1 is completely transparency
	-- @param [AnimationTime] The time to animate the outline. Defaults at 0.2.

	AnimationTime = AnimationTime or 0.2 
	self.OutlineTween:Map(PercentTransparency, AnimationTime, true)
end--]]

function KeyIcon:RescaleWidth()
	--- Used with TextLabels to rescale the width. Note: Only works if the icon is parented.

	if self.GUI:IsA("TextLabel") then
		local Y = self.GUI.Size.Y
		local X = self.GUI.Size.X

		self.GUI.Size = UDim2.new(0, math.max(X.Offset, self.GUI.TextBounds.X + 16), Y.Scale, Y.Offset)
	end

	self.Width = self.GUI.Size.X.Offset
end


function KeyIcon:Destroy()
	setmetatable(self, nil)
	self.OutlineTween = nil
	self.FillFrameTween = nil
	self.GUI:Destroy()
end

return KeyIcon