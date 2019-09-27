--- Gets the full assembly of a part
-- @module getFullAssembly
-- https://devforum.roblox.com/t/getting-all-parts-in-a-mechanism-one-part-in-each-assembly/101344/4

local Workspace = game:GetService("Workspace")

local IGNORE_CONSTRAINT_SET = {
	["LineForce"] = true;
	["VectorForce"] = true;
	["Torque"] = true;
}

return function(originPart)
	local result = { originPart }
	local checked = {
		[originPart] = true;
		[Workspace.Terrain] = true;
	}
	local connectionChecked = {}

	local index = 1
	while result[index] do
		local part = result[index]
		for _, joint in pairs(part:GetJoints()) do
			local part0
			local part1
			if joint:IsA("Constraint") then
				if not IGNORE_CONSTRAINT_SET[joint.ClassName] then
					part0 = joint.Attachment0.Parent
					part1 = joint.Attachment1.Parent
				end
			else
				part0 = joint.Part0
				part1 = joint.Part1
			end

			if part0 and not checked[part0] then
				checked[part0] = true
				result[#result + 1] = part0
			end

			if part1 and not checked[part1] then
				checked[part1] = true
				result[#result + 1] = part1
			end
		end

		-- Validate assembly
		if not connectionChecked[part] then
			connectionChecked[part] = true
			for _, connectedPart in pairs(part:GetConnectedParts(true)) do
				if not checked[connectedPart] then
					checked[connectedPart] = true
					connectionChecked[connectedPart] = true
					result[#result + 1] = connectedPart
				end
			end
		end

		index = index + 1
	end

	return result
end
