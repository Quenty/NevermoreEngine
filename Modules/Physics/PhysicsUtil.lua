--- General physics library for use on Roblox
-- @module PhysicsUtil

local lib = {}

--- Retrieves all connected parts of a part, plus the connected part
local function GetConnectedParts(Part)
	local Parts = Part:GetConnectedParts(true)
	Parts[#Parts+1] = Part
	return Parts
end
lib.GetConnectedParts = GetConnectedParts

--- Estimate buoyancy contributed by parts
local function EstimateBuoyancyContribution(Parts)
	local TotalMass = 0
	local TotalVolumeApplicable = 0
	local TotalFloat = 0

	for _, Part in pairs(Parts) do
		local Mass = Part:GetMass()
		TotalMass = TotalMass + Mass

		TotalFloat = TotalFloat - Mass * workspace.Gravity

		if Part.CanCollide then
			local Volume = Part.Size.X*Part.Size.Y*Part.Size.Z
			local WaterDensity = 1 --(Mass/Volume)
			TotalFloat = TotalFloat + Volume*WaterDensity*workspace.Gravity
			TotalVolumeApplicable = TotalVolumeApplicable + Volume
		end
	end

	return TotalFloat, TotalMass, TotalVolumeApplicable
end
lib.EstimateBuoyancyContribution = EstimateBuoyancyContribution

--- Return's the world vector center of mass.
-- Lots of help from Hippalectryon :D
local function GetCenterOfMass(Parts)

	local TotalMass = 0
	local SumOfMasses = Vector3.new(0, 0, 0)

	for _, Part in pairs(Parts) do
		-- Part.BrickColor = BrickColor.new("Bright yellow")
		TotalMass = TotalMass + Part:GetMass()
		SumOfMasses = SumOfMasses + Part:GetMass() * Part.Position
	end

	return SumOfMasses/TotalMass, TotalMass
end
lib.GetCenterOfMass = GetCenterOfMass

--- Calculates the moment of inertia of a cuboid.
-- @param Part part
-- @param Axis the axis
-- @param Origin the origin of the axis
local function MomentOfInertia(Part, Axis, Origin)
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

--- Given a connected body of parts, returns the moment of inertia of these parts
-- @param Parts The parts to use
-- @param Axis the axis to use (Should be torque, or offset cross force)
-- @param Origin The origin of the axis (should be center of mass of the parts)
local function BodyMomentOfInertia(Parts, Axis, Origin)

	local TotalBodyInertia = 0

	for _, Part in pairs(Parts) do
		TotalBodyInertia = TotalBodyInertia + MomentOfInertia(Part, Axis, Origin)
	end

	return TotalBodyInertia
end
lib.BodyMomentOfInertia = BodyMomentOfInertia

--- Applies a force to a ROBLOX body
-- @param Force the force vector to apply
-- @param ForcePosition The position that the force is to be applied from (World vector).
--
-- It should be noted that setting the velocity to one part of a connected part on ROBLOX sets the velocity of the whole physics model.
-- http://xboxforums.create.msdn.com/forums/p/34179/196459.aspx
-- http://www.cs.cmu.edu/~baraff/sigcourse/notesd1.pdf
local function ApplyForce(Part, Force, ForcePosition)
	local Parts = GetConnectedParts(Part)

	ForcePosition = ForcePosition or Part.Position

	local CenterOfMass, TotalMass = GetCenterOfMass(Parts)
	local Offset = (CenterOfMass - ForcePosition)
	local Torque = Offset:Cross(Force)

	local MomentOfInertia = BodyMomentOfInertia(Parts, Torque, CenterOfMass)
	local RotAcceleration = MomentOfInertia ~= 0 and Torque/MomentOfInertia or Vector3.new(0, 0, 0) -- We cannot divide by 0
	local Acceleration = Force/TotalMass

	Part.RotVelocity = Part.RotVelocity + RotAcceleration
	Part.Velocity = Part.Velocity + Acceleration
end
lib.ApplyForce = ApplyForce

--- Accelerates a part utilizing newton's laws. EmittingPart is the part it's emitted from.
-- Force = Mass * Acceleration
local function AcceleratePart(Part, EmittingPart, Acceleration)

	local Force = Acceleration * Part:GetMass()
	local Position = Part.Position

	ApplyForce(Part, Force, Position)
	ApplyForce(EmittingPart, -Force, Position)
end
lib.AcceleratePart = AcceleratePart

return lib