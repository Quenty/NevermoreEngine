--[[
	@class QFrame.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local CameraStoryUtils = require("CameraStoryUtils")
local CubicSplineUtils = require("CubicSplineUtils")
local Maid = require("Maid")
local QFrame = require("QFrame")

return function(target)
	local maid = Maid.new()

	local viewportFrame = CameraStoryUtils.setupViewportFrame(maid, target)

	local cameraCFrame = workspace.CurrentCamera.CFrame
	local a = QFrame.fromCFrameClosestTo(
		CFrame.new(cameraCFrame.Position + cameraCFrame.lookVector * 25 - 20 * cameraCFrame.RightVector),
		QFrame.new()
	)

	local setup = CameraStoryUtils.getInterpolationFactory(maid, viewportFrame, -1, 2, 8, function(qFrame)
		return QFrame.toCFrame(qFrame)
	end)

	local function getFinish(t)
		local root = CFrame.new(cameraCFrame.Position + cameraCFrame.lookVector * 25 + 20 * cameraCFrame.RightVector)
			* CFrame.Angles(math.pi / 3, 2 * math.pi / 3, 0)

		return QFrame.fromCFrameClosestTo(root * CFrame.Angles(0, math.pi * t / 3, 0), QFrame.new())
	end

	setup(function(t)
		return getFinish(t)
	end, Color3.new(1, 0.5, 0.5))

	setup(function(_)
		return a
	end, Color3.new(0.5, 1, 0.5))

	-- setup(function(t)
	-- 	return (1 - t)*a + t*getFinish(t)
	-- end, Color3.new(0.25, 0.25, 0.25))

	setup(function(t)
		return QFrame.fromCFrameClosestTo(QFrame.toCFrame(a):Lerp(QFrame.toCFrame(getFinish(t)), t), QFrame.new())
	end, Color3.new(0.75, 0.75, 0.75), "CFrame:Lerp()")

	local function slerp(q0, q1, t)
		local delta = q1 * (q0 ^ -1)
		if delta.W < 0 then
			delta = QFrame.new(delta.x, delta.y, delta.z, -delta.W, -delta.X, -delta.Y, -delta.Z)
		end

		return (delta ^ t) * q0
	end

	setup(function(t)
		local result = slerp(a, getFinish(t), t)
		return result
	end, Color3.new(0.5, 0.5, 1), "Quaternion Slerp")

	setup(function(t)
		local node0 = CubicSplineUtils.newSplineNode(0, a, QFrame.new())
		local node1 = CubicSplineUtils.newSplineNode(1, getFinish(t), QFrame.new())

		if t <= node0.t then
			return node0.p
		elseif t >= node1.t then
			return node1.p
		end

		local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, t)
		return newNode.p
	end, Color3.new(0.5, 1, 1), "Cubic Spline")

	return function()
		maid:DoCleaning()
	end
end
