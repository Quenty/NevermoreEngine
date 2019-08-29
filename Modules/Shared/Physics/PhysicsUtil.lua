--- General physics library for use on Roblox
-- @module PhysicsUtil

local Workspace = game:GetService("Workspace")

local PhysicsUtil = {}
PhysicsUtil.WATER_DENSITY = 1 -- (mass/volume)

--- Retrieves all connected parts of a part, plus the connected part
function PhysicsUtil.GetConnectedParts(part)
	local parts = part:GetConnectedParts(true)
	parts[#parts+1] = part
	return parts
end

function PhysicsUtil.GetMass(parts)
	local mass = 0
	for _, part in pairs(parts) do
		mass = mass + part:GetMass()
	end
	return mass
end

--- Estimate buoyancy contributed by parts
function PhysicsUtil.EstimateBuoyancyContribution(parts)
	local totalMass = 0
	local totalVolumeApplicable = 0
	local totalFloat = 0

	for _, part in pairs(parts) do
		local mass = part:GetMass()
		totalMass = totalMass + mass
		totalFloat = totalFloat - mass * Workspace.Gravity

		if part.CanCollide then
			local volume = part.Size.X*part.Size.Y*part.Size.Z
			totalFloat = totalFloat + volume*PhysicsUtil.WATER_DENSITY*Workspace.Gravity
			totalVolumeApplicable = totalVolumeApplicable + volume
		end
	end

	return totalFloat, totalMass, totalVolumeApplicable
end

--- Return's the world vector center of mass.
-- Lots of help from Hippalectryon :D
function PhysicsUtil.GetCenterOfMass(parts)
	local mass = 0
	local weightedSum = Vector3.new(0, 0, 0)

	for _, part in pairs(parts) do
		-- part.BrickColor = BrickColor.new("Bright yellow")
		mass = mass + part:GetMass()
		weightedSum = weightedSum + part:GetMass() * part.Position
	end

	return weightedSum/mass, mass
end

--- Calculates the moment of inertia of a cuboid.
-- @param part part
-- @param axis the axis
-- @param origin the origin of the axis
function PhysicsUtil.MomentOfInertia(part, axis, origin)
	local PartSize = part.Size
	local mass  = part:GetMass()
	local Radius  = (part.Position - origin):Cross(axis)
	local r2 = Radius:Dot(Radius)
	local ip = mass * r2--Inertia based on Position
	local s2 = PartSize*PartSize
	local sa = (part.CFrame-part.Position):inverse()*axis
	local id = (Vector3.new(s2.y+s2.z, s2.z+s2.x, s2.x+s2.y)):Dot(sa*sa)*mass/12 -- Inertia based on Direction
	return ip+id
end

--- Given a connected body of parts, returns the moment of inertia of these parts
-- @param parts The parts to use
-- @param axis the axis to use (Should be torque, or offset cross force)
-- @param origin The origin of the axis (should be center of mass of the parts)
function PhysicsUtil.BodyMomentOfInertia(parts, axis, origin)

	local TotalBodyInertia = 0

	for _, part in pairs(parts) do
		TotalBodyInertia = TotalBodyInertia + PhysicsUtil.MomentOfInertia(part, axis, origin)
	end

	return TotalBodyInertia
end

--- Applies a force to a ROBLOX body
-- @param force the force vector to apply
-- @param forcePosition The position that the force is to be applied from (World vector).
--
-- It should be noted that setting the velocity to one part of a connected part on ROBLOX sets the velocity of the whole physics model.
-- http://xboxforums.create.msdn.com/forums/p/34179/196459.aspx
-- http://www.cs.cmu.edu/~baraff/sigcourse/notesd1.pdf
function PhysicsUtil.ApplyForce(part, force, forcePosition)
	local parts = PhysicsUtil.GetConnectedParts(part)

	forcePosition = forcePosition or part.Position

	local CenterOfMass, mass = PhysicsUtil.GetCenterOfMass(parts)
	local Offset = (CenterOfMass - forcePosition)
	local Torque = Offset:Cross(force)

	local MomentOfInertia = PhysicsUtil.BodyMomentOfInertia(parts, Torque, CenterOfMass)
	local RotAcceleration = MomentOfInertia ~= 0 and Torque/MomentOfInertia or Vector3.new(0, 0, 0) -- We cannot divide by 0
	local acceleration = force/mass

	part.RotVelocity = part.RotVelocity + RotAcceleration
	part.Velocity = part.Velocity + acceleration
end

--- Accelerates a part utilizing newton's laws. emittingPart is the part it's emitted from.
-- force = mass * acceleration
function PhysicsUtil.AcceleratePart(part, emittingPart, acceleration)
	local force = acceleration * part:GetMass()
	local Position = part.Position

	PhysicsUtil.ApplyForce(part, force, Position)
	PhysicsUtil.ApplyForce(emittingPart, -force, Position)
end

return PhysicsUtil