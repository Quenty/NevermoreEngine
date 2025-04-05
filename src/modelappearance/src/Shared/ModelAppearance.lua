--[=[
	Allows the appearance of a model to be overridden. Most commonly used when
	placing down an object in a building game.

	@class ModelAppearance
]=]

local require = require(script.Parent.loader).load(script)

local Math = require("Math")

local ModelAppearance = {}
ModelAppearance.ClassName = "ModelAppearance"
ModelAppearance.__index = ModelAppearance

function ModelAppearance.new(model)
	local self = setmetatable({}, ModelAppearance)

	self._parts = {}
	self._interactions = {}
	self._seats = {}

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			self._parts[part] = {
				Transparency = part.Transparency;
				Color = part.Color;
				Material = part.Material;
				CanCollide = part.CanCollide;
			}

			if part:IsA("Seat") or part:IsA("VehicleSeat") then
				self._seats[part] = part
			end

			if part:IsA("PartOperation") then
				self._parts[part].UsePartColor = part.UsePartColor
			end
		elseif part:IsA("ClickDetector") or part:IsA("BodyMover") then
			table.insert(self._interactions, part)
		end
	end

	return self
end

-- Destructive, cannot be reverted
function ModelAppearance:DisableInteractions()
	for _, item in self._interactions do
		item:Destroy()
	end
	self._interactions = {}
	for seat, _ in self._seats do
		seat.Disabled = true
	end

	self:SetCanCollide(false)
end

function ModelAppearance:SetCanCollide(canCollide: boolean)
	assert(type(canCollide) == "boolean", "Bad canCollide")

	if self._canCollide == canCollide then
		return
	end

	self._canCollide = canCollide
	for part, properties in self._parts do
		part.CanCollide = properties.CanCollide and canCollide
	end
end

function ModelAppearance:ResetCanCollide()
	self:SetCanCollide(true)
end

function ModelAppearance:SetTransparency(transparency)
	if self._transparency == transparency then
		return
	end

	self._transparency = transparency
	for part, properties in self._parts do
		part.Transparency = Math.map(transparency, 0, 1, properties.Transparency, 1)
	end
end

function ModelAppearance:ResetTransparency()
	if not self._transparency then
		return
	end

	self._transparency = nil
	for part, properties in self._parts do
		part.Transparency = properties.Transparency
	end
end

function ModelAppearance:SetColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	if self._color == color then
		return
	end

	self._color = color
	for part, _ in self._parts do
		part.Color = color

		if part:IsA("PartOperation") then
			part.UsePartColor = true
		end
	end
end

function ModelAppearance:ResetColor()
	if not self._color then
		return
	end

	self._color = nil
	for part, properties in self._parts do
		part.Color = properties.Color

		if part:IsA("PartOperation") then
			part.UsePartColor = properties.UsePartColor
		end
	end
end

function ModelAppearance:ResetMaterial()
	if not self._material then
		return
	end

	self._material = nil
	for part, properties in self._parts do
		part.Material = properties.Material
	end
end

function ModelAppearance:SetMaterial(material)
	if self._material == material then
		return
	end

	self._material = material
	for part, _ in self._parts do
		part.Material = material
	end
end

return ModelAppearance