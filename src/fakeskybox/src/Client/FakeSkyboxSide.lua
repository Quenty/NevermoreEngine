--[=[
	@class FakeSkyboxSide
]=]

local FakeSkyboxSide = {}
FakeSkyboxSide.__index = FakeSkyboxSide
FakeSkyboxSide.ClassName = "FakeSkyboxSide"
FakeSkyboxSide.CanvasSize = 1024
FakeSkyboxSide.PartWidth = 1

function FakeSkyboxSide.new(PartSize, Normal, Parent)
	local self = setmetatable({}, FakeSkyboxSide)

	self.PartSize = PartSize or error("No PartSize")
	self.Transparency = 1
	self.Normal = Normal or error("No Normal")

	self.Part = Instance.new("Part")
	self.Part.Name = "SkyboxSide" .. self.Normal.Name
	self.Part.Anchored = true
	self.Part.Transparency = 1
	self.Part.CanCollide = false

	self.SurfaceGui = Instance.new("SurfaceGui")
	self.SurfaceGui.Adornee = self.Part
	self.SurfaceGui.CanvasSize = Vector2.new(self.CanvasSize, self.CanvasSize)
	self.SurfaceGui.LightInfluence = 0
	self.SurfaceGui.Face = Enum.NormalId.Front
	self.SurfaceGui.Parent = self.Part

	local ImageLabel = Instance.new("ImageLabel")
	ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	ImageLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	ImageLabel.Size = UDim2.new(1, 0, 1, 0)
	ImageLabel.ImageTransparency = self.Transparency
	ImageLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	ImageLabel.BackgroundTransparency = 1
	ImageLabel.BorderSizePixel = 0

	ImageLabel.Parent = self.SurfaceGui
	self.ImageLabel = ImageLabel

	self:UpdateSizing()

	self.Part.Parent = Parent

	return self
end

function FakeSkyboxSide:SetPartSize(PartSize)
	self.PartSize = PartSize or error("No PartSize")
	self:UpdateSizing()

	return self
end

function FakeSkyboxSide:UpdateSizing()
	self.Part.Size = Vector3.new(self.PartSize, self.PartSize, self.PartWidth)

	local Direction = Vector3.FromNormalId(self.Normal)
	local Offset = Direction * self.PartWidth/2

	self.Relative = CFrame.new(Direction*(self.PartSize/2) + Offset)
		* CFrame.new(Vector3.zero, -Direction)

	if self.Normal == Enum.NormalId.Bottom then
		-- Hack
		self.Relative = self.Relative * CFrame.Angles(0, 0, math.pi)
	end
end

function FakeSkyboxSide:SetImage(Image)
	self.ImageLabel.Image = Image

	return self
end

function FakeSkyboxSide:SetTransparency(Transparency)
	self.Transparency = Transparency or error("No Transparency")
	self.ImageLabel.ImageTransparency = Transparency

	return self
end

function FakeSkyboxSide:UpdateRender(RelativeCFrame)
	self.Part.CFrame = RelativeCFrame * self.Relative
end

return FakeSkyboxSide