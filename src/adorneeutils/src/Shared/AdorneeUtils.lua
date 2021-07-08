---
-- @module AdorneeUtils
-- @author Quenty

local AdorneeUtils = {}

function AdorneeUtils.getCenter(adornee)
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	if adornee:IsA("BasePart") then
		return adornee.Position
	elseif adornee:IsA("Model") then
		return adornee:GetBoundingBox().p
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

function AdorneeUtils.getBoundingBox(adornee)
	if adornee:IsA("Model") then
		return adornee:GetBoundingBox()
	else
		return AdorneeUtils.getPartCFrame(adornee), AdorneeUtils.getAlignedSize(adornee)
	end
end

function AdorneeUtils.isPartOfAdornee(adornee, part)
	assert(part:IsA("BasePart"))

	if adornee:IsA("Humanoid") then
		if not adornee.Parent then
			return false
		end

		return part:IsDescendantOf(adornee.Parent)
	end

	return adornee == part or part:IsDescendantOf(adornee)
end

function AdorneeUtils.getParts(adornee)
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	local parts = {}
	if adornee:IsA("BasePart") then
		table.insert(parts, adornee)
	end

	local searchParent
	if adornee:IsA("Humanoid") then
		searchParent = adornee.Parent
	else
		searchParent = adornee
	end

	if searchParent then
		for _, part in pairs(searchParent:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end

	return parts
end

function AdorneeUtils.getAlignedSize(adornee)
	if adornee:IsA("Model") then
		return select(2, adornee:GetBoundingBox())
	elseif adornee:IsA("Humanoid") then
		if adornee.Parent then
			return select(2, adornee.Parent:GetBoundingBox())
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

function AdorneeUtils.getPartCFrame(adornee)
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	local part = AdorneeUtils.getPart(adornee)
	if not part then
		return nil
	end

	return part.CFrame
end

function AdorneeUtils.getPartPosition(adornee)
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	local part = AdorneeUtils.getPart(adornee)
	if not part then
		return nil
	end

	return part.Position
end

function AdorneeUtils.getPartVelocity(adornee)
	local part = AdorneeUtils.getPart(adornee)
	if not part then
		return nil
	end

	return part.Velocity
end

function AdorneeUtils.getPart(adornee)
	assert(typeof(adornee) == "Instance", "Adornee must by of type 'Instance'")

	if adornee:IsA("BasePart") then
		return adornee
	elseif adornee:IsA("Model") then
		if adornee.PrimaryPart then
			return adornee.PrimaryPart
		else
			return adornee:FindFirstChildWhichIsA("BasePart")
		end
	elseif adornee:IsA("Attachment") then
		return adornee.Parent
	elseif adornee:IsA("Humanoid") then
		return adornee.RootPart
	elseif adornee:IsA("Accessory") or adornee:IsA("Clothing") then
		return adornee:FindFirstChildWhichIsA("BasePart")
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

function AdorneeUtils.getRenderAdornee(adornee)
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
		return adornee:FindFirstChildWhichIsA("BasePart")
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