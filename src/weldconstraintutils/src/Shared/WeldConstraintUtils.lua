--!strict
--[=[
	Utility functions to create WeldConstraint objects in Roblox.
	@class WeldConstraintUtils
]=]

local WeldConstraintUtils = {}

--[=[
	Creates a new weld constraint between the given parts.

	:::info
	Actually generally defaults to a weld because the weld constraint system is buggy.
	https://devforum.roblox.com/t/weld-constraint-behaves-differently-on-server-compared-to-client/445036
	:::

	:::info
	We tend to create a weld constraint between parts and terrain, because terrain will remove welds when it
	deforms for non-touching parts.

	https://devforum.roblox.com/t/allow-way-to-prevent-terrain-after-deforming-from-removing-welds/631061
	:::

	@param name string
	@param part0 BasePart
	@param part1 BasePart
	@param parent Instance? -- Optional
	@return Weld | WeldConstraint
]=]
function WeldConstraintUtils.namedBetween(
	name: string,
	part0: BasePart,
	part1: BasePart,
	parent: Instance
): Weld | WeldConstraint
	assert(type(name) == "string", "Bad name")
	assert(typeof(part0) == "Instance", "Bad part0")
	assert(typeof(part1) == "Instance", "Bad part1")

	if part0:IsA("Terrain") or part1:IsA("Terrain") then
		-- Terrain likes to remove welds when it deforms for non-touching parts
		-- Weld constraints do not get affected by this
		-- https://devforum.roblox.com/t/allow-way-to-prevent-terrain-after-deforming-from-removing-welds/631061
		return WeldConstraintUtils.namedBetweenForceWeldConstraint(name, part0, part1, parent)
	end

	-- Roblox weld constraints very buggy!
	-- https://devforum.roblox.com/t/weld-constraint-behaves-differently-on-server-compared-to-client/445036
	local weld = Instance.new("Weld")
	weld.Name = name
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = CFrame.new()
	weld.C1 = part1.CFrame:ToObjectSpace(part0.CFrame)
	weld.Parent = parent

	return weld
end

--[=[
	Creates a new weld constraint between the given parts guaranteed.

	:::info
	This may not always work in ways you want, because Roblox is complicated. When in doubt, it is
	recommend you use [WeldConstraintUtils.namedBetween] for all welding scenarios.
	:::

	@param name string
	@param part0 BasePart
	@param part1 BasePart
	@param parent Instance? -- Optional
	@return WeldConstraint
]=]
function WeldConstraintUtils.namedBetweenForceWeldConstraint(
	name: string,
	part0: BasePart,
	part1: BasePart,
	parent: Instance?
): WeldConstraint
	assert(type(name) == "string", "Bad name")
	assert(typeof(part0) == "Instance", "Bad part0")
	assert(typeof(part1) == "Instance", "Bad part1")

	-- Roblox weld constraints very buggy!
	-- https://devforum.roblox.com/t/weld-constraint-behaves-differently-on-server-compared-to-client/445036
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Name = name
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	weldConstraint.Parent = parent

	return weldConstraint
end

return WeldConstraintUtils
