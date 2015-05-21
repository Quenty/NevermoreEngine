local ICompassElement = {}
ICompassElement.__index = ICompassElement
ICompassElement.ClassName = "ICompassElement"
ICompassElement.PercentSolid = 0.8
ICompassElement.ThetaVisible = math.pi/2

-- @author Quenty

function ICompassElement.new(Gui)
	-- @param Gui A ROBLOX GUI that represents the compass element

	local self = setmetatable({}, ICompassElement)

	-- Basic stuff
	self.Gui = Gui or error("No GUI")

	-- Private
	self.PercentPosition = 0
	self.Position = UDim2.new()

	return self
end

function ICompassElement:GetGui()
	return self.Gui
end

function ICompassElement:SetPosition(NewPosition)
	--- Sets the element's GUI into the UDim2, but centered
	-- @param NewPosition UDim2, the center of which will be positioned there.

	self.Position = NewPosition or error("No position sent")
end

function ICompassElement:SetPercentSolid(PercentSolid)
	--- Sets the percentage of the compass that is solid (that is, visible), to the player
	--  This way, we can calculate transparency
	-- @param PercentSolid Number [0, 1] of the percentage solid fo the compass element.

	self.PercentSolid = tonumber(PercentSolid) or error("No or invalid PercentSolid sent")
end

function ICompassElement:SetThetaVisible(ThetaVisible)
	-- Sets the area shown by the compass (the rest will be hidden). (In radians).
	-- @param ThetaVisible Number [0, 6.28...] The theta in radians visible to the player overall.

	self.ThetaVisible = tostring(ThetaVisible) or error("No or invalid ThetaVisible sent")
end

function ICompassElement:CalculateTransparency()
	--- Return's a GUI's transparency based on it's percent position.

	local Distance = math.abs(0.5 - self.PercentPosition)
	local Range = self.PercentSolid/2
	local ExternalRange = (1 - self.PercentSolid)/2
	local Transparency = (Distance-Range) / ExternalRange

	if Transparency >= 1 then
		return 1
	elseif Transparency <= 0 then
		return 0
	else
		return Transparency
	end
end

function ICompassElement:SetPercentPosition(Percent)
	assert(type(Percent) == "number", "Percent must be a number")

	self.PercentPosition = Percent
end

function ICompassElement:GetPercentPosition()
	return self.PercentPosition
end

function ICompassElement:Draw()
	--- Draws the compass element, updating its rendering

	self:SetTransparency(self:CalculateTransparency())

	local Size = self.Gui.AbsoluteSize
	self.Gui.Position = self.Position + UDim2.new(0, -Size.X/2, 0, -Size.Y/2)
end


-- OVERRIDDEN

function ICompassElement:SetTransparency(NewTransparency)
	-- @param NewTransparency Number, the new transparency to set the element

	error("No set transparency")
end

function ICompassElement:CalculatePercentPosition(CompassModel)
	--- The element has to calculate the percent position because the element stores 
	--  its own data about this position. This data is then passed back.
	-- @param CompassModel The compasss model to use to calculate it.

	error("CalculatePosition not overriden")
end

return ICompassElement