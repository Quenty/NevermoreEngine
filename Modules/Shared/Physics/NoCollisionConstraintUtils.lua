---
-- @module NoCollisionConstraintUtils
-- @author Quenty

local NoCollisionConstraintUtils = {}

function NoCollisionConstraintUtils.create(part0, part1)
	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Part0 = part0
	noCollision.Part1 = part1
	noCollision.Parent = part0

	return noCollision
end

function NoCollisionConstraintUtils.createBetweenPartsLists(parts0, parts1)
	local collisionConstraints = {}
	for _, part0 in pairs(parts0) do
		for _, part1 in pairs(parts1) do
			table.insert(collisionConstraints, NoCollisionConstraintUtils.create(part0, part1))
		end
	end
	return collisionConstraints
end

return NoCollisionConstraintUtils