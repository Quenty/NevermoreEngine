--[[
	@class CameraFrame.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local CameraFrame = require("CameraFrame")
local CameraStoryUtils = require("CameraStoryUtils")
local CubicSplineUtils = require("CubicSplineUtils")
local Maid = require("Maid")
local QFrame = require("QFrame")

return function(target)
	local maid = Maid.new()

	local viewportFrame = CameraStoryUtils.setupViewportFrame(maid, target)

	local cameraCFrame = workspace.CurrentCamera.CFrame
	local a = CameraFrame.new(
		QFrame.fromCFrameClosestTo(
			CFrame.new(cameraCFrame.Position + cameraCFrame.lookVector * 25 - 20 * cameraCFrame.RightVector),
			QFrame.new()
		),
		70
	)
	local b = CameraFrame.new(
		QFrame.fromCFrameClosestTo(
			CFrame.new(cameraCFrame.Position + cameraCFrame.lookVector * 30 + 20 * cameraCFrame.RightVector)
				* CFrame.Angles(math.pi / 3, 2 * math.pi / 3, 0),
			QFrame.new()
		),
		70
	)

	local setup = CameraStoryUtils.getInterpolationFactory(maid, viewportFrame, -0.1, 1.1, 4, function(cameraFrame)
		return cameraFrame.CFrame
	end)

	setup(function(_)
		return b
	end, Color3.new(1, 0.5, 0.5))

	setup(function(_)
		return a
	end, Color3.new(0.5, 1, 0.5))

	setup(function(t)
		return CameraFrame.new((1 - t) * a.QFrame + t * b.QFrame, a.FieldOfView + (b.FieldOfView - a.FieldOfView) * t)
	end, Color3.new(0.25, 0.25, 0.25), "Linear", Vector2.new(80, 0))

	setup(function(t)
		local result = ((b.QFrame * (a.QFrame ^ -1)) ^ t) * a.QFrame
		return CameraFrame.new(result, a.FieldOfView + (b.FieldOfView - a.FieldOfView) * t)
	end, Color3.new(0.5, 0.5, 1), "Quaternion", Vector2.new(0, -80))

	setup(function(t)
		local node0 = CubicSplineUtils.newSplineNode(0, a, CameraFrame.new())
		local node1 = CubicSplineUtils.newSplineNode(1, b, CameraFrame.new())

		if t <= node0.t then
			return node0.p
		elseif t >= node1.t then
			return node1.p
		end

		local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, t)
		return newNode.p
	end, Color3.new(0.5, 1, 1), "Cubic spline", Vector2.new(0, 40))
	return function()
		maid:DoCleaning()
	end
end
