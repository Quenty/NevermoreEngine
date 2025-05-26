--!strict
--[=[
	Provides utility functions to make it easy to work with network owners. This wraps this API
	because the API surface is actually quite bad.

	See also: [NetworkOwnerService]

	@class NetworkOwnerUtils
]=]

local NetworkOwnerUtils = {}

--[=[
	Tries to set the network owner. Otherwise warns about failure.

	@param part BasePart
	@param player Player?
]=]
function NetworkOwnerUtils.trySetNetworkOwner(part: BasePart, player: Player?): boolean
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local canSet, err = part:CanSetNetworkOwnership()
	if not canSet then
		warn("[NetworkOwnerUtils.trySetNetworkOwner] - Cannot set network ownership", err)
		return false, err
	end

	part:SetNetworkOwner(player)
	return true
end

--[=[
	Tries to get the network owner a part. If this can't be retrieved
	it defaults to nil, which is sort of like pretending to be a server.

	@param part BasePart
	@return Player?
]=]
function NetworkOwnerUtils.getNetworkOwnerPlayer(part: BasePart): Player?
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local ok, owner = NetworkOwnerUtils.tryToGetNetworkOwner(part)
	if not ok then
		return nil
	end

	return owner
end

--[=[
	Returns whether or not a player is a network owner. If it
	cannot be retrieved then it will return false.

	@param part BasePart
	@param player Player? -- nil for server
	@return boolean
]=]
function NetworkOwnerUtils.isNetworkOwner(part: BasePart, player: Player): boolean
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	local ok, owner = NetworkOwnerUtils.tryToGetNetworkOwner(part)
	if not ok then
		return false
	end

	return owner == player
end

--[=[
	Returns whether or not the server is the network owner. Returns
	false if it can't be retrieved.

	@param part BasePart
	@return boolean
]=]
function NetworkOwnerUtils.isServerNetworkOwner(part: BasePart): boolean
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local ok, owner = NetworkOwnerUtils.tryToGetNetworkOwner(part)
	if not ok then
		return false
	end

	return owner == nil
end

--[=[
	@param part BasePart
	@return boolean -- true if retrieved fine, false otherwise
	@return Player? -- player that is owner.
]=]
function NetworkOwnerUtils.tryToGetNetworkOwner(part: BasePart): (boolean, Player?)
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local finished = false
	local networkOwner = nil

	xpcall(function()
		networkOwner = part:GetNetworkOwner()
		finished = true
	end, function(err)
		warn(err)
	end)

	if not finished then
		return false, nil
	end

	return true, networkOwner
end

return NetworkOwnerUtils
