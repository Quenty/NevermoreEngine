-- Renders a frame and its descendants in 3D space.
-- @classmod GUIRender3D

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ScreenSpace = require("ScreenSpace")

local GUIRender3D = {}
GUIRender3D.ClassName = "GUIRender3D"
GUIRender3D.__index = GUIRender3D

function GUIRender3D.new()
	local self = setmetatable({}, GUIRender3D)

	self.Depth = -10 -- studs
	self.RenderParent = workspace.CurrentCamera

	return self
end

function GUIRender3D:SetDepth(Depth)
	if Depth > 0 then
		warn("Depth > 0, will not render on screen @ " .. debug.traceback())
	end
	self.Depth = Depth
end

function GUIRender3D:GetDepth()
	return self.Depth
end

function GUIRender3D:GetFrame()
	return self.Frame
end

function GUIRender3D:WithRenderParent(RenderParent)
	self.RenderParent = RenderParent or error()

	return self
end

function GUIRender3D:SetFrame(Frame)
	self.Frame = Frame or error()

	local Part = Instance.new("Part", self.RenderParent)
	Part.Archivable = false
	Part.FormFactor = "Custom"
	Part.CanCollide = false
	Part.Anchored = true
	Part.Name = Frame.Name .. "_3DRender"
	Part.Transparency = 1
	self.Part = Part

	local SurfaceGui = Instance.new("SurfaceGui", Part)
	SurfaceGui.Adornee = Part
	SurfaceGui.Face = "Back"

	self.SurfaceGui = SurfaceGui

	local FakeFrame = Instance.new("Frame")
	FakeFrame.Parent = Frame.Parent
	FakeFrame.Name = "FakeFrame_" .. Frame.Name
	FakeFrame.BackgroundTransparency = 1;
	FakeFrame.Size = Frame.Size
	FakeFrame.Position = Frame.Position
	FakeFrame.SizeConstraint = Frame.SizeConstraint
	FakeFrame.Visible = true
	FakeFrame.Active = Frame.Active
	self.FakeFrame = FakeFrame

	Frame.Parent = self.SurfaceGui;
	Frame.Position = UDim2.new(0, 0, 0, 0)
	Frame.Size = UDim2.new(1, 0, 1, 0)
	Frame.SizeConstraint = "RelativeXY"

	self:UpdatePartSize()
end

function GUIRender3D:GetFakeFrame()
	return self.FakeFrame
end

function GUIRender3D:UpdatePartSize()
	local Size = self.FakeFrame.AbsoluteSize

	local WorldWidth = ScreenSpace.ScreenWidthToWorldWidth(Size.X, self.Depth)
	local WorldHeight = ScreenSpace.ScreenHeightToWorldHeight(Size.Y, self.Depth)

	self.Part.Size = Vector3.new(WorldWidth, WorldHeight, 0.2)
	self.SurfaceGui.CanvasSize = Size
end

function GUIRender3D:Hide()
	self.Part.Parent = nil
end

function GUIRender3D:Show()
	self.Part.Parent = self.RenderParent
end

function GUIRender3D:GetPrimaryCFrame()
	local Size = self.FakeFrame.AbsoluteSize
	local FrameCenter = self.FakeFrame.AbsolutePosition + Size/2

	local Position = ScreenSpace.ScreenToWorldByWidthDepth(FrameCenter.X, FrameCenter.Y, Size.X, self.Depth)

	return workspace.CurrentCamera.CoordinateFrame *
          CFrame.new(Position) * -- Transform by camera coordinates
          CFrame.new(0, 0, -self.Part.Size.Z/2) -- And take out the part size factor.
end

function GUIRender3D:Update(RelativeCFrame)
	RelativeCFrame = RelativeCFrame or CFrame.new()

	self:UpdatePartSize()
	self.Part.CFrame = self:GetPrimaryCFrame() * RelativeCFrame
end

function GUIRender3D:Destroy()
	self.Part:Destroy()
	self.FakeFrame:Destroy()
	self.Frame:Destroy()

	self.Part, self.FakeFrame = nil, nil
	self.Frame = nil

	setmetatable(self, nil)
end

return GUIRender3D