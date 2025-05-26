--!strict
--[=[
	Utility to get touching parts on a Roblox part.
	This acts as a performance-friendly way to query
	Roblox's spatial tree.

	@class TouchingPartUtils
]=]

local Workspace = game:GetService("Workspace")

local EMPTY_FUNCTION = function() end

local TouchingPartUtils = {}

--[=[
	Gets all the touching parts to a base part

	@param part BasePart
	@return { BasePart }
]=]
function TouchingPartUtils.getAllTouchingParts(part: BasePart): { BasePart }
	-- Use the connection hack to gather all touching parts!
	local conn = part.Touched:Connect(EMPTY_FUNCTION)
	local parts: { BasePart } = part:GetTouchingParts() :: any

	-- Disconnect connection before we continue
	conn:Disconnect()

	return parts
end

--[=[
	Returns all parts that are touching the given part.
	@param cframe CFrame
	@param size Vector3
	@return { BasePart }
]=]
function TouchingPartUtils.getBoundingBoxParts(cframe: CFrame, size: Vector3): { BasePart }
	local dummyPart = Instance.new("Part")
	dummyPart.Name = "CollisionDetectionDummYpart"
	dummyPart.Size = size
	dummyPart.CFrame = cframe
	dummyPart.Anchored = false
	dummyPart.CanCollide = true
	dummyPart.Parent = Workspace

	local conn = dummyPart.Touched:Connect(EMPTY_FUNCTION)
	local parts: { BasePart } = dummyPart:GetTouchingParts() :: any

	conn:Disconnect()
	dummyPart:Destroy()

	return parts
end

return TouchingPartUtils
