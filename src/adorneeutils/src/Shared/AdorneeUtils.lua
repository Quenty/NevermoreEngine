--!strict
--[=[
	Utilities involving an "Adornee" effectively, any Roblox instance. This is an extremely
	useful library to use as it lets you abstract applying effects to any Roblox instance
	instead of specifically switching for different Roblox types.

	@class AdorneeUtils
]=]

local AdorneeUtils = {}

--[=[
	Gets the center of the adornee
	@param adornee Instance
	@return Vector3?
]=]
function AdorneeUtils.getCenter(adornee: Instance): Vector3?
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	if adornee:IsA("BasePart") then
		return adornee.Position
	elseif adornee:IsA("Model") then
		return adornee:GetBoundingBox().Position
	elseif adornee:IsA("Attachment") then
		return adornee.WorldPosition
	elseif adornee:IsA("Humanoid") then
		local rootPart = adornee.RootPart
		if rootPart then
			return rootPart.Position
		else
			return nil
		end
	elseif adornee:IsA("Accessory") or adornee:IsA("Clothing") then
		local handle = adornee:FindFirstChildWhichIsA("BasePart")
		if handle then
			return handle.Position
		else
			return nil
		end
	elseif adornee:IsA("Tool") then
		local handle = adornee:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle.Position
		else
			return nil
		end
	else
		return nil
	end
end

--[=[
	Gets the bounding box of the adornee
	@param adornee Instance
	@return CFrame? -- Center of the bounding box
	@return Vector3? -- Size of the bounding box
]=]
function AdorneeUtils.getBoundingBox(adornee: Instance): (CFrame?, Vector3?)
	if adornee:IsA("Model") then
		return adornee:GetBoundingBox()
	elseif adornee:IsA("Attachment") then
		return adornee.WorldCFrame, Vector3.zero -- This is a point
	else
		return AdorneeUtils.getPartCFrame(adornee), AdorneeUtils.getAlignedSize(adornee)
	end
end

--[=[
	Returns whether a part is a part of an adornee
	@param adornee Instance
	@param part BasePart
	@return boolean
]=]
function AdorneeUtils.isPartOfAdornee(adornee: Instance, part: BasePart): boolean
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	if adornee:IsA("Humanoid") then
		if not adornee.Parent then
			return false
		end

		return part:IsDescendantOf(adornee.Parent)
	end

	return adornee == part or part:IsDescendantOf(adornee)
end

--[=[
	Retrieves all parts of an adornee
	@param adornee Instance
	@return { BasePart }
]=]
function AdorneeUtils.getParts(adornee: Instance): { BasePart }
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	local parts = {}
	if adornee:IsA("BasePart") then
		table.insert(parts, adornee)
	end

	local searchParent: Instance?
	if adornee:IsA("Humanoid") then
		searchParent = adornee.Parent
	else
		searchParent = adornee
	end

	if searchParent ~= nil then
		for _, part in searchParent:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end

	return parts
end

--[=[
	Retrieves a size aligned the adornee's CFrame
	@param adornee Instance
	@return Vector3?
]=]
function AdorneeUtils.getAlignedSize(adornee: Instance): Vector3?
	if adornee:IsA("Model") then
		return select(2, adornee:GetBoundingBox())
	elseif adornee:IsA("Humanoid") then
		local character = adornee.Parent
		if character and character:IsA("Model") then
			return select(2, character:GetBoundingBox())
		else
			return nil
		end
	else
		local part = AdorneeUtils.getPart(adornee)
		if part then
			return part.Size
		end
	end

	return nil
end

--[=[
	Retrieves this adornee's "part"'s CFrame.
	@param adornee Instance
	@return CFrame
]=]
function AdorneeUtils.getPartCFrame(adornee: Instance): CFrame?
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	local part = AdorneeUtils.getPart(adornee)
	if not part then
		return nil
	end

	return part.CFrame
end

--[=[
	Retrieves this adornee's "part"'s position.
	@param adornee Instance
	@return Position
]=]
function AdorneeUtils.getPartPosition(adornee: Instance): Vector3?
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	local part = AdorneeUtils.getPart(adornee)
	if not part then
		return nil
	end

	return part.Position
end

--[=[
	Retrieves this adornee's "part"'s Velocity.
	@param adornee Instance
	@return Vector3
]=]
function AdorneeUtils.getPartVelocity(adornee: Instance): Vector3?
	local part = AdorneeUtils.getPart(adornee)
	if not part then
		return nil
	end

	return part.AssemblyLinearVelocity
end

--[=[
	Retrieves this adornee's part
	@param adornee Instance
	@return BasePart
]=]
function AdorneeUtils.getPart(adornee: Instance): BasePart?
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	if adornee:IsA("BasePart") then
		return adornee
	elseif adornee:IsA("Model") then
		if adornee.PrimaryPart ~= nil then
			return adornee.PrimaryPart
		else
			local basePart: BasePart? = adornee:FindFirstChildWhichIsA("BasePart")
			return basePart
		end
	elseif adornee:IsA("Attachment") then
		return adornee:FindFirstAncestorWhichIsA("BasePart")
	elseif adornee:IsA("Humanoid") then
		return adornee.RootPart
	elseif adornee:IsA("Accessory") or adornee:IsA("Clothing") then
		return adornee:FindFirstChildWhichIsA("BasePart") :: BasePart
	elseif adornee:IsA("Tool") then
		local handle = adornee:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		else
			return nil
		end
	else
		return nil
	end
end

--[=[
	Retrieves this adornee's part on which to attach a rendering instance to
	@param adornee Instance
	@return Instance
]=]
function AdorneeUtils.getRenderAdornee(adornee: Instance): Instance?
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	if adornee:IsA("BasePart") then
		return adornee
	elseif adornee:IsA("Model") then
		return adornee
	elseif adornee:IsA("Attachment") then
		return adornee
	elseif adornee:IsA("Humanoid") then
		return adornee.Parent
	elseif adornee:IsA("Accessory") or adornee:IsA("Clothing") then
		local basePart = adornee:FindFirstChildWhichIsA("BasePart")
		return basePart
	elseif adornee:IsA("Tool") then
		local handle = adornee:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		else
			return nil
		end
	else
		return nil
	end
end

return AdorneeUtils
