---
-- @module CameraStoryUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local InsertServiceUtils = require("InsertServiceUtils")
local Promise = require("Promise")
local Math = require("Math")

local CameraStoryUtils = {}

function CameraStoryUtils.reflectCamera(maid, topCamera)
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

function CameraStoryUtils.setupViewportFrame(maid, target)
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.ZIndex = 0
	viewportFrame.BorderSizePixel = 0
	viewportFrame.BackgroundColor3 = Color3.new(0.9, 0.9, 0.85)
	viewportFrame.Size = UDim2.new(1, 0, 1, 0)
	maid:GiveTask(viewportFrame)

	local reflectedCamera = CameraStoryUtils.reflectCamera(maid, workspace.CurrentCamera)
	reflectedCamera.Parent = viewportFrame
	viewportFrame.CurrentCamera = reflectedCamera

	viewportFrame.Parent = target

	return viewportFrame
end

function CameraStoryUtils.promiseCrate(maid, viewportFrame, properties)
	return maid:GivePromise(InsertServiceUtils.promiseAsset(182451181)):Then(function(model)
		maid:GiveTask(model)

		local crate = model:GetChildren()[1]
		if not crate then
			return Promise.rejected()
		end

		if properties then
			for _, item in pairs(crate:GetDescendants()) do
				if item:IsA("BasePart") then
					for property, value in pairs(properties) do
						item[property] = value
					end
				end
			end
		end

		crate.Parent = viewportFrame

		local camera = viewportFrame.CurrentCamera
		if camera then
			local cameraCFrame = camera.CFrame
			local cframe = CFrame.new(cameraCFrame.Position + cameraCFrame.lookVector*25)
			crate:SetPrimaryPartCFrame(cframe)
		end

		return Promise.resolved(crate)
	end)
end

function CameraStoryUtils.getInterpolationFactory(maid, viewportFrame, low, high, period, toCFrame)
	assert(maid, "Bad maid")
	assert(viewportFrame, "Bad viewportFrame")
	assert(type(low) == "number", "Bad low")
	assert(type(high) == "number", "Bad high")
	assert(type(period) == "number", "Bad period")
	assert(type(toCFrame) == "function", "Bad toCFrame")

	return function(interpolate, color, labelText, labelOffset)
		assert(type(interpolate) == "function", "Bad interpolate")
		assert(typeof(color) == "Color3", "Bad color")

		labelOffset = labelOffset or Vector2.new(0, 0)

		maid:GivePromise(CameraStoryUtils.promiseCrate(maid, viewportFrame, {
			Color = color;
			Transparency = 0.5
		}))
			:Then(function(crate)
				local label
				if labelText then
					local h, s, _ = Color3.toHSV(color)
					label = Instance.new("TextLabel")
					label.AnchorPoint = Vector2.new(0.5, 0.5)
					label.Text = labelText
					label.BorderSizePixel = 0
					label.BackgroundTransparency = 0.5
					label.BackgroundColor3 = Color3.fromHSV(h, math.clamp(s/(s+0.1), 0, 1), 0.25)
					label.TextColor3 = Color3.new(1, 1, 1)
					label.Font = Enum.Font.FredokaOne
					label.TextSize = 15
					label.Parent = viewportFrame
					label.Visible = false
					maid:GiveTask(label)

					local size = TextService:GetTextSize(labelText, label.TextSize, label.Font, Vector2.new(1e6, 1e6))
						label.Size = UDim2.new(0, size.x + 20, 0, 20)

					local uiCorner = Instance.new("UICorner")
					uiCorner.CornerRadius = UDim.new(0.5, 0)
					uiCorner.Parent = label
					maid:GiveTask(label)
				end

				-- avoid floating point numbers from :SetPrimaryPartCFrame
				local primaryPart, primaryCFrame
				local relCFrame = {}
				for _, part in pairs(crate:GetDescendants()) do
					if part:IsA("BasePart") then
						if primaryPart then
							relCFrame[part] = primaryCFrame:toObjectSpace(part.CFrame)
						else
							primaryPart = part
							primaryCFrame = part.CFrame
							relCFrame[part] = CFrame.new()
						end
					end
				end

				maid:GiveTask(RunService.RenderStepped:Connect(function()
					local t = (os.clock()/period % 2/period)*period
					if t >= 1 then
						t = 1 - (t % 1)
					end

					t = Math.map(t, 0, 1, low, high)
					t = math.clamp(t, low, high)

					local cframe = toCFrame(interpolate(t))

					if label then
						local camera = viewportFrame.CurrentCamera
						local pos = camera:WorldToViewportPoint(cframe.p)
						local viewportSize = viewportFrame.AbsoluteSize
						local aspectRatio = viewportSize.x/viewportSize.y
						if pos.z > 0 then
							label.Position = UDim2.new((pos.x - 0.5)/aspectRatio + 0.5, labelOffset.x, pos.y, 0 + labelOffset.y)
							label.Visible = true
						else
							label.Visible = false
						end
					end

					for part, rel in pairs(relCFrame) do
						part.CFrame = cframe:toWorldSpace(rel)
					end
				end))
			end)
	end
end

return CameraStoryUtils