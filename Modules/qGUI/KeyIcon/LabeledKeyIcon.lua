local LabeledKeyIcon     = {}
LabeledKeyIcon.__index   = LabeledKeyIcon
LabeledKeyIcon.ClassName = "LabeledKeyIcon"

-- LabeledKeyIcons can be collapsed
-- @author Quenty

function LabeledKeyIcon.new(Frame, KeyIcon, TextLabel)
	-- @param Frame The parent of the KeyIcon and the TextLabel. (NOTE: Children of this should 
	--              not be rotated.) Note too that this will be resized.
	-- @param KeyIcon A key icon for the input label
	-- @param TextLabel The text label (assumedly to the right) of the KeyIcon. We assume these
	--                  both share the same parent, but it's not guaranteed. 
	local self = {}
	setmetatable(self, LabeledKeyIcon)

	self.GUI                  = Frame
	self.GUI.ClipsDescendants = true
	
	self.KeyIcon              = KeyIcon
	self.TextLabel            = TextLabel

	self:SetLabelVisible(true, 0) -- Calls AutoResize too!
	self:RescaleLabel()
	self:AutoResize(0)

	return self
end

function LabeledKeyIcon.FromKeyIcon(KeyIcon, LabelText)
	--- Creates a labeled key icon from an existing KeyIcon
	-- @param KeyIcon The KeyIcon to use. 
	-- @param [LabelText] String, the text to use for the label.

	local Frame                  = Instance.new("Frame")
	Frame.Size                   = KeyIcon.GUI.Size
	Frame.ZIndex                 = KeyIcon.GUI.ZIndex
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel        = 0
	Frame.Name                   = "LabeledKeyIconFrame"
	Frame.ClipsDescendants       = true

	local TextLabel                  = Instance.new("TextLabel", Frame)
	TextLabel.BackgroundTransparency = 1
	TextLabel.BorderSizePixel        = 0
	TextLabel.TextXAlignment         = "Left"
	TextLabel.Size                   = UDim2.new(0, 0, 1, 0)
	TextLabel.Position               = UDim2.new(0, KeyIcon.GUI.Size.X.Offset + 5, 0, 0) -- Will be recalculated anyway.
	TextLabel.TextColor3             = Color3.new(1, 1, 1)
	TextLabel.Font                   = "SourceSans"
	TextLabel.FontSize               = "Size10"
	TextLabel.Name                   = "KeyIconLabel"
	TextLabel.Text                   = LabelText:upper() or "[ label goes here ]"

	KeyIcon.GUI.Parent = Frame

	return LabeledKeyIcon.new(Frame, KeyIcon, TextLabel)
end

function LabeledKeyIcon:SetFillTransparency(PercentTransparency, AnimationTime)
	--- Sets the fill of the KeyIcon to a specific transparency. Used to indicate state. 

	self.KeyIcon:SetFillTransparency(PercentTransparency, AnimationTime)
end

function LabeledKeyIcon:SetOutlineTransparency(PercentTransparency, AnimationTime)
	--- Sets the outline of the KeyIcon to a specific transparency

	self.KeyIcon:SetOutlineTransparency(PercentTransparency, AnimationTime)
end

function LabeledKeyIcon:RescaleIcon()
	-- RESCALE WIDTH
	self.KeyIcon:RescaleWidth()

	-- REPOSITION BASED ON WIDTH.
	local Y = self.TextLabel.Position.Y
	self.TextLabel.Position = UDim2.new(0, self.KeyIcon.Width + 5, Y.Scale, Y.Offset)
end

function LabeledKeyIcon:ResizeWidth(Width, AnimationTime)
	--- Resizes the who icon. Used to show/hide the label.
	-- @param Width Number, the width of the icon (offset) to set.
	-- @param [AnimationTime] Number, The time to animate the resize [0, infinity). Defaults to 0.2
	
	-- print("ResizeWidth", self.GUI, "ResizeWidth", Width, "AnimationTime: ", AnimationTime)

	self.Width = Width

	AnimationTime = AnimationTime or 0.2

	local Y = self.GUI.Size.Y
	local NewSize = UDim2.new(0, Width, Y.Scale, Y.Offset)

	if NewSize ~= self.GUI.Size then
		if AnimationTime > 0 then
			self.GUI:TweenSize(NewSize, "Out", "Quad", AnimationTime, true)
		else
			self.GUI.Size = NewSize
		end
	end
end

function LabeledKeyIcon:AutoResize(AnimationTime)
	self:RescaleIcon()

	local Width = self.KeyIcon.Width

	-- RESIZE APPROXIMATELY.
	if self.LabelVisible then
		-- Calculate TextLabel Offset from KeyIcon:
		local Offset = (self.TextLabel.Position - self.KeyIcon.GUI.Size).X.Offset

		Width = Width + Offset + self.TextLabel.Size.X.Offset
	end

	-- print("AutoResize", self.GUI, "self.KeyIcon.Width", self.KeyIcon.Width, "Width", Width)
	-- print("> self.TextLabel.Size.X.Offset", self.TextLabel.Size.X.Offset)
	-- print("> Second offset thingy?", (self.TextLabel.Position - self.KeyIcon.GUI.Size).X.Offset)
	
	self:ResizeWidth(Width, AnimationTime)
end

function LabeledKeyIcon:SetLabelVisible(LabelVisible, AnimationTime)
	-- @param LabelVisible Bool, whether the label is visible or not.
	-- @param [AnimationTime] [0, infinity)

	if self.LabelVisible ~= LabelVisible then
		self.LabelVisible = LabelVisible
		
		self:AutoResize(AnimationTime)
	end
end

function LabeledKeyIcon:RescaleLabel()
	--- Rescales the text label to its text bounds. 
	-- @param [AnimationTime] [0, infinity)

	local Y = self.TextLabel.Size.Y
	self.TextLabel.Size = UDim2.new(0, self.TextLabel.TextBounds.X, Y.Scale, Y.Offset)
end

function LabeledKeyIcon:SetIconText(NewText, AnimationTime)
	-- @param [AnimationTime] [0, infinity)
	self.TextLabel.Text = NewText
	self:RescaleLabel()
	self:AutoResize(AnimationTime)
end

function LabeledKeyIcon:Destroy()
	setmetatable(self, nil)

	self.KeyIcon:Destroy()
	self.TextLabel:Destroy()
	self.GUI:Destroy()
end

return LabeledKeyIcon