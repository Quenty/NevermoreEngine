---
-- @module QFrame.story
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local QFrame = require("QFrame")
local InsertServiceUtils = require("InsertServiceUtils")

local function reflectCamera(maid, topCamera)
	local camera = Instance.new("Camera")
	camera.Name = "ReflectedCamera"
	maid:GiveTask(camera)

	local function update()
		camera.FieldOfView = topCamera.FieldOfView
		camera.CFrame = topCamera.CFrame
	end
	maid:GiveTask(topCamera:GetPropertyChangedSignal("CFrame"):Connect(update))
	maid:GiveTask(topCamera:GetPropertyChangedSignal("FieldOfView"):Connect(update))

	update()

	return camera
end

return function(target)
	local maid = Maid.new()

	local viewPortFrame = Instance.new("ViewportFrame")
	viewPortFrame.ZIndex = 0
	viewPortFrame.BorderSizePixel = 0
	viewPortFrame.BackgroundColor3 = Color3.new(0.7, 0.7, 0.7)
	viewPortFrame.Size = UDim2.new(1, 0, 1, 0)
	maid:GiveTask(viewPortFrame)

	local reflectedCamera = reflectCamera(maid, workspace.CurrentCamera)
	reflectedCamera.Parent = viewPortFrame
	viewPortFrame.CurrentCamera = reflectedCamera

	local cameraCFrame = workspace.CurrentCamera.CFrame
	local startQFrame = QFrame.fromCFrameClosestTo(
		CFrame.new(cameraCFrame.Position + cameraCFrame.lookVector*25),
		QFrame.new())
	local endQFrame = QFrame.fromCFrameClosestTo(
		CFrame.new(cameraCFrame.Position + cameraCFrame.lookVector*25 + 10*cameraCFrame.RightVector)
			* CFrame.Angles(math.pi/3, 2*math.pi/3, 0),
		QFrame.new())

	local function setup(interpolate, color)
		maid:GivePromise(InsertServiceUtils.promiseAsset(182451181)):Then(function(model)
			maid:GiveTask(model)

			local crate = model:GetChildren()[1]
			if not crate then
				return
			end

			for _, item in pairs(crate:GetDescendants()) do
				if item:IsA("BasePart") then
					item.Color = color
					item.Transparency = 0.5
				end
			end

			crate.Parent = viewPortFrame

			local PERIOD = 1
			maid:GiveTask(RunService.RenderStepped:Connect(function()
				local t = (os.clock()/PERIOD % 2/PERIOD)*PERIOD
				if t >= 1 then
					t = 1 - (t % 1)
				end

				t = t*3 - 1

				local qFrame = interpolate(t)
				crate:SetPrimaryPartCFrame(QFrame.toCFrame(qFrame))
			end))

			viewPortFrame.Parent = target
		end)
	end

	setup(function(t)
		return endQFrame
	end, Color3.new(1, 0.5, 0.5))

	setup(function(t)
		return startQFrame
	end, Color3.new(0.5, 1, 0.5))

	setup(function(t)
		return (1 - t)*startQFrame + t*endQFrame
	end, Color3.new(0.25, 0.25, 0.25))

	setup(function(t)
		local result = ((endQFrame*(startQFrame^-1))^t)*startQFrame
		return result
	end, Color3.new(0.5, 0.5, 1))

	return function()
		maid:DoCleaning()
	end
end