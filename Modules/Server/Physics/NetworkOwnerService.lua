--- Tracks a stack of owners so ownership isn't reverted or overwritten in delayed network owner set
-- @module NetworkOwnerService

local NetworkOwnerService = {}

local WEAK_METATABLE = { __mode = "kv" }

local SERVER_FLAG = "server"

function NetworkOwnerService:Init()
	self._partOwnerData = setmetatable({}, { __mode="k" })
end

function NetworkOwnerService:AddSetNetworkOwnerHandle(part, player)
	assert(self._partOwnerData, "Not initialized")
	assert(typeof(part) == "Instance" and part:IsA("BasePart"))
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil)

	if player == nil then
		player = SERVER_FLAG
	end

	-- wrap in table so we have unique value
	local data = {
		player = player;
	}

	self:_addOwnerData(part, data)
	self:_updateOwner(part)

	-- closure keeps a reference to part, so we can set _partOwnerData to __mode="k"
	return function()
		if not self:_removeOwner(part, data) then
			warn("[NetworkOwnerService] - Failed to remove owner data")
			return
		end

		self:_updateOwner(part)
	end
end

function NetworkOwnerService:_addOwnerData(part, data)
	local ownerDataStack = self._partOwnerData[part]
	if not ownerDataStack then
		ownerDataStack = setmetatable({}, WEAK_METATABLE)
		self._partOwnerData[part] = ownerDataStack
	end

	if #ownerDataStack > 5 then
		warn("[NetworkOwnerService] - Possibly a memory leak, lots of owners")
	end

	table.insert(ownerDataStack, data)
end

function NetworkOwnerService:_removeOwner(part, toRemove)
	local ownerDataStack = self._partOwnerData[part]
	if not ownerDataStack then
		warn("[NetworkOwnerService] - No data for part")
		return false
	end

	for index, item in pairs(ownerDataStack) do
		if item == toRemove then
			table.remove(ownerDataStack, index)

			if #ownerDataStack == 0 then
				self._partOwnerData[part] = nil
			end

			return true
		end
	end

	return false
end

function NetworkOwnerService:_updateOwner(part)
	local ownerDataStack = self._partOwnerData[part]
	if not ownerDataStack then
		self:_setNetworkOwnershipAuto(part)
		return
	end

	-- Prefer last set
	local player = ownerDataStack[#ownerDataStack].player
	if player == SERVER_FLAG then
		player = nil
	end

	self:_setNetworkOwner(part, player)
end

function NetworkOwnerService:_setNetworkOwner(part, player)
	local canSet, err = part:CanSetNetworkOwnership()
	if not canSet then
		warn("[NetworkOwnerService] - Cannot set network ownership:", err, part:GetFullName())
		return
	end

	part:SetNetworkOwner(player)
end

function NetworkOwnerService:_setNetworkOwnershipAuto(part)
	local canSet, err = part:CanSetNetworkOwnership()
	if not canSet then
		warn("[NetworkOwnerService] - Cannot set network ownership:", err, part:GetFullName())
		return
	end

	part:SetNetworkOwnershipAuto()
end

return NetworkOwnerService