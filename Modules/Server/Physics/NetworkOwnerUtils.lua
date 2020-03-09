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

return NetworkOwnerUtils