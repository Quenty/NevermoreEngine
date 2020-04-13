---
-- @module NoCollisionConstraintUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local getMechanismParts = require("getMechanismParts")
local Maid = require("Maid")

local NoCollisionConstraintUtils = {}

function NoCollisionConstraintUtils.create(part0, part1)
	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Part0 = part0
	noCollision.Part1 = part1

	return noCollision
end

function NoCollisionConstraintUtils.tempNoCollision(parts0, parts1)
	local maid = Maid.new()

	for _, item in pairs(NoCollisionConstraintUtils.createBetweenPartsLists(parts0, parts1)) do
		maid:GiveTask(item)
	end

	return maid
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

function NoCollisionConstraintUtils.createBetweenMechanisms(adornee0, adornee1)
	return NoCollisionConstraintUtils.createBetweenPartsLists(getMechanismParts(adornee0), getMechanismParts(adornee1))
end

return NoCollisionConstraintUtils