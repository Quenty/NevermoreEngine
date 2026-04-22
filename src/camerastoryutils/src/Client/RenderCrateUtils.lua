--!strict
--[=[
    @class RenderCrateUtils
]=]

local require = require(script.Parent.loader).load(script)

local Blend = require("Blend")

local RenderCrateUtils = {}

function RenderCrateUtils.crate()
	local center = Blend.State(nil)

	return Blend.New "Model" {
		Name = "Wood Crate",
		PrimaryPart = center,
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(1.7, -0.300135, -1.699984, 0, -1, 0, -1, 0, 0, 0, 0, -1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(180, 0, 90),
		},
		Blend.New "Part" {
			Size = Vector3.new(2.8, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(0, 1.7, -1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
		},
		Blend.New "Part" {
			Size = Vector3.new(4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(0, 0.028748, 1.641696, -0.707111, -0.707102, 0, 0.707102, -0.707112, 0, 0, 0, 1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(0, 0, 135),
		},
		Blend.New "Part" {
			Size = Vector3.new(0.6, 0.6, 4),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(0, 0.028749, -1.658263, 0, -0.707102, -0.707111, 0, -0.707111, 0.707102, -1, -0, 0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(-90, -45, 90),
		},
		Blend.New "Part" {
			Size = Vector3.new(4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(
				-1.649982,
				0.02874,
				-0.008285,
				0,
				0,
				-1,
				0.707106,
				-0.707108,
				0,
				-0.707108,
				-0.707106,
				-0
			),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(-135, -90, 0),
		},
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(0.3, -1.7, 1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
		},
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(-1.7, 1.7, -0.3) * CFrame.Angles(0, math.pi / 2, 0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(0, 90, 0),
		},
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(-1.7, -0.3, -1.7) * CFrame.Angles(-math.pi / 2, math.pi / 2, 0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(-90, 90, 0),
		},
		Blend.New "Part" {
			Size = Vector3.new(2.8, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(0.000019, -1.70013, -1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
		},
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(1.7, 0.3, 1.7, 0, -1, 0, 1, 0, 0, 0, 0, 1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(0, 0, 90),
		},
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(-0.3, 1.7, 1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
		},
		Blend.New "Part" {
			Size = Vector3.new(4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(1.649986, 0.028765, 0, 0, 0, 1, 0.707111, 0.707102, 0, -0.707102, 0.707111, 0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(45, 90, 0),
		},
		Blend.New "Part" {
			Size = Vector3.new(4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(-0.007957, 1.649938, 0.054213, 0.707106, 0, 0.707108, 0, 1, 0, -0.707108, 0, 0.707106),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(0, 45, 0.001),
		},
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(-1.699978, -1.700141, 0.299995) * CFrame.Angles(0, math.pi / 2, 0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(0, 90, 0),
		},
		Blend.New "Part" {
			Size = Vector3.new(2.8, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(-1.7, 0, 1.7, 0, 1, 0, -1, 0, 0, 0, 0, 1),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(0, 0, -90),
		},
		Blend.New "Part" {
			Size = Vector3.new(4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(0, -1.671373, -0.008285, 0.707105, 0.707108, -0, 0, 0, 1, 0.707108, -0.707105, -0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(-90, -0.001, -45),
		},
		Blend.New "Part" {
			Size = Vector3.new(2.8, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(1.7, -1.7, 0) * CFrame.Angles(math.pi, math.pi / 2, 0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(180, 90, 0),
		},
		Blend.New "Part" {
			Name = "Center",
			Size = Vector3.new(3.6, 3.6, 3.6),
			BrickColor = BrickColor.new("Brown"),
			CFrame = CFrame.Angles(0, 0, 0),
			Color = Color3.fromRGB(124, 92, 70),
			Material = Enum.Material.WoodPlanks,
			[Blend.Instance] = center,
		},
		Blend.New "Part" {
			Size = Vector3.new(3.4, 0.6, 0.6),
			BrickColor = BrickColor.new("Reddish brown"),
			CFrame = CFrame.new(1.7, 1.7, -0.3) * CFrame.Angles(0, -math.pi / 2, 0),
			Color = Color3.fromRGB(105, 64, 40),
			Material = Enum.Material.WoodPlanks,
			Rotation = Vector3.new(0, -90, 0),
		},
	}
end

return RenderCrateUtils
