---
-- @module TouchingPartUtils
-- @author Quenty

local Workspace = game:GetService("Workspace")

local EMPTY_FUNCTION = function() end

local TouchingPartUtils = {}

function TouchingPartUtils.getAllTouchingParts(part)
	-- Use the connection hack to gather all touching parts!
	local conn = part.Touched:Connect(EMPTY_FUNCTION)
	local parts = part:GetTouchingParts()

	-- Disconnect connection before we continue
	conn:Disconnect()

	return parts
end

function TouchingPartUtils.getBoundingBoxParts(cframe, size)
	local dummyPart = Instance.new("Part")
	dummyPart.Name = "CollisionDetectionDummYpart"
	dummyPart.Size = size
	dummyPart.CFrame = cframe
	dummyPart.Anchored = false
	dummyPart.CanCollide = true
	dummyPart.Parent = Workspace

	local conn = dummyPart.Touched:Connect(EMPTY_FUNCTION)
	local parts = dummyPart:GetTouchingParts()

	conn:Disconnect()
	dummyPart:Destroy()

	return parts
end

return TouchingPartUtils