-- PointElement.lua
-- An interest point for an element
-- @author Quenty

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local ICompassElement   = LoadCustomLibrary("ICompassElement")

local PointElement = setmetatable({}, ICompassElement)
PointElement.__index = PointElement
PointElement.ClassName = "PointElement"

function PointElement.new(Gui, SetTransparency, Part)
	-- @param Gui A ROBLOX GUI that represents the compass element
	-- @param SetTransparency A function used to set transparency of the element
	-- @param Part A ROBLOX part to track. :)

	local self = setmetatable(ICompassElement.new(Gui), PointElement)

	self:SetPart(Part)
	self.SetTransparency = SetTransparency or error("No SetTransparency")

	return self
end

function PointElement:SetPart(Part)
	-- @param Part A ROBLOX part to track. :)


	self.Part = Part or error("No part")

	-- Assert after we verify Part isn't nil
	assert(Part:IsA("BasePart"), "Part must be a base part")
end

function PointElement:CalculatePercentPosition(CompassModel)
	-- Calculates the percent position for the element
	-- @return The percent position

	local Angle = CompassModel:GetRelativeAngle(self.Part.Position)
	return CompassModel:GetPercentPosition(Angle, self.ThetaVisible)
end

return PointElement
