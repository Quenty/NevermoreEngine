local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local ICompass          = LoadCustomLibrary("ICompass")

-- StripCompass.lua
-- @author Quenty
-- A Skyrim style compass. Yay!

local StripCompass = setmetatable({}, ICompass)
StripCompass.__index = StripCompass
StripCompass.ClassName = "StripCompass"

function StripCompass.new(CompassModel, Container)
	--- Constructs a new skyrim style compass

	local self = setmetatable(ICompass.new(CompassModel, Container), StripCompass)

	return self
end

function StripCompass:GetPosition(PercentPosition)
	--- Calculates the GUI position for the element
	-- @param PercentPosition Number, the percent position to use
	-- @return UDim2 The position (center) of the GUI element given its percentage. Relative to the container.
	
	return UDim2.new(PercentPosition, 0, 0.5, 0)
end

return StripCompass