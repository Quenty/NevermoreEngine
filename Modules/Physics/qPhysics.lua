local lib = {}

-- qPhysics
-- @author Quenty
-- @owner Trey Reynolds

local function GetConnectedParts(Part)
	--- Retrieves all connected parts of a part, plus the connected part
	
	local Parts = Part:GetConnectedParts(true)
	Parts[#Parts+1] = Part
	return Parts
end
lib.GetConnectedParts = GetConnectedParts
lib.getConnectedParts = GetConnectedParts

local function GetCenterOfMass(Parts)
	--- Return's the world vector center of mass.
	-- Lots of help from Hippalectryon :D

	local TotalMass = 0
	local SumOfMasses = Vector3.new(0, 0, 0)

	for _, Part in pairs(Parts) do
		-- Part.BrickColor = BrickColor.new("Bright yellow")
		TotalMass = TotalMass + Part:GetMass()
		SumOfMasses = SumOfMasses + Part:GetMass() * Part.Position
	end

	-- print("Sum of masses: " .. tostring(SumOfMasses))
	-- print("Total mass:    " .. tostring(TotalMass))

	return SumOfMasses/TotalMass, TotalMass
end
lib.GetCenterOfMass = GetCenterOfMass
lib.getCenterOfMass = GetCenterOfMass

-- Moment of Inertia of any rectangular prism.
-- 1/12 * m * sum(deminsionlengths^2)

local function MomentOfInertia(Part, Axis, Origin)
	--- Calculates the moment of inertia of a cuboid.

	-- Part is part
	-- Axis is the axis
	-- Origin is the origin of the axis

	local PartSize = Part.Size

	local Mass  = Part:GetMass()
	local Radius  = (Part.Position - Origin):Cross(Axis)
	local r2 = Radius:Dot(Radius)
	local ip = Mass * r2--Inertia based on Position
	local s2 = PartSize*PartSize
	local sa = (Part.CFrame-Part.Position):inverse()*Axis
	local id = (Vector3.new(s2.y+s2.z, s2.z+s2.x, s2.x+s2.y)):Dot(sa*sa)*Mass/12 -- Inertia based on Direction
	return ip+id
end
lib.MomentOfInertia = MomentOfInertia
lib.momentOfInertia = MomentOfInertia

local function BodyMomentOfInertia(Parts, Axis, Origin)
	--- Given a connected body of parts, returns the moment of inertia of these parts
	-- @param Parts The parts to use
	-- @param Axis the axis to use (Should be torque, or offset cross force)
	-- @param Origin The origin of the axis (should be center of mass of the parts)
	
	local TotalBodyInertia = 0

	for _, Part in pairs(Parts) do
		TotalBodyInertia = TotalBodyInertia + MomentOfInertia(Part, Axis, Origin)
	end

	return TotalBodyInertia
end
lib.BodyMomentOfInertia = BodyMomentOfInertia
lib.bodyMomentOfInertia = BodyMomentOfInertia

local function ApplyForce(Part, Force, ForcePosition)
	--- Applies a force to a ROBLOX body
	-- @param Force the force vector to apply
	-- @param ForcePosition The position that the force is to be applied from (World vector). 

	-- Credit to TreyReynolds for this code.

	-- It should be noted that setting the velocity to one part of a connected part on ROBLOX sets the velocity of the whole physics model.
	-- http://xboxforums.create.msdn.com/forums/p/34179/196459.aspx
	-- http://www.cs.cmu.edu/~baraff/sigcourse/notesd1.pdf

	local Parts = GetConnectedParts(Part)

	ForcePosition = ForcePosition or Part.Position

	local CenterOfMass, TotalMass = GetCenterOfMass(Parts)
	local Offset = (CenterOfMass - ForcePosition)
	local Torque = Offset:Cross(Force)

	local MomentOfInertia = BodyMomentOfInertia(Parts, Torque, CenterOfMass)
	local RotAcceleration = MomentOfInertia ~= 0 and Torque/MomentOfInertia or Vector3.new(0, 0, 0) -- We cannot divide by 0

	-- print("Torque:        " .. tostring(Torque))
	-- print("RotAccelerion: " .. tostring(RotAcceleration))

	local Acceleration = Force/TotalMass

	-- print("Acceleration: " .. tostring(Acceleration))

	Part.RotVelocity = Part.RotVelocity + RotAcceleration
	Part.Velocity = Part.Velocity + Acceleration
end
lib.ApplyForce = ApplyForce
lib.applyForce = ApplyForce

local function AcceleratePart(Part, EmittingPart, Acceleration)
	--- Accelerates a part utilizing newton's laws. EmittingPart is the part it's emitted from.

	-- Force = Mass * Acceleration

	local Force = Acceleration * Part:GetMass()
	local Position = Part.Position

	ApplyForce(Part, Force, Position)
	ApplyForce(EmittingPart, -Force, Position)
end
lib.AcceleratePart = AcceleratePart
lib.acceleratePart = AcceleratePart

return lib