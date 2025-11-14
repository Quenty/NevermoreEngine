--[[
	@class CameraUtils.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")

local CameraUtils = require("CameraUtils")

return function(target: Instance)
	local maid = Maid.new()

	local viewportFrame = maid:Add(Instance.new("ViewportFrame"))
	viewportFrame.BorderSizePixel = 0
	viewportFrame.BackgroundColor3 = Color3.new(0.7, 0.7, 0.7)
	viewportFrame.Size = UDim2.fromScale(1, 1)

	local camera: Camera = maid:Add(Instance.new("Camera"))
	camera.FieldOfViewMode = Enum.FieldOfViewMode.Diagonal
	camera.FieldOfView = 70
	viewportFrame.CurrentCamera = camera

	local radius = 5

	local ball: Part = maid:Add(Instance.new("Part"))
	ball.Color = Color3.new(1, 0.5, 0.5)
	ball.Size = Vector3.new(2 * radius, 2 * radius, 2 * radius)
	ball.Shape = Enum.PartType.Ball
	ball.CFrame = CFrame.new()
	ball.Anchored = true
	ball.Parent = viewportFrame

	local function update()
		local absSize = viewportFrame.AbsoluteSize
		if absSize.x > 0 and absSize.y > 0 then
			local aspectRatio = absSize.x / absSize.y
			local dist = CameraUtils.fitSphereToCamera(radius, camera.FieldOfView, aspectRatio)
			camera.CFrame = CFrame.new(0, 0, dist)
		end
	end
	maid:GiveTask(camera:GetPropertyChangedSignal("FieldOfView"):Connect(update))
	maid:GiveTask(viewportFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
	update()

	viewportFrame.Parent = target

	return function()
		maid:DoCleaning()
	end
end
