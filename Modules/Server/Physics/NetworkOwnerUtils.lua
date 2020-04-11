---
-- @module NetworkOwnerUtils
-- @author Quenty

local NetworkOwnerUtils = {}

function NetworkOwnerUtils.trySetNetworkOwner(part, player)
	local canSet, err = part:CanSetNetworkOwnership()
	if not canSet then
		warn("[NetworkOwnerUtils.trySetNetworkOwner] - Cannot set network ownership", err)
		return
	end

	part:SetNetworkOwner(player)
end

function NetworkOwnerUtils.getNetworkOwnerPlayer(part)
	assert(part)

	local ok, owner = NetworkOwnerUtils.tryToGetNetworkOwner(part)
	if not ok then
		return nil
	end

	return owner
end

function NetworkOwnerUtils.isNetworkOwner(part, player)
	assert(part)
	assert(player)

	local ok, owner = NetworkOwnerUtils.tryToGetNetworkOwner(part, player)
	if not ok then
		return false
	end

	return owner == player
end

function NetworkOwnerUtils.isServerNetworkOwner(part)
	local ok, owner = NetworkOwnerUtils.tryToGetNetworkOwner(part, part)
	if not ok then
		return false
	end

	return owner == nil
end

function NetworkOwnerUtils.tryToGetNetworkOwner(part)
	local finished = false
	local networkOwner = nil

	-- xpcall here
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