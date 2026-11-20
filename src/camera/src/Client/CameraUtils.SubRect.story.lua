--!nonstrict
--[[
	Frames a sphere in a draggable sub-rect of the viewport. The sphere stays centered in
	the outlined rect and touches its limiting edge.

	@class CameraUtils.SubRect.story
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Maid = require("Maid")

local CameraUtils = require("CameraUtils")

return function(target: Instance)
	local maid = Maid.new()

	local viewportFrame = maid:Add(Instance.new("ViewportFrame"))
	viewportFrame.BorderSizePixel = 0
	viewportFrame.BackgroundColor3 = Color3.new(0.7, 0.7, 0.7)
	viewportFrame.Size = UDim2.fromScale(1, 1)

	local camera: Camera = maid:Add(Instance.new("Camera"))
	camera.FieldOfView = 70
	viewportFrame.CurrentCamera = camera

	local radius = 3

	local ball: Part = maid:Add(Instance.new("Part"))
	ball.Color = Color3.new(1, 0.5, 0.5)
	ball.Size = Vector3.new(2 * radius, 2 * radius, 2 * radius)
	ball.Shape = Enum.PartType.Ball
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.CFrame = CFrame.new()
	ball.Anchored = true
	ball.Parent = viewportFrame

	local subrectFrame = Instance.new("Frame")
	subrectFrame.BackgroundColor3 = Color3.new(0.3, 1, 0.5)
	subrectFrame.BackgroundTransparency = 0.8
	subrectFrame.BorderSizePixel = 0
	subrectFrame.Position = UDim2.fromScale(0.1, 0.1)
	subrectFrame.Size = UDim2.fromScale(0.5, 0.55)
	subrectFrame.Parent = viewportFrame

	local uiAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	uiAspectRatioConstraint.AspectRatio = 1
	uiAspectRatioConstraint.Parent = subrectFrame

	local dragDetector = Instance.new("UIDragDetector")
	dragDetector.BoundingUI = viewportFrame
	dragDetector.Parent = subrectFrame

	local function update()
		local absSize = viewportFrame.AbsoluteSize
		if absSize.X > 0 and absSize.Y > 0 then
			local min = (subrectFrame.AbsolutePosition - viewportFrame.AbsolutePosition) / absSize
			local subrect = Rect.new(min, min + subrectFrame.AbsoluteSize / absSize)

			local offset = CameraUtils.fitSphereToCameraRect(radius, camera.FieldOfView, absSize.X / absSize.Y, subrect)
			camera.CFrame = CFrame.new(offset)
		end
	end
	maid:GiveTask(camera:GetPropertyChangedSignal("FieldOfView"):Connect(update))
	maid:GiveTask(viewportFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
	maid:GiveTask(subrectFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
	maid:GiveTask(subrectFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
	update()

	viewportFrame.Parent = target

	return function()
		maid:DoCleaning()
	end
end
