-- An interest point for an element
-- @classmod ICompassElement

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ICompassElement = require("ICompassElement")

local PointElement = setmetatable({}, ICompassElement)
PointElement.__index = PointElement
PointElement.ClassName = "PointElement"

---
-- @param Gui A ROBLOX GUI that represents the compass element
-- @param SetTransparency A function used to set transparency of the element
-- @param Part A ROBLOX part to track. :)
function PointElement.new(Gui, SetTransparency, Part)
	local self = setmetatable(ICompassElement.new(Gui), PointElement)

	self:SetPart(Part)
	self.SetTransparency = SetTransparency or error("No SetTransparency")

	return self
end

---
-- @param Part A ROBLOX part to track. :)
function PointElement:SetPart(Part)
	self.Part = Part or error("No part")

	-- Assert after we verify Part isn't nil
	assert(Part:IsA("BasePart"), "Part must be a base part")
end

--- Calculates the percent position for the element
-- @return The percent position
function PointElement:CalculatePercentPosition(CompassModel)
	local Angle = CompassModel:GetRelativeAngle(self.Part.Position)
	return CompassModel:GetPercentPosition(Angle, self.ThetaVisible)
end

return PointElement