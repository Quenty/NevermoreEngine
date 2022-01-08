--[=[
	General joint utilities.

	:::warning
	This class is really old
	:::

	@class Joint
]=]

local Joint = {}

--[=[
	Welds 2 parts together.

	@param part0 BasePart -- The first part
	@param part1 BasePart -- The second part (Dependent part most of the time).
	@param jointType string? -- The type of joint.
	@param parent Instance? -- Parent of the weld, Defaults to Part0 (so GC is better).
	@return Weld -- The weld created.
]=]
function Joint.Weld(part0, part1, jointType, parent)
	local weld = Instance.new(jointType or "Weld")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = CFrame.new()
	weld.C1 = part1.CFrame:ToObjectSpace(part0.CFrame)
	weld.Parent = parent or part0

	return weld
end

--[=[
	Welds mulitple parts together.

	@param parts { BasePart } -- The Parts to weld. Should be anchored to prevent really horrible results.
	@param mainPart BasePart -- The part to weld the model to (can be in the model).
	@param jointType string? -- The type of joint
]=]
function Joint.WeldParts(parts, mainPart, jointType)
	for _, part in pairs(parts) do
		Joint.Weld(mainPart, part, jointType, mainPart)
	end
end


return Joint
