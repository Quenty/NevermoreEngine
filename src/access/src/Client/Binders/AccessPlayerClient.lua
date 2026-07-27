--!strict
--[=[
	The client half of [AccessPlayerBase]. It reads what the server replicated onto the player instance
	and feeds it into this realm's [AccessDataService], so a fact this realm can resolve and one only the
	server can are answered through the same path.

	Bound to every player, so this realm can answer questions about anybody -- a party UI can show which
	teammate is missing a chapter without asking them.

	@client
	@class AccessPlayerClient
]=]

local require = require(script.Parent.loader).load(script)

local AccessPlayerBase = require("AccessPlayerBase")
local AccessPlayerInterface = require("AccessPlayerInterface")
local Binder = require("Binder")
local ServiceBag = require("ServiceBag")

local AccessPlayerClient = setmetatable({}, AccessPlayerBase)
AccessPlayerClient.ClassName = "AccessPlayerClient"
AccessPlayerClient.__index = AccessPlayerClient

export type AccessPlayerClient =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = AccessPlayerClient })))
	& AccessPlayerBase.AccessPlayerBase

function AccessPlayerClient.new(player: Player, serviceBag: ServiceBag.ServiceBag): AccessPlayerClient
	local self: AccessPlayerClient = setmetatable(AccessPlayerBase.new(player, serviceBag) :: any, AccessPlayerClient)

	self._maid:GiveTask((AccessPlayerInterface :: any).Client:Implement(self._obj :: Instance, self))

	self:_consumeReplicatedFacts()

	return self
end

-- Feeds what the server replicated into this realm's AccessDataService, so a locally-registered fact and
-- a server-only one are answered through exactly the same path.
--
-- Runs for every player, not only the local one: the attribute is on the player instance, so this realm
-- can answer questions about anybody.
function AccessPlayerClient._consumeReplicatedFacts(self: AccessPlayerClient): ()
	self._maid:GiveTask(self._replicatedFacts:Observe():Subscribe(function(entries: any)
		for factName, entry in entries or {} do
			self._accessDataService:SetServerFactValue(
				self._obj,
				factName,
				entry.value,
				entry.abstained,
				entry.metadata
			)
		end
	end))
end

return Binder.new("AccessPlayer", AccessPlayerClient :: any) :: Binder.Binder<AccessPlayerClient>
