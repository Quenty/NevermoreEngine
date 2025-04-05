--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.observablecollection)

local ObservableSortedList = require("ObservableSortedList")
local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")

local observableSortedList = ObservableSortedList.new()

observableSortedList.CountChanged:Connect(function(count)
	print("Count", count)
end)

observableSortedList:ObserveItemsBrio():Subscribe(function(brio)
	if brio:IsDead() then
		return
	end

	local part, key = brio:GetValue()
	local maid = brio:ToMaid()

	local currentTween
	local function setCFrame(cframe: CFrame, doNotAnimate: boolean?)
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end

		if doNotAnimate then
			part.CFrame = cframe
		else
			local tweenInfo = TweenInfo.new(0.2)
			local tween = TweenService:Create(part, tweenInfo, {
				CFrame = cframe;
			})
			currentTween = tween
			tween:Play()
		end
	end

	local first = true

	maid:GiveTask(observableSortedList:ObserveIndexByKey(key):Subscribe(function(index)
		print("change")

		if index then
			part:SetAttribute("CurrentIndex", index)
			setCFrame(CFrame.new(-5*index, 5, 0) * CFrame.Angles(0, math.pi/2, 0), first)
			first = false
		else
			part:SetAttribute("CurrentIndex", "nil")
			setCFrame(CFrame.new(part.CFrame.x, 10, 0) * CFrame.Angles(0, math.pi/2, 0), first)
			first = false
		end
	end))

	maid:GiveTask(function()
		part:SetAttribute("CurrentIndex", "nil")
		setCFrame(CFrame.new(part.CFrame.x, 5, 5) * CFrame.Angles(0, math.pi/2, 0), first)
		first = false
	end)
end)

local parts = {}
for i=9, 1, -1 do
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Size = Vector3.new(3, 3, 3)
	part.Name = i

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "SurfaceGui"
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Adornee = part
	surfaceGui.Parent = part

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "TextLabel"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextScaled = true
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.new(0, 0, 0)
	textLabel.BorderSizePixel = 0
	textLabel.Parent = surfaceGui

	RxInstanceUtils.observeProperty(part, "Name", nil):Subscribe(function(value)
		textLabel.Text = tostring(value)
	end)

	parts[i] = part
	part.Parent = workspace

	observableSortedList:Add(part, RxInstanceUtils.observeProperty(part, "Name", nil):Pipe({
		Rx.map(function(name)
			return tonumber(name)
		end)
	}))
end

parts[5].Name = "25"
parts[9].Name = "3.1"
parts[2].Name = "remove"

