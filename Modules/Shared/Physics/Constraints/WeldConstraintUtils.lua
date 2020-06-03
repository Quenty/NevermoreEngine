---
-- @module WeldConstraintUtils
-- @author Quenty

local WeldConstraintUtils = {}

function WeldConstraintUtils.namedBetween(name, part0, part1, parent)
	assert(typeof(part0) == "Instance")
	assert(typeof(part1) == "Instance")

	-- Roblox weld constraints very buggy!
	-- https://devforum.roblox.com/t/weld-constraint-behaves-differently-on-server-compared-to-client/445036
	local weld = Instance.new("Weld")
	weld.Name = name
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = CFrame.new()
	weld.C1 = part1.CFrame:ToObjectSpace(part0.CFrame)
	weld.Parent = parent

	-- local weldConstraint = Instance.new("WeldConstraint")
	-- weldConstraint.Name = name
	-- weldConstraint.Part0 = part0
	-- weldConstraint.Part1 = part1
	-- weldConstraint.Parent = parent

	return weld
end

return WeldConstraintUtils