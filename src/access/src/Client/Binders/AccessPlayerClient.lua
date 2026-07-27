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

local AccessCommandUtils = require("AccessCommandUtils")
local AccessPlayerBase = require("AccessPlayerBase")
local AccessPlayerInterface = require("AccessPlayerInterface")
local AccessPolicyService = require("AccessPolicyService")
local Binder = require("Binder")
local PlayerMock = require("PlayerMock")
local Players = game:GetService("Players")
local Remoting = require("Remoting")
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
	self:_answerDebugRequests()

	return self
end

--[[
	Answers the server when a console asks what this realm thinks. Local player only: a client can only
	speak for itself. Strictly a readout -- a client that could report its own access authoritatively
	could grant itself whatever it liked.
]]
function AccessPlayerClient._answerDebugRequests(self: AccessPlayerClient): ()
	local localPlayer = PlayerMock.getMockedLocalPlayer() or Players.LocalPlayer
	if localPlayer ~= self._obj then
		return
	end

	local accessPolicyService = self._serviceBag:GetService(AccessPolicyService)
	local remoting = self._maid:Add(Remoting.Client.new(self._obj :: Instance, "AccessPlayerDebug"))

	self._maid:GiveTask(remoting.GetClientAccessState:Bind(function()
		return AccessCommandUtils.collectPlayerState(self._accessDataService, accessPolicyService, self._obj :: any)
	end))
end

--[[
	Feeds what the server replicated into this realm's AccessDataService, so a local fact and a
	server-only one are answered through the same path. Runs for every player, not only the local one.
]]
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
