local ICompass = {}
ICompass.__index = ICompass
ICompass.ClassName = "ICompass"
ICompass.PercentSolid = 0.8
ICompass.ThetaVisible = math.pi/2

--- Provides a basis for the compass GUI. Invidiual CompassElements handle
--  the positioning.
-- @author Quenty

function ICompass.new(CompassModel, Container)
	--- Makes a skyrim style "strip" compass.
	-- @param CompassModel A CompassModel to use for this compass
	-- @param Container A ROBLOX GUI to use as a container

	local self = setmetatable({}, ICompass)

	-- Composition
	self.CompassModel = CompassModel or error("No CompassModel")
	self.Container = Container or error("No Container")

	self.Elements = {}

	return self
end

function ICompass:SetPercentSolid(PercentSolid)
	--- Sets the percentage of the compass that is solid (that is, visible), to the player
	--  This way, we can calculate transparency
	-- @param PercentSolid Number [0, 1] of the percentage solid fo the compass element.

	self.PercentSolid = tonumber(PercentSolid) or error("No PercentSolid")

	for Element, _ in pairs(self.Elements) do
		Element:SetPercentSolid(self.PercentSolid)
	end
end

function ICompass:SetThetaVisible(ThetaVisible)
	-- Sets the area shown by the compass (the rest will be hidden). (In radians).
	-- @param ThetaVisible Number [0, 6.28...] The theta in radians visible to the player overall.

	self.ThetaVisible = tostring(ThetaVisible) or error("No or invalid ThetaVisible sent")

	for Element, _ in pairs(self.Elements) do
		Element:SetThetaVisible(self.ThetaVisible)
	end
end

function ICompass:AddElement(Element)
	-- @param Element An ICompassElement to be added to the system

	assert(not self.Elements[Element], "Element already added")

	self.Elements[Element] = true
	Element:SetPercentSolid(self.PercentSolid)
	Element:SetThetaVisible(self.ThetaVisible)

	Element:GetGui().Parent = self.Container
end

function ICompass:GetPosition(PercentPosition)
	--- Calculates the GUI position for the element
	-- @param PercentPosition Number, the percent position to use
	-- @return UDim2 The position (center) of the GUI element given its percentage. Relative to the container.

	error("GetPosition is not overridden yet")
end

function ICompass:Draw()
	--- Updates the compass for fun!

	self.CompassModel:Step()

	for Element, _ in pairs(self.Elements) do
		local PercentPosition = Element:CalculatePercentPosition(self.CompassModel)
		Element:SetPercentPosition(PercentPosition)

		local NewPosition = self:GetPosition(PercentPosition)
		Element:SetPosition(NewPosition)
		Element:Draw()
	end
end

return ICompass