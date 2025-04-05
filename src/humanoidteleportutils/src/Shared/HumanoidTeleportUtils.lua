--[=[
	Utility for teleporting humanoids
	@class HumanoidTeleportUtils
]=]

local require = require(script.Parent.loader).load(script)

local Raycaster = require("Raycaster")

local HumanoidTeleportUtils = {}

local REQUIRED_SPACE = 7
local SEARCH_UP_TO = 40

--[=[
	Finds a safe position to teleport a humanoid. This searches some amount
	around the position to try to ensure a free space for the humanoid.

	@param position Position
	@param raycaster Raycaster? -- Optional raycaster
	@return boolean -- True if safe
	@return Vector3? -- Position if we can hit it
]=]
function HumanoidTeleportUtils.identifySafePosition(position, raycaster)
	assert(typeof(position) == "Vector3", "Bad position")

	if not raycaster then
		raycaster = Raycaster.new()
		raycaster.MaxCasts = 10
		raycaster.Filter = function(hitData)
			return not hitData.Part.CanCollide
		end
	end

	for i=1, SEARCH_UP_TO, 2 do
		local origin = position + Vector3.new(0, i, 0)
		local direction = Vector3.new(0, REQUIRED_SPACE, 0)
		local hitData = raycaster:FindPartOnRay(Ray.new(origin, direction))

		if not hitData then
			local secondHit = raycaster:FindPartOnRay(Ray.new(origin+direction - Vector3.new(0, 1, 0), -direction))

			-- try to identify flat surface
			if secondHit then
				return true, secondHit.Position
			end

			return true, origin
		end
	end

	return false, position + Vector3.new(0, SEARCH_UP_TO, 0)
end

--[=[
	Teleports a humanoid to a given location.

	:::info
	You should call this on the machine that has network ownership. For characters
	owned by a player, this is generally the player who's character it is.

	For NPCs, this should generally be the server.
	:::

	@param humanoid Humanoid
	@param rootPart BasePart
	@param position Vector3
]=]
function HumanoidTeleportUtils.teleportRootPart(humanoid, rootPart, position)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")
	assert(typeof(rootPart) == "Instance" and rootPart:IsA("BasePart"), "Bad rootPart")
	assert(typeof(position) == "Vector3", "Bad position")

	local offset = HumanoidTeleportUtils.getRootPartOffset(humanoid, rootPart)
	rootPart.CFrame = rootPart.CFrame - rootPart.Position + position + offset
end

--[=[
	Teleports a humanoid to a given location including all attached parts

	@param humanoid Humanoid
	@param rootPart BasePart
	@param parts { BasePart }
	@param position Vector3
]=]
function HumanoidTeleportUtils.teleportParts(humanoid, rootPart, parts, position)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")
	assert(typeof(rootPart) == "Instance" and rootPart:IsA("BasePart"), "Bad rootPart")
	assert(type(parts) == "table", "Bad parts")
	assert(typeof(position) == "Vector3", "Bad position")

	local offset = HumanoidTeleportUtils.getRootPartOffset(humanoid, rootPart)
	local rootPartCFrame = rootPart.CFrame
	local newRootPartCFrame = rootPartCFrame - rootPartCFrame.Position + position + offset

	local relCFrame = {}
	for _, part in parts do
		relCFrame[part] = rootPartCFrame:toObjectSpace(part.CFrame)
	end

	relCFrame[rootPart] = nil

	for part, relative in relCFrame do
		part.CFrame = newRootPartCFrame:toWorldSpace(relative)
	end

	rootPart.CFrame = newRootPartCFrame
end

--[=[
	Tries to teleport the character to a given position

	@param character Model
	@param position Vector3
]=]
function HumanoidTeleportUtils.tryTeleportCharacter(character, position)
	assert(typeof(character) == "Instance", "Bad character")
	assert(typeof(position) == "Vector3", "Bad position")

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return false
	end

	local rootPart = humanoid.RootPart
	if not rootPart then
		return false
	end

	HumanoidTeleportUtils.teleportRootPart(humanoid, rootPart, position)
	return true
end

function HumanoidTeleportUtils.getRootPartOffset(humanoid, rootPart)
	-- Calculate additional offset for teleportation
	return Vector3.new(0, rootPart.Size.Y/2 + humanoid.HipHeight, 0)
end

return HumanoidTeleportUtils