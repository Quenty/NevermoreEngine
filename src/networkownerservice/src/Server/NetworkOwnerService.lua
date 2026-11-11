--!strict
--[=[
	Tracks a stack of owners so ownership isn't reverted or overwritten in delayed network owner set. Deduplicates network
	ownership handles.

	## Setup
	```lua
	-- Server.lua

	local serviceBag = require("ServiceBag")
	serviceBag:GetService(require("NetworkOwnerService"))

	serviceBag:Init()
	serviceBag:Start()
	```

	## Usage
	```lua
	local networkOwnerService = serviceBag:GetService(NetworkOwnerService)

	-- Force this part to be owned by the server
	local handle = networkOwnerService:AddSetNetworkOwnerHandle(workspace.Part, nil)

	delay(2.5, function()
		-- oh no, another function wants to set the network owner, guess we'll be owned by Quenty for a while
		local handle = networkOwnerService:AddSetNetworkOwnerHandle(workspace.Part, Players.Quenty)

		delay(1, function()
			-- stop using quenty, guess we're back to the server now
			handle()
		end)
	end)

	delay(5, function()
		handle() -- stop forcing network ownership to be the server, now we're back to nil
	end)
	```

	@class NetworkOwnerService
]=]

local NetworkOwnerService = {}
NetworkOwnerService.ServiceName = "NetworkOwnerService"

local WEAK_METATABLE = { __mode = "kv" }

local SERVER_FLAG = "server"

type OwnerData = {
	player: Player | string,
}

export type NetworkOwnerService = typeof(setmetatable(
	{} :: {
		_partOwnerData: { [BasePart]: { OwnerData } },
	},
	{} :: typeof({ __index = NetworkOwnerService })
))

--[=[
	Initializes the NetworkOwnerService. Should be done via [ServiceBag].
]=]
function NetworkOwnerService.Init(self: NetworkOwnerService): ()
	assert(not (self :: any)._partOwnerData, "Already initialized")

	self._partOwnerData = setmetatable({}, { __mode = "k" }) :: any
end

--[=[
	Tries to set the network owner handle to the given player.
	@param part BasePart
	@param player Player?
	@return function -- Cleanup function
]=]
function NetworkOwnerService.AddSetNetworkOwnerHandle(
	self: NetworkOwnerService,
	part: BasePart,
	player: Player?
): () -> ()
	assert((self :: any) ~= NetworkOwnerService, "Make sure to retrieve NetworkOwnerService from a ServiceBag")
	assert(self._partOwnerData, "Not initialized")
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")

	-- wrap in table so we have unique value
	local data: OwnerData = {
		player = player or SERVER_FLAG,
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

function NetworkOwnerService._addOwnerData(self: NetworkOwnerService, part: BasePart, data: OwnerData): ()
	local ownerDataStack = self._partOwnerData[part]
	if not ownerDataStack then
		ownerDataStack = setmetatable({}, WEAK_METATABLE) :: any
		self._partOwnerData[part] = ownerDataStack
	end

	if #ownerDataStack > 5 then
		warn("[NetworkOwnerService] - Possibly a memory leak, lots of owners")
	end

	table.insert(ownerDataStack, data)
end

function NetworkOwnerService._removeOwner(self: NetworkOwnerService, part: BasePart, toRemove: OwnerData): boolean
	local ownerDataStack = self._partOwnerData[part]
	if not ownerDataStack then
		warn("[NetworkOwnerService] - No data for part")
		return false
	end

	for index, item in ownerDataStack do
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

function NetworkOwnerService._updateOwner(self: NetworkOwnerService, part: BasePart): ()
	local ownerDataStack = self._partOwnerData[part]
	if not ownerDataStack then
		self:_setNetworkOwnershipAuto(part)
		return
	end

	-- Prefer last set
	local owner = ownerDataStack[#ownerDataStack].player
	local player: Player?
	if owner ~= SERVER_FLAG then
		player = owner :: Player
	end

	self:_setNetworkOwner(part, player)
end

function NetworkOwnerService._setNetworkOwner(_self: NetworkOwnerService, part: BasePart, player: Player?): ()
	local canSet, err = part:CanSetNetworkOwnership()
	if not canSet then
		warn("[NetworkOwnerService] - Cannot set network ownership:", err, part:GetFullName())
		return
	end

	part:SetNetworkOwner(player)
end

function NetworkOwnerService._setNetworkOwnershipAuto(_self: NetworkOwnerService, part: BasePart): ()
	local canSet, err = part:CanSetNetworkOwnership()
	if not canSet then
		warn("[NetworkOwnerService] - Cannot set network ownership:", err, part:GetFullName())
		return
	end

	part:SetNetworkOwnershipAuto()
end

return NetworkOwnerService
