local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local ICompass          = LoadCustomLibrary("ICompass")

-- CircleCompass.lua
-- @author Quenty
-- A classically circle compass

local CircleCompass = setmetatable({}, ICompass)
CircleCompass.__index = CircleCompass
CircleCompass.ClassName = "CircleCompass"

function CircleCompass.new(CompassModel, Container)
	--- Constructs a new skyrim style compass
	
	local self = setmetatable(ICompass.new(CompassModel, Container), CircleCompass)
	
	self:UpdateThetaCalculations()

	return self
end

function CircleCompass:UpdateThetaCalculations()
	local ContainerSize = self.Container.AbsoluteSize

	local Width            = ContainerSize.X
	local Height           = ContainerSize.Y -- CANNOT BE > WIDTH / 2. PANIC. PANIC. MAYBE. TREY IS CRAY CRAY
	local Radius           = (Height/2) + ((Width*Width)/(8 * Height)) 
	local ArcLength        = (2 * Height + Width*Width / (2 * Height)) * math.atan(2 * Height / Width )
	local ThetaVisible     = ArcLength/Radius -- Theta visible in the box.	(Number, will be [-HalfThetaVisible, HalfThetaVisible])

	self.Radius = Radius

	if self.ThetaVisible ~= ThetaVisible then
		self:SetThetaVisible(ThetaVisible)
	end
end

function CircleCompass:SetRadius(Radius)
	-- @param Radius The radius of the circle compass

	self.Radius = tonumber(Radius) or error("Radius is iether not sent or not a number")
end

function CircleCompass:Draw()
	local Super = getmetatable(CircleCompass)

	self:UpdateThetaCalculations()

	Super.Draw(self)
end

function CircleCompass:GetPosition(PercentPosition)
	--- Calculates the GUI position for the element
	-- @param PercentPosition Number, the percent position to use
	-- @return UDim2 The position (center) of the GUI element given its percentage. Relative to the container.
	-- @return [Rotation] Number in radians, the rotation of the GUI to be set.

	local HalfThetaVisible = self.ThetaVisible/2

	local RadianTheta  = HalfThetaVisible * (PercentPosition - 0.5)
	local NewLocationX = math.sin(RadianTheta) * self.Radius
	local NewLocationY = math.cos(RadianTheta) * self.Radius

	local Position = UDim2.new(0.5, NewLocationX, 0, self.Radius - NewLocationY)
	local Rotation = RadianTheta * 180 / math.pi

	return Position, Rotation
end

return CircleCompass