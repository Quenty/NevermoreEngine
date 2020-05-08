---
-- @module WeldConstraintUtils
-- @author Quenty

local WeldConstraintUtils = {}

function WeldConstraintUtils.namedBetween(name, part0, part1, parent)
	assert(typeof(part0) == "Instance")
	assert(typeof(part1) == "Instance")

	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Name = name
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	weldConstraint.Parent = parent

	return weldConstraint
end

return WeldConstraintUtils