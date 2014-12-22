local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

-- RotatingTextLabel.lua
-- @author Quenty

local RotatingTextCharacter = {}
RotatingTextCharacter.__index   = RotatingTextCharacter
RotatingTextCharacter.ClassName = "RotatingTextCharacter"

RotatingTextCharacter.PropertiesToTransfer = {
	BorderSizePixel        = 0;
	BackgroundColor3       = Color3.new();
	BackgroundTransparency = 1;
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

	--- Generate GUIs
	local ContainerFrame            = Instance.new("Frame")
	ContainerFrame.Name             = "RotatingTextCharacter"
	ContainerFrame.ClipsDescendants = true;

	-- This label is underneath the regular one.
	local RotatingLabelOne    = TextLabel:Clone()
	RotatingLabelOne.Name     = "RotatingLabelOne"
	RotatingLabelOne.Parent   = TextLabel;
	RotatingLabelOne.Position = UDim2.new(0, 0, 1, 0)
	RotatingLabelOne.Size     = UDim2.new(1, 0, 1, 0)
	RotatingLabelOne.Parent   = TextLabel
	self.RotatingLabelOne     = RotatingLabelOne

	for PropertName, NewValue in pairs(self.PropertiesToTransfer) do
		ContainerFrame[PropertName] = TextLabel[PropertName]
		TextLabel[PropertName] = NewValue
	end

	ContainerFrame.Parent = TextLabel.Parent
	TextLabel.Parent      = ContainerFrame

	--- Render...
	self:UpdateText()

	return self
end

function RotatingTextCharacter:UpdateText()
	--- Updates the text

	self.TextLabel.Text = string.char(math.floor(self.Position))
	self.RotatingLabelOne.Text = string.char(math.floor(self.Position) + 1)
end

function RotatingTextCharacter:UpdatePosition()
	local Distance = self.TargetPosition - self.Position

	if math.abs(Distance) < 0.05 then
		self.Position = self.TargetPosition
		self.Velocity = 0

		self:StopUpdate()
	else
		local Acceleration = Distance * (1/30)
		self.Velocity = self.Velocity * 0.8
		self.Velocity = self.Velocity + Acceleration

		self.Position = self.Position + self.Velocity
	end

	self.TextLabel.Position = UDim2.new(0, 0, -self.Position % 1, 0)

	self:UpdateText()
end

function RotatingTextCharacter:StopUpdate()
	self.UpdateCoroutine = nil
end

function RotatingTextCharacter:StartUpdate()
	local LocalUpdateCoroutine
	LocalUpdateCoroutine = coroutine.create(function()
		while self.UpdateCoroutine == LocalUpdateCoroutine do
			self:UpdatePosition()
			RunService.RendeStepped:wait()
		end
	end)
end

function RotatingTextCharacter:SetTargetPosition(NewTarget)
	self.TargetPosition = NewTarget

	if self.Position ~= NewTarget then
		self:StartUpdate()
	end
end



local RotatingTextLabel = {}
RotatingTextLabel.ClassName = "RotatingTextLabel"
RotatingTextLabel.__index = RotatingTextLabel

function RotatingLabelOne.new()

end