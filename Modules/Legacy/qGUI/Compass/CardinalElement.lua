local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local ICompassElement = require("ICompassElement")

-- A cardinal direction for a compass
-- @author Quenty

local CardinalElement = setmetatable({}, ICompassElement)
CardinalElement.__index = CardinalElement
CardinalElement.ClassName = "CardinalElement"

function CardinalElement.new(Gui, SetTransparency, Angle)
	-- @param Gui A ROBLOX GUI that represents the compass element
	-- @param SetTransparency A function used to set transparency of the element
	-- @param Angle Number, Radians Angle on the compass, relative to "N" (0 radians).

	local self = setmetatable(ICompassElement.new(Gui), CardinalElement)

	self:SetAngle(Angle)
	self.SetTransparency = SetTransparency or error("No SetTransparency")

	return self
end

function CardinalElement:SetAngle(Angle)
	-- @param Angle Number, Radians Angle on the compass, relative to "N" (0 radians).

	assert(type(Angle) == "number", "Angle must be a number!")

	self.Angle = Angle
end

function CardinalElement:CalculatePercentPosition(CompassModel)
	-- Calculates the percent position for the element
	-- @return The percent position

	return CompassModel:GetPercentPosition(self.Angle, self.ThetaVisible)
end

return CardinalElement