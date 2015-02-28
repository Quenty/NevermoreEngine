local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid
local qMath = LoadCustomLibrary("qMath")

-- RotatingTextLabel.lua
-- @author Quenty

local RotatingTextCharacter = {}
RotatingTextCharacter.__index   = RotatingTextCharacter
RotatingTextCharacter.ClassName = "RotatingTextCharacter"
RotatingTextCharacter.Width = 7;

RotatingTextCharacter.PropertiesToTransfer = {
	BorderSizePixel        = 0;
	BackgroundColor3       = Color3.new();
	Size                   = UDim2.new(1, 0, 1, 0);
	Position               = UDim2.new(0, 0, 0, 0);
}

function RotatingTextCharacter.new(TextLabel)
	--- Creates a rotating text label with the style and postion of the TextLabel
	-- @param TextLabel A square text label with one character in it.
	--                  Should have Archivable = true; and ClipsDescendents false

	local self = {}
	setmetatable(self, RotatingTextCharacter)

	--- Set values
	self.Position       = string.byte(TextLabel.Text)
	self.TargetPosition = self.Position
	self.Velocity       = 0
	-- self.Hiding = false
	-- self.Showing = false

	--- Generate GUIs
	local ContainerFrame            = Instance.new("Frame")
	ContainerFrame.Name             = "RotatingTextCharacter"
	ContainerFrame.ClipsDescendants = true;
	ContainerFrame.ZIndex           = TextLabel.ZIndex

	TextLabel.BackgroundTransparency      = 1
	ContainerFrame.BackgroundTransparency = 1

	-- This label is underneath the regular one.
	local TextLabelTwo    = TextLabel:Clone()
	TextLabelTwo.Name     = "TextLabelTwo"
	TextLabelTwo.Parent   = TextLabel;
	TextLabelTwo.Position = UDim2.new(0, 0, 1, 0)
	TextLabelTwo.Size     = UDim2.new(1, 0, 1, 0)
	TextLabelTwo.Parent   = TextLabel
	TextLabelTwo.ZIndex   = TextLabel.ZIndex
	self.TextLabelTwo     = TextLabelTwo

	for PropertyName, NewValue in pairs(self.PropertiesToTransfer) do
		ContainerFrame[PropertyName] = TextLabel[PropertyName]
		TextLabel[PropertyName]      = NewValue
	end

	ContainerFrame.Parent = TextLabel.Parent
	TextLabel.Parent      = ContainerFrame

	self.ContainerFrame = ContainerFrame
	self.TextLabel      = TextLabel

	--- Transparency stuff
	self.TransparencyFrameData = {}
	self.Transparency = 0
	self:AddTransparencyDataForFrame(self.TextLabel, {"TextTransparency", "TextStrokeTransparency"})
	self:AddTransparencyDataForFrame(self.TextLabelTwo, {"TextTransparency", "TextStrokeTransparency"})

	--- Render...
	self:UpdateText()
	self:Show()

	return self
end

function RotatingTextCharacter:AddTransparencyDataForFrame(Frame, Properties)
	local DataTable = {}

	for _, PropertyName in pairs(Properties) do
		DataTable[PropertyName] = Frame[PropertyName]
	end

	self.TransparencyFrameData[Frame] = DataTable
end

function RotatingTextCharacter:SetTransparencyOfFrame(Frame, NewTransparency)
	for PropertyName, DefaultValue in pairs(self.TransparencyFrameData[Frame] or error("[RotatingTextCharacter][SetTransparencyOfFrame] - No frame data for frame '" .. Frame:GetFullName())) do
		Frame[PropertyName] = qMath.MapNumber(NewTransparency, 0, 1, DefaultValue, 1)
	end
end

function RotatingTextCharacter:UpdateWidth()
	self.ContainerFrame.Size = UDim2.new(0, self.Width, self.ContainerFrame.Size.Y.Scale, self.ContainerFrame.Size.Y.Offset)
end

function RotatingTextCharacter:GetCharacterFromPosition(Position)
	Position = math.floor(Position)

	--[[if self.Hiding == Position then
		return ""
	elseif self.Showing == Position then
		return ""
	end--]]

	if Position == 47 then
		return " "
	end

	return string.char(Position)
end

function RotatingTextCharacter:UpdateText()
	--- Updates the text
	self.TextLabel.Text = self:GetCharacterFromPosition(self.Position)
	self.TextLabelTwo.Text = self:GetCharacterFromPosition(self.Position + 1)
end



function RotatingTextCharacter:UpdatePhysics()
	local Distance = self.TargetPosition - self.Position

	if math.abs(self.Velocity) < 0.05 and math.abs(Distance) < 0.05 then
		self.Position = self.TargetPosition

		self.Velocity = 0

		self:StopUpdate()
	else
		local Acceleration = Distance * (1/30)
		self.Velocity = self.Velocity * 0.7
		self.Velocity = self.Velocity + Acceleration

		self.Position = self.Position + self.Velocity
	end
end

function RotatingTextCharacter:Show()

	-- We set the second one to be "" because we're moving downwards and that should start out with "" (no text)
	-- self.TextLabel.Text = string.char(math.floor(self.TargetPosition))
	-- self.TextLabelTwo.Text = ""

	-- if not self.Showing then
	-- 	self.Showing = true
	-- 	self.Hiding = false

	self.Position = 47 -- so we aniamte in nicely....
	self:StartUpdate()

	-- 	local LocalUpdateCoroutine
	-- 	LocalUpdateCoroutine = coroutine.create(function()
	-- 		while self.UpdateCoroutine == LocalUpdateCoroutine do
	-- 			self:UpdatePhysics()
	-- 			self:UpdateTransparency()
	-- 			self:UpdatePosition()
	-- 			self:UpdateText()

	-- 			RunService.RenderStepped:wait()

	-- 			--[[if self.UpdateCoroutine ~= LocalUpdateCoroutine then
	-- 				self:UpdateText()
	-- 			else
	-- 				RunService.RenderStepped:wait()
	-- 			end--]]
	-- 		end
	-- 	end)

	-- 	self.UpdateCoroutine = LocalUpdateCoroutine
	-- 	assert(coroutine.resume(LocalUpdateCoroutine))
	-- end
end

function RotatingTextCharacter:UpdateTransparency()
	local TransparencyOne = self.Position % 1
	local TransparencyTwo = 1 - TransparencyOne

	local TransparencyModifier = 1 - self.Transparency

	self:SetTransparencyOfFrame(self.TextLabel, TransparencyOne * TransparencyModifier)
	self:SetTransparencyOfFrame(self.TextLabelTwo, TransparencyTwo * TransparencyModifier)

	-- self.TextLabel.TextTransparency = TransparencyOne
	-- self.TextLabelTwo.TextTransparency = TransparencyTwo
end

function RotatingTextCharacter:SetTransparency(NewTransparency)
	self.Transparency = NewTransparency
	self:UpdateTransparency()
end

function RotatingTextCharacter:UpdatePosition()
	self.TextLabel.Position = UDim2.new(0, 0, -(self.Position % 1), 0)
end

function RotatingTextCharacter:StopUpdate()
	self.UpdateCoroutine = nil
end

function RotatingTextCharacter:StartUpdate()
	local LocalUpdateCoroutine
	LocalUpdateCoroutine = coroutine.create(function()
		while self.UpdateCoroutine == LocalUpdateCoroutine do
			self:UpdatePhysics()
			self:UpdateTransparency()
			self:UpdatePosition()
			self:UpdateText()

			RunService.RenderStepped:wait()
		end
	end)

	self.UpdateCoroutine = LocalUpdateCoroutine
	assert(coroutine.resume(LocalUpdateCoroutine))
end

function RotatingTextCharacter:SetTargetPosition(NewTarget)
	self.TargetPosition = NewTarget

	if self.Position ~= NewTarget then
		self:StartUpdate()
	end
end

function RotatingTextCharacter:SetCharacter(Character)
	self:SetTargetPosition(string.byte(Character))
end

function RotatingTextCharacter:Hide()
	self:SetTargetPosition(47)

	--[==[if not self.Hiding then
		self.Hiding = true
		self.Showing = false
	
		self.TargetPosition = 47

		local LocalUpdateCoroutine
		LocalUpdateCoroutine = coroutine.create(function()
			--- Hiding animation...


			--- Hide in a smart direction....
			--[[if self.Velocity > 0 then
				self.TargetPosition = self.TargetPosition + 1
			elseif self.Velocity < 0 then
				self.TargetPosition = self.TargetPosition - 1
			else --- Randomize direction of flow for hiding.
				if math.random() < 0.5 then
					self.TargetPosition = self.TargetPosition + 1
				else
					self.TargetPosition = self.TargetPosition - 1
				end
			end

			if self.TargetPosition > self.Position then
				--- We're fading upwards. 
				self.TextLabelTwo.Text = ""
			else
				--- We're fading downwards...
				self.TextLabelTwo.Text = self.TextLabel.Text
				self.TextLabel.Text = ""
			end--]]

			--- Begin the update loop.
			while self.UpdateCoroutine == LocalUpdateCoroutine do
				--[[self:UpdatePhysics()
				self:UpdateTransparency()
				self:UpdatePosition()

				--- If we GCed then..
				if self.UpdateCoroutine ~= LocalUpdateCoroutine then
					self.TextLabel.Text = "" -- So we don't "flash" the text again.
				else
					RunService.RenderStepped:wait()
				end--]]
				self:UpdatePhysics()
				self:UpdateTransparency()
				self:UpdatePosition()
				self:UpdateText()

				RunService.RenderStepped:wait()
			end

			--- Detect whether we were intercepted at all...
			if self.Hiding then
				print("Should destroy here")
			end
		end)

		self.UpdateCoroutine = LocalUpdateCoroutine
		assert(coroutine.resume(LocalUpdateCoroutine))
	end--]==]
end

function RotatingTextCharacter:Destroy()
	self.ContainerFrame:Destroy()
	self.ContainerFrame = nil
	self.ContainerFrame = nil
	self.TextLabel      = nil
	
	self.UpdateCoroutine = nil

	setmetatable(self, nil)

end

function RotatingTextCharacter:SetPosition(NewPosition)
	self.ContainerFrame.Position = NewPosition
end




local RotatingTextLabel = {}
RotatingTextLabel.ClassName = "RotatingTextLabel"
RotatingTextLabel.__index = RotatingTextLabel

function RotatingTextLabel.new(TextLabel)
	--- Will replace your GUI with a new frame.

	local self = {}
	setmetatable(self, RotatingTextLabel)

	--- Set variables
	self.Text = TextLabel.Text
	self.TextLabel = TextLabel
	self:SetupGUI()

	--- Setup rendering
	self.RotatingTextCharacters = {}
	self:UpdateTextBoxes()

	return self
end

function RotatingTextLabel:AddRotatingTextCharacter(Index, Character)
	local Gui = self:GetRotatingTextCharacterGui(Index, Character)
	local NewLabel = RotatingTextCharacter.new(Gui)
	NewLabel:UpdateWidth()

	self.RotatingTextCharacters[Index] = NewLabel
	return NewLabel
end

--[[
function RotatingTextLabel:GetXOffsetForIndex(Index, TextXAlignment, TotalWidth)

	if TextXAlignment == "Left" then
		local XOffset = 0

		for CharacterIndex = 1, Index-1 do
			XOffset = XOffset + self.RotatingTextCharacters[CharacterIndex].Width
		end

		return XOffset
	elseif TextXAlignment == "Right" then
		local XOffset = 0

		for CharacterIndex = Index, #self.RotatingTextCharacters do
			XOffset = XOffset - self.RotatingTextCharacters[CharacterIndex].Width
		end

		return XOffset	
	else -- Center
		local XOffset = math.floor((self.Gui.AbsoluteSize.X - TotalWidth)/2)

		for CharacterIndex = 1, Index-1 do
			XOffset = XOffset + self.RotatingTextCharacters[CharacterIndex].Width
		end

		return XOffset
	end
end--]]

function RotatingTextLabel:GetRotatingTextCharacterGui(Index, Character)
	local NewLabel    = self.TextLabel:Clone()
	NewLabel.Text     = Character
	NewLabel.Size     = UDim2.new(0, 0, 1, 0)
	NewLabel.TextXAlignment = "Center"
	NewLabel.Parent   = self.Gui
	NewLabel.Name     = "RotatingLabel_AtIndex" .. Index

	return NewLabel
end

function RotatingTextLabel:SetText(NewText)
	self.Text = tostring(NewText)
	self:UpdateTextBoxes()
end

function RotatingTextLabel:UpdateRotationgTextCharacterForIndex(Index, Character)
	local RotatingTextCharacter = self.RotatingTextCharacters[Index]

	if not (RotatingTextCharacter and RotatingTextCharacter.Destroy) then
		RotatingTextCharacter = self:AddRotatingTextCharacter(Index, Character)
	else
		RotatingTextCharacter:SetCharacter(Character)
	end

	return RotatingTextCharacter
end


function RotatingTextLabel:UpdateTextBoxes()
	--- Assume right aligned for now

	local Text = self.Text
	local TotalWidth = 0


	-- The first character is on the right...
	local Index = 1

	if self.TextLabel.TextXAlignment.Name == "Right" then
		for TextIndex = #Text, 1, -1 do
			local Character = self.Text:sub(TextIndex, TextIndex)
			local RotatingTextCharacter = self:UpdateRotationgTextCharacterForIndex(Index, Character)

			TotalWidth = TotalWidth + RotatingTextCharacter.Width

			--print("RotatingTextCharacter", RotatingTextCharacter, "Index", Index, "Character", Character, "TotalWidth", TotalWidth)
			RotatingTextCharacter:SetPosition(UDim2.new(1, -TotalWidth, 0, 0))

			Index = Index + 1
		end
	elseif self.TextLabel.TextXAlignment.Name == "Left" then
		for Index = 1, #Text do
			local Character = self.Text:sub(Index, Index)
			local RotatingTextCharacter = self:UpdateRotationgTextCharacterForIndex(Index, Character)

			TotalWidth = TotalWidth + RotatingTextCharacter.Width
			RotatingTextCharacter:SetPosition(UDim2.new(0, TotalWidth, 0, 0))
		end
	end


	--[[elseif self.TextLabel.TextXAlignment.Name == "Left" then
		for Index = 1, #Text do
			local Character = Text:sub(Index, Index)
			local RotatingTextCharacter = self:UpdateRotationgTextCharacterForIndex(Index, Character)

			RotatingTextCharacter:SetPosition(UDim2.new(0, TotalWidth, 0, 0))
			TotalWidth = TotalWidth + RotatingTextCharacter.Width
		end
	else
		error("Center not supported yet")
	end--]]


	--- Clean up excess labels
	local ReachedIndex = #Text+1
	while ReachedIndex <= #self.RotatingTextCharacters do
		local Label = self.RotatingTextCharacters[ReachedIndex]
		if Label.Destroy then
			Label:Hide()
		else
			--- GC it somehow... :/
		end
		ReachedIndex = ReachedIndex + 1
	end


	--[[
	--- We need to add new text labels here...
	for Index = 1, #Text do
		local Character = Text:sub(Index, Index)
		local RotatingTextCharacter =self.RotatingTextCharacters[Index]

		if not RotatingTextCharacter then
			RotatingTextCharacter = self:AddRotatingTextCharacter(Index, Character)
		else
			RotatingTextCharacter:SetCharacter(Character)
		end

		TotalWidth = TotalWidth + RotatingTextCharacter.Width
		ReachedIndex = Index
	end

	--- Now clean up old labels
	while ReachedIndex < #self.RotatingTextCharacters do
		self.RotatingTextCharacters[ReachedIndex]:Destroy()
		table.remove(self.RotatingTextCharacters, ReachedIndex)
	end

	--- And reposition current ones.
	for Index, RotatingTextLabel in pairs(self.RotatingTextCharacters) do
		local NewPosition

		if self.TextLabel.TextXAlignment.Name == "Left" then
			NewPosition = UDim2.new(0, self:GetXOffsetForIndex(Index, "Left"), 0, 0)
		elseif self.TextLabel.TextXAlignment.Name == "Right" then
			NewPosition = UDim2.new(1, self:GetXOffsetForIndex(Index, "Right"), 0, 0)
		else -- Center
			NewPosition = UDim2.new(0, self:GetXOffsetForIndex(Index, "Center", TotalWidth), 0, 0)
		end

		RotatingTextLabel:SetPosition(NewPosition)
	end--]]
end

function RotatingTextLabel:SetupGUI()
	local TextLabel = self.TextLabel

	local Container = Instance.new("Frame", TextLabel.Parent)
	Container.Name                   = TextLabel.Name .. "_RotatingTextLabelContainer"
	Container.Archivable             = false
	Container.Size                   = TextLabel.Size
	Container.Position               = TextLabel.Position
	Container.BackgroundTransparency = 1
	Container.ZIndex                 = TextLabel.ZIndex

	self.Gui = Container

	--- We don't want to render the TextLabel, but we do want to read from it.
	self.TextLabel.Parent = nil
end

function RotatingTextLabel:SetTransparency(NewTransparency)
	for _, Label in pairs(self.RotatingTextCharacters) do
		Label:SetTransparency(NewTransparency)
	end
end

function RotatingTextLabel:Destroy()
	for _, Label in pairs(self.RotatingTextCharacters) do
		Label:Destroy()
	end
	self.RotatingTextCharacters = nil

	setmetatable(self, nil)
end

return RotatingTextLabel