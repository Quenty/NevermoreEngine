--- General physics library for use on Roblox
-- @module PhysicsUtils

local Workspace = game:GetService("Workspace")

local PhysicsUtils = {}
PhysicsUtils.WATER_DENSITY = 1 -- (mass/volume)

--- Retrieves all connected parts of a part, plus the connected part
function PhysicsUtils.getConnectedParts(part)
	local parts = part:GetConnectedParts(true)
	parts[#parts+1] = part
	return parts
end

function PhysicsUtils.getMass(parts)
	local mass = 0
	for _, part in pairs(parts) do
		mass = mass + part:GetMass()
	end
	return mass
end

--- Estimate buoyancy contributed by parts
function PhysicsUtils.estimateBuoyancyContribution(parts)
	local totalMass = 0
	local totalVolumeApplicable = 0
	local totalFloat = 0

	for _, part in pairs(parts) do
		local mass = part:GetMass()
		totalMass = totalMass + mass
		totalFloat = totalFloat - mass * Workspace.Gravity

		if part.CanCollide then
			local volume = part.Size.X*part.Size.Y*part.Size.Z
			totalFloat = totalFloat + volume*PhysicsUtils.WATER_DENSITY*Workspace.Gravity
			totalVolumeApplicable = totalVolumeApplicable + volume
		end
	end

	return totalFloat, totalMass, totalVolumeApplicable
end

--- Return's the world vector center of mass.
-- Lots of help from Hippalectryon :D
function PhysicsUtils.getCenterOfMass(parts)
	local mass = 0
	local weightedSum = Vector3.new(0, 0, 0)

	for _, part in pairs(parts) do
		-- part.BrickColor = BrickColor.new("Bright yellow")
		mass = mass + part:GetMass()
		weightedSum = weightedSum + part:GetMass() * part.Position
	end

	return weightedSum/mass, mass
end

--- Calculates the moment of inertia of a solid cuboid. This is wrong for Roblox.
-- @param part part
-- @param axis the axis
-- @param origin the origin of the axis
function PhysicsUtils.momentOfInertia(part, axis, origin)
	local size = part.Size
	local position = part.Position
	local cframe = part.CFrame
	local mass = part:GetMass()

	local radius  = (position - origin):Cross(axis)
	local r2 = radius:Dot(radius)
	local ip = mass * r2 -- inertia based on position
	local s2 = size*size
	local sa = cframe:vectorToObjectSpace(axis)
	local id = (Vector3.new(s2.y+s2.z, s2.z+s2.x, s2.x+s2.y)):Dot(sa*sa)*mass/12 -- Inertia based on direction
	return ip+id
end

--- Given a connected body of parts, returns the moment of inertia of these parts
-- @param parts The parts to use
-- @param axis the axis to use (Should be torque, or offset cross force)
-- @param origin The origin of the axis (should be center of mass of the parts)
function PhysicsUtils.bodyMomentOfInertia(parts, axis, origin)
	local totalBodyInertia = 0

	for _, part in pairs(parts) do
		totalBodyInertia = totalBodyInertia + PhysicsUtils.momentOfInertia(part, axis, origin)
	end

	return totalBodyInertia
end

--- Applies a force to a Roblox body
-- @param force the force vector to apply
-- @param forcePosition The position that the force is to be applied from (World vector).
--
-- It should be noted that setting the velocity to one part of a connected part on Roblox sets
-- the velocity of the whole physics model.
-- http://xboxforums.create.msdn.com/forums/p/34179/196459.aspx
-- http://www.cs.cmu.edu/~baraff/sigcourse/notesd1.pdf
function PhysicsUtils.applyForce(part, force, forcePosition)
	local parts = PhysicsUtils.getConnectedParts(part)

	forcePosition = forcePosition or part.Position

	local centerOfMass, mass = PhysicsUtils.getCenterOfMass(parts)
	local offset = (centerOfMass - forcePosition)
	local torque = offset:Cross(force)

	local momentOfInertia = PhysicsUtils.bodyMomentOfInertia(parts, torque, centerOfMass)
	local rotAcceleration
	if momentOfInertia ~= 0 then
		rotAcceleration = torque/momentOfInertia
	else
		rotAcceleration = Vector3.new(0, 0, 0) -- We cannot divide by 0
	end

	local acceleration = force/mass

	part.RotVelocity = part.RotVelocity + rotAcceleration
	part.Velocity = part.Velocity + acceleration
end

--- Accelerates a part utilizing newton's laws. emittingPart is the part it's emitted from.
-- force = mass * acceleration
function PhysicsUtils.acceleratePart(part, emittingPart, acceleration)
	local force = acceleration * part:GetMass()
	local position = part.Position

	PhysicsUtils.applyForce(part, force, position)
	PhysicsUtils.applyForce(emittingPart, -force, position)
end

return PhysicsUtils