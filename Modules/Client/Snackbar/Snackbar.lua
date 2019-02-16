--- Snackbars provide lightweight feedback on an operation
-- at the base of the screen. They automatically disappear
-- after a timeout or user interaction. There can only be
-- one on the screen at a time.
-- @classmod Snackbar

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local qGUI = require("qGUI")
local Maid = require("Maid")
local Math = require("Math")

-- Base clase, not functional
local Snackbar = {}
Snackbar.ClassName = "Snackbar"
Snackbar.__index = Snackbar
Snackbar.Height = 48
Snackbar.MinimumWidth = 288 -- Taken from google material design
Snackbar.MaximumWidth = 700
Snackbar.TextWidthOffset = 24
Snackbar.Position = UDim2.new(1, -10, 1, -10 - Snackbar.Height)
Snackbar.FadeTime = 0.16
Snackbar.CornerRadius = 2--24

local DEFAULT_TEXT_COLOR = Color3.fromRGB(78, 205, 196)

function Snackbar.new(Parent, Text, options)
	local self = setmetatable({}, Snackbar)

	local Gui = Instance.new("ImageButton")
	Gui.ZIndex = 7
	Gui.Name = "Snackbar"
	Gui.Size = UDim2.new(0, 100, 0, self.Height)
	Gui.BorderSizePixel = 0
	Gui.BackgroundColor3 = Color3.new(0.196, 0.196, 0.196) -- Google design specifications
	Gui.Archivable = false
	Gui.ClipsDescendants = false
	Gui.Position = self.Position
	Gui.AutoButtonColor = false
	Gui.BackgroundTransparency = 1
	self.Gui = Gui

	self.BackgroundImages = {qGUI.BackWithRoundedRectangle(Gui, self.CornerRadius, Gui.BackgroundColor3)}

	local ShadowRadius = 1
	local ShadowContainer = Instance.new("Frame")
	ShadowContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	ShadowContainer.Parent = Gui
	ShadowContainer.Name = "ShadowContainer"
	ShadowContainer.BackgroundTransparency = 1
	ShadowContainer.Size = UDim2.new(1, ShadowRadius*2, 1, ShadowRadius*2)
	ShadowContainer.Archivable = false
	ShadowContainer.Position = UDim2.new(0.5, 0, 0.5, 0)

	--- Image is blurred at
	self.ShadowImages = {
		qGUI.AddNinePatch(ShadowContainer, "rbxassetid://191838004",
			Vector2.new(150, 150),
			self.CornerRadius + ShadowRadius,
			"ImageLabel"
		)
	}

	for _, item in pairs(self.ShadowImages) do
		item.ImageTransparency = 0.74
		item.ZIndex = Gui.ZIndex - 2
	end

	for _, item in pairs(self.BackgroundImages) do
		item.ZIndex = Gui.ZIndex - 1
	end

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Size = UDim2.new(1, -self.TextWidthOffset*2, 0, 16)
	TextLabel.Position = UDim2.new(0, self.TextWidthOffset, 0, 16)
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	TextLabel.TextYAlignment = Enum.TextYAlignment.Center
	TextLabel.Name = "SnackbarLabel"
	TextLabel.TextTransparency = 0.87
	TextLabel.TextColor3 = Color3.new(1, 1, 1)
	TextLabel.BackgroundTransparency = 1
	TextLabel.BorderSizePixel = 0
	TextLabel.Font = Enum.Font.SourceSans
	TextLabel.Text = Text
	TextLabel.FontSize = Enum.FontSize.Size18
	TextLabel.ZIndex = Gui.ZIndex-1
	TextLabel.Parent = Gui
	self._textLabel = TextLabel

	self._whileActiveMaid = Maid.new()
	self.Gui.Parent = Parent

	local callToActionText
	if options and options.CallToAction then
		if type(options.CallToAction) == "string" then
			callToActionText = options.CallToAction
		else
			callToActionText = tostring(options.CallToAction.Text)
		end
		callToActionText = callToActionText:upper()

		local button = Instance.new("TextButton")
		button.Name = "CallToActionButton"
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.BackgroundTransparency = 1
		button.Position = UDim2.new(1, -self.TextWidthOffset, 0.5, 0)
		button.Size = UDim2.new(0.5, 0, 0.8, 0)
		button.Text = callToActionText
		button.Font = Enum.Font.SourceSans
		button.FontSize = TextLabel.FontSize
		button.TextXAlignment = Enum.TextXAlignment.Right
		button.TextColor3 = DEFAULT_TEXT_COLOR
		button.ZIndex = Gui.ZIndex
		button.Parent = Gui

		-- Resize
		button.Size = UDim2.new(UDim.new(0, button.TextBounds.X), button.Size.Y)

		self._whileActiveMaid:GiveTask(button.MouseButton1Click:Connect(function()
			if options.CallToAction.OnClick then
				self:Dismiss()
				options.CallToAction.OnClick()
			end
		end))

		self._whileActiveMaid:GiveTask(button.MouseEnter:Connect(function()
			button.TextColor3 = DEFAULT_TEXT_COLOR:lerp(Color3.new(0, 0, 0), 0.2)
		end))

		self._whileActiveMaid:GiveTask(button.MouseLeave:Connect(function()
			button.TextColor3 = DEFAULT_TEXT_COLOR
		end))

		self._callToActionButton = button
	end


	local width = self._textLabel.TextBounds.X + self.TextWidthOffset*2
	if self._callToActionButton then
		width = width + self._callToActionButton.Size.X.Offset + self.TextWidthOffset*2
	end

	if width < self.MinimumWidth then
		width = self.MinimumWidth
	elseif width > self.MaximumWidth then
		width = self.MaximumWidth
	end

	if callToActionText then
		self._textLabel.Text = Text
	end

	self.Gui.Size = UDim2.new(0, width, 0, self.Height)

	self.Position = self.Position + UDim2.new(0, -width, 0, 0)
	self.Gui.Position = self.Position
	self.AbsolutePosition = self.Gui.AbsolutePosition

	return self
end

function Snackbar:Dismiss()
	error("Not implemented")
end

function Snackbar:SetBackgroundTransparency(Transparency)
	for _, item in pairs(self.BackgroundImages) do
		item.ImageTransparency = Transparency
	end
	for _, item in pairs(self.ShadowImages) do
		item.ImageTransparency = Math.map(Transparency, 0, 1, 0.74, 1)
	end
end

function Snackbar:FadeOutTransparency(PercentFaded)
	if PercentFaded then
		self:SetBackgroundTransparency(Math.map(PercentFaded, 0, 1, 0, 1))
		self._textLabel.TextTransparency = Math.map(PercentFaded, 0, 1, 0.13, 1)

		if self._callToActionButton then
			self._callToActionButton.TextTransparency = PercentFaded
		end
	else
		local newProperties = {
			ImageTransparency = 1;
		}

		for _, item in pairs(self.BackgroundImages) do
			qGUI.TweenTransparency(item, newProperties, self.FadeTime, true)
		end
		for _, item in pairs(self.ShadowImages) do
			qGUI.TweenTransparency(item, newProperties, self.FadeTime, true)
		end

		qGUI.TweenTransparency(self._textLabel, {
			TextTransparency = 1;
		}, self.FadeTime, true)

		if self._callToActionButton then
			qGUI.TweenTransparency(self._callToActionButton, {
				TextTransparency = 1;
			}, self.FadeTime, true)
		end
	end
end

--- Will animate unless given PercentFaded
function Snackbar:FadeInTransparency(PercentFaded)
	if PercentFaded then
		-- self.Gui.BackgroundTransparency = Math.map(PercentFaded, 0, 1, 1, 0)
		self:SetBackgroundTransparency(Math.map(PercentFaded, 0, 1, 1, 0))
		self._textLabel.TextTransparency = Math.map(PercentFaded, 0, 1, 1, 0.13)

		if self._callToActionButton then
			self._callToActionButton.TextTransparency = PercentFaded
		end
	else
		-- Should be an ease-in-out transparency fade.
		do
			local newProperties = {
				ImageTransparency = 0;
			}
			for _, item in pairs(self.BackgroundImages) do
				qGUI.TweenTransparency(item, newProperties, self.FadeTime, true)
			end
		end

		do
			local newProperties = {
				ImageTransparency = 0.74;
			}
			for _, item in pairs(self.ShadowImages) do
				qGUI.TweenTransparency(item, newProperties, self.FadeTime, true)
			end
		end

		qGUI.TweenTransparency(self._textLabel, {
			TextTransparency = 0.13;
		}, self.FadeTime, true)

		if self._callToActionButton then
			qGUI.TweenTransparency(self._callToActionButton, {
				TextTransparency = 0;
			}, self.FadeTime, true)
		end
	end
end

-- Utility function
function Snackbar:FadeHandler(NewPosition, DoNotAnimate, IsFadingOut)
	assert(NewPosition, "[Snackbar] - Internal function should not have been called. Missing NewPosition")

	if IsFadingOut then
		self:FadeOutTransparency(DoNotAnimate and 1 or nil)
	else
		self:FadeInTransparency(DoNotAnimate and 1 or nil)
	end

	if DoNotAnimate then
		self.Gui.Position = NewPosition
	else
		self.Gui:TweenPosition(NewPosition, "InOut", "Quad", self.FadeTime, true)
	end
end

function Snackbar:FadeOutUp(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, 0, 0, -self.Gui.AbsoluteSize.Y)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeOutDown(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, 0, 0, self.Gui.AbsoluteSize.Y)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeOutRight(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, self.Gui.AbsoluteSize.X, 0, 0)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeOutLeft(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, -self.Gui.AbsoluteSize.X, 0, 0)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeIn(DoNotAnimate)
	self:FadeHandler(self.Position, DoNotAnimate, false)
end

return Snackbar