--[=[
	Gets the full mechanism from parts. See [NoCollisionConstraintUtils].
	@class getMechanismParts
]=]

local Workspace = game:GetService("Workspace")

local IGNORE_CONSTRAINT_SET = {
	["LineForce"] = true;
	["VectorForce"] = true;
	["Torque"] = true;
}

--[=[
	Gets all parts in a mechanisms. A mechanism in Roblox is anything connected by joints,
	constraints, and are all owned by network ownership.

	:::info
	Calling this class can be quite expensive.
	:::

	```lua
	print(getMechanismParts({ workspace.Part })) --> "Part", "Blah"
	```
	See: https://devforum.roblox.com/t/getting-all-parts-in-a-mechanism-one-part-in-each-assembly/101344/4

	@function getMechanismParts
	@param originParts Instance | { BasePart }
	@return { BasePart }
	@within getMechanismParts
]=]
return function(originParts: Instance | { BasePart }): { BasePart }
	local startingTable
	if type(originParts) == "table" then
		assert(#originParts > 0, "Bad originParts")
		startingTable = originParts
	elseif typeof(originParts) == "Instance" then
		startingTable = { originParts }
	else
		error("Bad argument for originParts")
	end

	local result = {}
	local checked = {
		[Workspace.Terrain] = true;
	}

	for _, item in startingTable do
		if item:IsA("BasePart") then
			if not checked[item] then
				checked[item] = true
				table.insert(result, item)
			end
		elseif item:IsA("Model") then
			for _, child in item:GetDescendants() do
				if child:IsA("BasePart") then
					if not checked[child] then
						checked[child] = true
						table.insert(result, child)
					end
				end
			end
		elseif item:IsA("Accessory") or item:IsA("Clothing") then
			local handle = item:FindFirstChildWhichIsA("BasePart")
			if handle then
				if not checked[handle] then
					checked[handle] = true
					table.insert(result, handle)
				end
			else
				warn("[getFullAssembly] - No handle in accessory")
			end
		else
			error("Bad item type in starting table")
		end
	end

	local connectionChecked = {}

	local index = 1
	while result[index] do
		local part = result[index]
		for _, joint in part:GetJoints() do
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
			for _, connectedPart in part:GetConnectedParts(true) do
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
