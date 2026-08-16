--!strict
-- Helpers shared by the pie and graph renderers. Kept local to iris_ImPlot so
-- we do not add another generic Util to Nevermore's module registry.

local RNG = Random.new(os.time())

local Util = {}

function Util.DeepCopy(original: any)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = Util.DeepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

function Util.RandomColor()
	return Color3.new(RNG:NextNumber(), RNG:NextNumber(), RNG:NextNumber())
end

function Util.TextContrastBasedOnBackground(BackgroundRGB: Color3)
	local b = BackgroundRGB.R * 0.299 + BackgroundRGB.G * 0.587 + BackgroundRGB.B * 0.114

	return if b < 0.5 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
end

function Util.CutCircle(Circle: ImageLabel, Rotation: number)
	local gradient = Instance.new("UIGradient")

	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})

	gradient.Rotation = Rotation
	gradient.Parent = Circle
end

function Util.CreateSemiCircle()
	local circle = Instance.new("ImageLabel")
	circle.Image = "rbxassetid://7135409944"
	circle.BackgroundTransparency = 1

	circle.Size = UDim2.new(1, 0, 1, 0)
	circle.ScaleType = Enum.ScaleType.Fit
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.new(0.5, 0, 0.5, 0)

	local ui_corner = Instance.new("UICorner")
	ui_corner.Parent = circle
	ui_corner.CornerRadius = UDim.new(0, 0)

	return circle
end

return Util
