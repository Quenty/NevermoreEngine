--- General joint utilities
-- @module Weld

local lib = {}

--- Weld's 2 parts together
-- @param Part0 The first part
-- @param Part1 The second part (Dependent part most of the time).
-- @param[opt="Weld"] jointType The type of joint.
-- @param[opt=Part0] parent Parent of the weld, Defaults to Part0 (so GC is better).
-- @return The weld created.
function lib.Weld(part0, part1, jointType, parent)
	local weld = Instance.new(jointType or "Weld")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = CFrame.new()
	weld.C1 = part1.CFrame:ToObjectSpace(part0.CFrame)
	weld.Parent = parent or part0

	return weld
end

---
-- @param Parts The Parts to weld. Should be anchored to prevent really horrible results.
-- @param MainPart The part to weld the model to (can be in the model).
-- @param[opt="Weld"] jointType The type of joint
function lib.WeldParts(parts, mainPart, jointType)
	for _, part in pairs(parts) do
		lib.Weld(mainPart, part, jointType, mainPart)
	end
end


return lib
