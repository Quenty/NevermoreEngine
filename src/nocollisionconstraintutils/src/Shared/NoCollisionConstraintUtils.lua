--[=[
	Utility functions to create and manipulate [NoCollisionConstraint] objects between Roblox parts.

	See [getMechanismParts].

	@class NoCollisionConstraintUtils
]=]

local require = require(script.Parent.loader).load(script)

local getMechanismParts = require("getMechanismParts")
local Maid = require("Maid")

local NoCollisionConstraintUtils = {}

--[=[
	Creates a new [NoCollisionConstraint] between the two parts.
	@param part0 BasePart
	@param part1 BasePart
	@return NoCollisionConstraint
]=]
function NoCollisionConstraintUtils.create(part0, part1)
	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Part0 = part0
	noCollision.Part1 = part1

	return noCollision
end

--[=[
	Creates [NoCollisionConstraint] objects between the two part lists, and adds them all to a [Maid]
	for cleanup.
	@param parts0 { BasePart }
	@param parts1 { BasePart }
	@return Maid
]=]
function NoCollisionConstraintUtils.tempNoCollision(parts0, parts1)
	local maid = Maid.new()

	for _, item in pairs(NoCollisionConstraintUtils.createBetweenPartsLists(parts0, parts1)) do
		maid:GiveTask(item)
	end

	return maid
end

--[=[
	Creates [NoCollisionConstraint] objects between the two part lists.

	@param parts0 { BasePart }
	@param parts1 { BasePart }
	@return { NoCollisionConstraint }
]=]
function NoCollisionConstraintUtils.createBetweenPartsLists(parts0, parts1)
	local collisionConstraints = {}
	for _, part0 in pairs(parts0) do
		for _, part1 in pairs(parts1) do
			table.insert(collisionConstraints, NoCollisionConstraintUtils.create(part0, part1))
		end
	end
	return collisionConstraints
end

--[=[
	Creates [NoCollisionConstraint] objects between the two mechanisms.

	@param adornee0 BasePart
	@param adornee1 BasePart
	@return { NoCollisionConstraint }
]=]
function NoCollisionConstraintUtils.createBetweenMechanisms(adornee0, adornee1)
	return NoCollisionConstraintUtils.createBetweenPartsLists(getMechanismParts(adornee0), getMechanismParts(adornee1))
end

return NoCollisionConstraintUtils