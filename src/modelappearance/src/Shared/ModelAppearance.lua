--!strict
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

export type ModelAppearance = typeof(setmetatable(
	{} :: {
		_parts: {
			[BasePart]: {
				Transparency: number,
				Color: Color3,
				Material: Enum.Material,
				CanCollide: boolean,
				UsePartColor: boolean?,
			},
		},
		_interactions: { Instance },
		_seats: { [Seat | VehicleSeat]: Instance },
		_canCollide: boolean?,
		_transparency: number?,
		_color: Color3?,
		_material: Enum.Material?,
	},
	{} :: typeof({ __index = ModelAppearance })
))

function ModelAppearance.new(model: Instance): ModelAppearance
	local self: ModelAppearance = setmetatable({} :: any, ModelAppearance)

	self._parts = {}
	self._interactions = {}
	self._seats = {}

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			self._parts[part] = {
				Transparency = part.Transparency,
				Color = part.Color,
				Material = part.Material,
				CanCollide = part.CanCollide,
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

--[=[
	Disables all interactions with the model. This includes click detectors and seats

	:::tip
	Destructive, cannot be reverted
	:::
]=]
function ModelAppearance.DisableInteractions(self: ModelAppearance)
	for _, item in self._interactions do
		item:Destroy()
	end
	self._interactions = {}
	for seat, _ in self._seats do
		(seat :: Seat).Disabled = true
	end

	self:SetCanCollide(false)
end

--[=[
	Sets the models collision state
]=]
function ModelAppearance.SetCanCollide(self: ModelAppearance, canCollide: boolean)
	assert(type(canCollide) == "boolean", "Bad canCollide")

	if self._canCollide == canCollide then
		return
	end

	self._canCollide = canCollide
	for part, properties in self._parts do
		part.CanCollide = properties.CanCollide and canCollide
	end
end

--[=[
	Resets the can collide state to the original state
]=]
function ModelAppearance.ResetCanCollide(self: ModelAppearance)
	self:SetCanCollide(true)
end

--[=[
	Sets the transparency of the model

	@param transparency number
]=]
function ModelAppearance.SetTransparency(self: ModelAppearance, transparency: number)
	if self._transparency == transparency then
		return
	end

	self._transparency = transparency
	for part, properties in self._parts do
		part.Transparency = Math.map(transparency, 0, 1, properties.Transparency, 1)
	end
end

--[=[
	Resets the transparency to the original state
]=]
function ModelAppearance.ResetTransparency(self: ModelAppearance)
	if not self._transparency then
		return
	end

	self._transparency = nil
	for part, properties in self._parts do
		part.Transparency = properties.Transparency
	end
end

--[=[
	Sets the color of the model

	@param color Color3
]=]
function ModelAppearance.SetColor(self: ModelAppearance, color: Color3)
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

--[=[
	Resets the color to the original state
]=]
function ModelAppearance.ResetColor(self: ModelAppearance)
	if not self._color then
		return
	end

	self._color = nil
	for part, properties in self._parts do
		part.Color = properties.Color

		if part:IsA("PartOperation") then
			part.UsePartColor = properties.UsePartColor :: boolean
		end
	end
end

--[=[
	Resets the material to the original state
]=]
function ModelAppearance.ResetMaterial(self: ModelAppearance): ()
	if not self._material then
		return
	end

	self._material = nil
	for part, properties in self._parts do
		part.Material = properties.Material
	end
end

--[=[
	Sets the material of the model

	@param material Enum.Material
]=]
function ModelAppearance.SetMaterial(self: ModelAppearance, material: Enum.Material)
	if self._material == material then
		return
	end

	self._material = material
	for part, _ in self._parts do
		part.Material = material
	end
end

return ModelAppearance