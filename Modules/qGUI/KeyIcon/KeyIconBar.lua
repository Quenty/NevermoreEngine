local KeyIconBar = {}
KeyIconBar.ClassName = "KeyIconBar"
KeyIconBar.__index = KeyIconBar

-- @author Quenty

function KeyIconBar.new(Frame)
	--- Creates a GUI "bar" that holds a stack of KeyIcons, useful for listing controls that
	--  are available. These icons can be KeyIcons or LabeledKeyIcons.
	-- @param Frame the ROBLOX GUI frame to parent the icons to.

	local self = {}
	setmetatable(self, KeyIconBar)

	self.GUI = Frame
	self.KeyIcons = {}

	return self
end

function KeyIconBar:HasIcon(Icon)
	-- @return Boolean, true if the icon exists in the bar, false otherwise.

	return self:GetIconIndex(Icon) ~= nil
end

function KeyIconBar:GetIconIndex(Icon)
	-- Retrieves the internal index of the icon in the bar. 
	-- @param Icon The icon (KeyIcon or LabeledKeyIcon) to identify the index of 
	--             in the bar. 
	-- @return Number the icons index if it exists in the bar. Otherwise, it
	--         nil. 

	for Index, KeyIcon in pairs(self.KeyIcons) do
		if KeyIcon == Icon then
			return Index
		end
	end

	return nil
end

function KeyIconBar:GetHeight()
	-- @return The icon bar's offset height. This is used by the KeyIconProvider to determine
	--         the height of the icons it creates.

	return self.GUI.Size.Y.Offset
end

function KeyIconBar:AddIcon(NewIcon, AnimationTime)
	--- Adds a new icon to the bar. 
	-- @param NewIcon A KeyIcon or LabeledKeyIcon to add to the bar. Should not already be in the bar.
	-- @param [AnimationTime] Number [0, infinity), time to animate

	assert(NewIcon, "Must send new icon")
	assert(not self:HasIcon(NewIcon), "Icon is already in the KeyIconBar")

	NewIcon.GUI.Parent  = self.GUI
	NewIcon.GUI.Visible = true
	NewIcon:ResizeWidth(0, 0)
	
	local CurrentWidth = 0
	for _, Item in pairs(self.KeyIcons) do
		CurrentWidth = CurrentWidth + Item.Width
	end
	NewIcon.Position = UDim2.new(0, CurrentWidth, 0, 0)

	self.KeyIcons[#self.KeyIcons+1] = NewIcon
	self:UpdatePositions(AnimationTime)
end

function KeyIconBar:RemoveIcon(Icon)
	--- Removes the icon from the bar. Sets visibility to false.
	-- @param Icon A KeyIcon or LabeledKeyIcon to be removed that already exists

	local Index      = self:GetIconIndex(Icon) or error("Icon does not exist in the bar")
	Icon.GUI.Visible = false

	table.remove(self.KeyIcons, Index)
	self:UpdatePositions()
end

function KeyIconBar:UpdatePositions(AnimationTime)
	--- Updates all the positions of the icons in the bar.
	-- @param [AnimationTime] Number [0, infinity), how much time it takes for the icons to 
	--                        animate to/from thier current position

	AnimationTime = AnimationTime or 0.2
	local OffsetX = 0

	for _, KeyIcon in pairs(self.KeyIcons) do
		KeyIcon:AutoResize(AnimationTime)

		local NewPosition = UDim2.new(0, OffsetX, 0, 0)
		
		OffsetX = OffsetX + (KeyIcon.Width or error("Element has no width"))

		if KeyIcon.GUI.Position ~= NewPosition then
			if AnimationTime > 0 then
				KeyIcon.GUI:TweenPosition(NewPosition, "Out", "Quad", AnimationTime, true)
			else
				KeyIcon.GUI.Position = NewPosition
			end
		end
	end
end

return KeyIconBar



