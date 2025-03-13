--!strict
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
	@param parent Instance?
	@return NoCollisionConstraint
]=]
function NoCollisionConstraintUtils.create(part0: BasePart, part1: BasePart, parent: Instance?): NoCollisionConstraint
	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Part0 = part0
	noCollision.Part1 = part1
	noCollision.Parent = parent

	return noCollision
end

--[=[
	Creates [NoCollisionConstraint] objects between the two part lists, and adds them all to a [Maid]
	for cleanup.

	@param parts0 { BasePart }
	@param parts1 { BasePart }
	@param parent Instance | boolean | nil
	@return Maid
]=]
function NoCollisionConstraintUtils.tempNoCollision(parts0: { BasePart }, parts1: { BasePart }, parent: Instance?)
	assert(typeof(parent) == "Instance" or type(parent) == "boolean" or type(parent) == "nil", "Bad parent")

	local maid = Maid.new()

	for _, item in NoCollisionConstraintUtils.createBetweenPartsLists(parts0, parts1, parent or true) do
		maid:GiveTask(item)
	end

	return maid
end

--[=[
	Creates [NoCollisionConstraint] objects between the two part lists.

	@param parts0 { BasePart }
	@param parts1 { BasePart }
	@param parent Instance | boolean | nil
	@return { NoCollisionConstraint }
]=]
function NoCollisionConstraintUtils.createBetweenPartsLists(
	parts0: { BasePart },
	parts1: { BasePart },
	parent: Instance | boolean | nil
): { NoCollisionConstraint }
	assert(type(parts0) == "table", "Bad parts0")
	assert(type(parts1) == "table", "Bad parts1")
	assert(typeof(parent) == "Instance" or type(parent) == "boolean" or type(parent) == "nil", "Bad parent")

	local collisionConstraints = {}

	if parent == false then
		parent = nil
	end

	if type(parent) == "boolean" then
		for _, part0 in parts0 do
			for _, part1 in parts1 do
				table.insert(collisionConstraints, NoCollisionConstraintUtils.create(part0, part1, part0))
			end
		end
	else
		for _, part0 in parts0 do
			for _, part1 in parts1 do
				table.insert(collisionConstraints, NoCollisionConstraintUtils.create(part0, part1, parent))
			end
		end
	end

	return collisionConstraints
end

--[=[
	Creates [NoCollisionConstraint] objects between the two mechanisms.

	@param adornee0 BasePart
	@param adornee1 BasePart
	@param parent Instance | boolean | nil
	@return { NoCollisionConstraint }
]=]
function NoCollisionConstraintUtils.createBetweenMechanisms(
	adornee0: BasePart,
	adornee1: BasePart,
	parent: Instance?
): { NoCollisionConstraint }
	return NoCollisionConstraintUtils.createBetweenPartsLists(
		getMechanismParts(adornee0),
		getMechanismParts(adornee1),
		parent
	)
end

return NoCollisionConstraintUtils
