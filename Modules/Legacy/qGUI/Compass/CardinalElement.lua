--- A cardinal direction for a compass
-- @classmod CardinalElement

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ICompassElement = require("ICompassElement")

local CardinalElement = setmetatable({}, ICompassElement)
CardinalElement.__index = CardinalElement
CardinalElement.ClassName = "CardinalElement"

---
-- @param Gui A ROBLOX GUI that represents the compass element
-- @param SetTransparency A function used to set transparency of the element
-- @param Angle Number, Radians Angle on the compass, relative to "N" (0 radians).
function CardinalElement.new(Gui, SetTransparency, Angle)
	local self = setmetatable(ICompassElement.new(Gui), CardinalElement)

	self:SetAngle(Angle)
	self.SetTransparency = SetTransparency or error("No SetTransparency")

	return self
end

---
-- @param Angle Number, Radians Angle on the compass, relative to "N" (0 radians).
function CardinalElement:SetAngle(Angle)
	assert(type(Angle) == "number", "Angle must be a number!")

	self.Angle = Angle
end

-- Calculates the percent position for the element
-- @return The percent position
function CardinalElement:CalculatePercentPosition(CompassModel)
	return CompassModel:GetPercentPosition(self.Angle, self.ThetaVisible)
end

return CardinalElement