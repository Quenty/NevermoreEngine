-- Renders a frame and its descendants in 3D space.
-- @classmod WorldGuiRender

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Workspace = game:GetService("Workspace")

local ScreenSpace = require("ScreenSpace")

local WorldGuiRender = {}
WorldGuiRender.ClassName = "WorldGuiRender"
WorldGuiRender.__index = WorldGuiRender

function WorldGuiRender.new()
	local self = setmetatable({}, WorldGuiRender)

	self._depth = -10 -- studs
	self._renderParent = Workspace.CurrentCamera

	return self
end

function WorldGuiRender:SetDepth(depth)
	if depth > 0 then
		warn("[WorldGuiRender] - depth > 0, will not render on screen @ " .. debug.traceback())
	end
	self._depth = depth
end

function WorldGuiRender:GetDepth()
	return self._depth
end

function WorldGuiRender:GetFrame()
	return self._frame
end

function WorldGuiRender:SetFrame(frame)
	self._frame = frame or error()

	self._part = Instance.new("Part")
	self._part.Archivable = false
	self._part.CanCollide = false
	self._part.Anchored = true
	self._part.Name = self._frame.Name .. "_3DRender"
	self._part.Transparency = 1

	self._surfaceGui = Instance.new("SurfaceGui")
	self._surfaceGui.Adornee = self._part
	self._surfaceGui.Face = Enum.Face.Back
	self._surfaceGui.Parent = self._part

	self._fakeFrame = Instance.new("Frame")
	self._fakeFrame.Name = "FakeFrame" .. self._frame.Name
	self._fakeFrame.BackgroundTransparency = 1
	self._fakeFrame.Size = self._frame.Size
	self._fakeFrame.Position = self._frame.Position
	self._fakeFrame.SizeConstraint = self._frame.SizeConstraint
	self._fakeFrame.Visible = true
	self._fakeFrame.Active = self._frame.Active
	self._fakeFrame.Parent = self._frame.Parent

	self._frame.Parent = self._surfaceGui
	self._frame.Position = UDim2.new(0, 0, 0, 0)
	self._frame.Size = UDim2.new(1, 0, 1, 0)
	self._frame.SizeConstraint = "RelativeXY"

	self._part.Parent = self._renderParent

	self:_updatePartSize()
end

function WorldGuiRender:GetFakeFrame()
	return self._fakeFrame
end

function WorldGuiRender:_updatePartSize()
	local size = self._fakeFrame.AbsoluteSize

	local worldWidth = ScreenSpace.ScreenWidthToWorldWidth(size.X, self._depth)
	local worldHeight = ScreenSpace.ScreenHeightToWorldHeight(size.Y, self._depth)

	self._part.Size = Vector3.new(worldWidth, worldHeight, 0.2)
	self._surfaceGui.CanvasSize = size
end

function WorldGuiRender:Hide()
	self._part.Parent = nil
end

function WorldGuiRender:Show()
	self._part.Parent = self._renderParent
end

function WorldGuiRender:GetPrimaryCFrame()
	local size = self._fakeFrame.AbsoluteSize
	local frameCenter = self._fakeFrame.AbsolutePosition + size/2
	local position = ScreenSpace.ScreenToWorldByWidthDepth(frameCenter.X, frameCenter.Y, size.X, self._depth)

	return Workspace.CurrentCamera.CFrame *
          CFrame.new(position) * -- Transform by camera coordinates
          CFrame.new(0, 0, -self._part.Size.Z/2) -- And take out the part size factor.
end

function WorldGuiRender:Update(relativeCFrame)
	relativeCFrame = relativeCFrame or CFrame.new()

	self:_updatePartSize()
	self._part.CFrame = self:GetPrimaryCFrame() * relativeCFrame
end

function WorldGuiRender:Destroy()
	self._part:Destroy()
	self._fakeFrame:Destroy()
	self._frame:Destroy()

	self._part, self._fakeFrame = nil, nil
	self._frame = nil

	setmetatable(self, nil)
end

return WorldGuiRender