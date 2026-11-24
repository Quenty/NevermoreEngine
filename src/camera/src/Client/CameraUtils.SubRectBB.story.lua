--!nonstrict
--[[
	Frames a rotated, non-cube box in a draggable sub-rect of the viewport, from a camera angled
	down. The box's corners touch both edges of the rect on the limiting axis.

	@class CameraUtils.SubRectBB.story
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

	local box: Part = maid:Add(Instance.new("Part"))
	box.Color = Color3.new(0.5, 0.6, 1)
	box.Size = Vector3.new(8, 3, 2)
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	box.CFrame = CFrame.Angles(0, math.rad(20), 0)
	box.Anchored = true
	box.Parent = viewportFrame

	local rotation = CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(math.rad(-30), 0, 0)

	local subrectFrame = Instance.new("Frame")
	subrectFrame.BackgroundColor3 = Color3.new(0.3, 1, 0.5)
	subrectFrame.BackgroundTransparency = 0.8
	subrectFrame.BorderSizePixel = 0
	subrectFrame.Position = UDim2.fromScale(0.1, 0.1)
	subrectFrame.Size = UDim2.fromScale(0.5, 0.55)
	subrectFrame.Parent = viewportFrame

	local dragDetector = Instance.new("UIDragDetector")
	dragDetector.BoundingUI = viewportFrame
	dragDetector.Parent = subrectFrame

	local function update()
		local absSize = viewportFrame.AbsoluteSize
		if absSize.X > 0 and absSize.Y > 0 then
			local min = (subrectFrame.AbsolutePosition - viewportFrame.AbsolutePosition) / absSize
			local subrect = Rect.new(min, min + subrectFrame.AbsoluteSize / absSize)

			local offset = CameraUtils.fitBoundingBoxToCameraRectExact(
				box.CFrame,
				box.Size,
				rotation,
				camera.FieldOfView,
				absSize.X / absSize.Y,
				subrect
			)
			camera.CFrame = CFrame.new(box.Position) * rotation * CFrame.new(offset)
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
