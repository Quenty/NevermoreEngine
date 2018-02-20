--- Control appearance of model being placed
-- @classmod ModelAppearance

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local qMath = require("qMath")

local ModelAppearance = {}
ModelAppearance.ClassName = "ModelAppearance"
ModelAppearance.__index = ModelAppearance

function ModelAppearance.new(parts)
	local self = setmetatable({}, ModelAppearance)

	self._parts = {}
	for _, part in pairs(parts) do
		self._parts[part] = {
			Transparency = part.Transparency;
			Color = part.Color;
			Material = part.Material;
			CanCollide = part.CanCollide;
		}

		if part:IsA("Seat") or part:IsA("VehicleSeat") then
			self._parts[part].IsSeat = true
			self._parts[part].Disabled = part.Disabled
		end
	end

	return self
end

function ModelAppearance:SetCanCollide(canCollide)
	for part, properties in pairs(self._parts) do
		part.CanCollide = properties.CanCollide and canCollide
		if properties.IsSeat then
			if canCollide then
				part.Disabled = properties.Disabled
			else
				part.Disabled = true
			end
		end
	end
end

function ModelAppearance:SetTransparency(transparency)
	for part, properties in pairs(self._parts) do
		part.Transparency = qMath.MapNumber(transparency, 0, 1, properties.Transparency, 1)
	end
end

function ModelAppearance:ResetTransparency()
	for part, properties in pairs(self._parts) do
		part.Transparency = properties.Transparency
	end
end

function ModelAppearance:SetColor(color)
	for part, _ in pairs(self._parts) do
		part.Color = color
	end
end

function ModelAppearance:ResetColor()
	for part, properties in pairs(self._parts) do
		part.Color = properties.Color
	end
end

function ModelAppearance:ResetMaterial()
	for part, properties in pairs(self._parts) do
		part.Material = properties.Material
	end
end

function ModelAppearance:SetMaterial(material)
	for part, _ in pairs(self._parts) do
		part.Material = material
	end
end

return ModelAppearance