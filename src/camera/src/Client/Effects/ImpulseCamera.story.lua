--[[
	@class ImpulseCamera.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraStack = require("CameraStack")
local DefaultCamera = require("DefaultCamera")
local ImpulseCamera = require("ImpulseCamera")
local Maid = require("Maid")

return function(target)
	local maid = Maid.new()

	local stack = CameraStack.new()
	maid:GiveTask(stack)

	local defaultCamera = DefaultCamera.new()
	maid:GiveTask(defaultCamera)

	maid:GiveTask(defaultCamera:BindToRenderStep())

	local impulseCamera = ImpulseCamera.new()
	maid:GiveTask(stack:Add((defaultCamera + impulseCamera):SetMode("Relative")))

	maid:GiveTask(RunService.RenderStepped:Connect(function()
		local topState = stack:GetTopState()
		if topState then
			topState:Set(Workspace.CurrentCamera)
		end
	end))

	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "ButtonContainer"
	buttonContainer.Size = UDim2.fromScale(1, 1)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.Parent = target
	maid:GiveTask(buttonContainer)

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.FillDirection = Enum.FillDirection.Horizontal
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiListLayout.Padding = UDim.new(0, 10)
	uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	uiListLayout.Parent = buttonContainer
	maid:GiveTask(uiListLayout)

	local function makeShaker(text, impulse)
		local button = Instance.new("TextButton")
		button.Text = text
		button.BorderSizePixel = 0
		button.Size = UDim2.fromOffset(100, 50)
		button.Parent = buttonContainer
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 20
		button.TextColor3 = Color3.new(0, 0, 0)
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		maid:GiveTask(button)

		local uiCorner = Instance.new("UICorner")
		uiCorner.Parent = button
		maid:GiveTask(uiCorner)

		maid:GiveTask(button.Activated:Connect(impulse))
	end

	makeShaker("Shake", function()
		impulseCamera:Impulse(Vector3.new(0, math.random() - 0.5, math.random() - 0.5) * 50, 50, 0.2)
	end)
	makeShaker("SHAKE", function()
		impulseCamera:ImpulseRandom(Vector3.new(0, 3, 0), 75, 0.1)
	end)

	return function()
		maid:DoCleaning()
	end
end
