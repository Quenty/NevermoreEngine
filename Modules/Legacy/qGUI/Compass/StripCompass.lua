--- A Skyrim style compass. Yay!
-- @classmod StripCompass

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ICompass = require("ICompass")

local StripCompass = setmetatable({}, ICompass)
StripCompass.__index = StripCompass
StripCompass.ClassName = "StripCompass"

--- Constructs a new skyrim style compass
function StripCompass.new(CompassModel, Container)
	local self = setmetatable(ICompass.new(CompassModel, Container), StripCompass)

	return self
end

--- Calculates the GUI position for the element
-- @param PercentPosition Number, the percent position to use
-- @return UDim2 The position (center) of the GUI element given its percentage. Relative to the container.
function StripCompass:GetPosition(PercentPosition)

	return UDim2.new(PercentPosition, 0, 0.5, 0)
end

return StripCompass