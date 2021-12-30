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
	-- Calculate additional offset for teleportation
	local offset = rootPart.Size.Y/2 + humanoid.HipHeight
	rootPart.CFrame = rootPart.CFrame - rootPart.Position + position + Vector3.new(0, offset, 0)
end

return HumanoidTeleportUtils