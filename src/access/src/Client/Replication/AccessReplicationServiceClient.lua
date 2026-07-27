--!strict
--[=[
	Receives the server's fact answers and hands them to [AccessDataService], which combines each with
	whatever this realm worked out for itself, per the fact's [AccessFactServerOverrideBehavior].

	Receive-only. There is no path from here back to the server carrying an answer, because a client that
	could tell the server what a fact reads as could grant itself anything. The one outbound call asks for
	state; it never supplies any.

	## Registration-independent

	A replicated fact does not have to be registered on this realm, and usually cannot be -- the whole
	point is facts the client has no way to compute. A per-chapter entitlement is a receipt in a
	server-only DataStore, and there is nothing for a client resolver to read. So every value this is told
	about is kept whether or not a local fact of that name exists.

	## Asks once, then follows

	Connecting to the change event is not enough on its own. A client that connects after the server has
	already sent hears nothing until the next change, and for a fact that never changes again that is
	never -- the picker sits empty forever. This asks for the full state on start and applies changes on
	top of it.

	@client
	@class AccessReplicationServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessDataService = require("AccessDataService")
local AccessReplicationStateUtils = require("AccessReplicationStateUtils")
local Maid = require("Maid")
local ObservableMap = require("ObservableMap")
local PlayerMock = require("PlayerMock")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")

-- Matches [AccessReplicationService]. A mismatch shows up as the client hearing nothing at all.
local REMOTING_NAME = "AccessFactReplication"

local AccessReplicationServiceClient = {}
AccessReplicationServiceClient.ServiceName = "AccessReplicationServiceClient"

export type AccessReplicationServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_accessDataService: any,
		_remoting: any,
		_values: any,
	},
	{} :: typeof({ __index = AccessReplicationServiceClient })
))

function AccessReplicationServiceClient.Init(
	self: AccessReplicationServiceClient,
	serviceBag: ServiceBag.ServiceBag
): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._accessDataService = self._serviceBag:GetService(AccessDataService)
	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, REMOTING_NAME))

	-- Held here as well as pushed into the data service, so what this realm was told is inspectable on
	-- its own -- including for facts that exist nowhere else on this realm.
	self._values = self._maid:Add(ObservableMap.new())
end

function AccessReplicationServiceClient.Start(self: AccessReplicationServiceClient): ()
	self._maid:GiveTask(
		self._remoting.SetFactValue:Connect(function(factName: string, value: boolean?, abstained: boolean?)
			self:_apply(factName, value, abstained)
		end)
	)

	-- After connecting, never before: anything that changes while the request is in flight arrives as a
	-- change rather than falling between the snapshot and the subscription.
	self._maid:GivePromise(self._remoting.GetFactValues:PromiseInvokeServer()):Then(function(values: any)
		for factName, box in values or {} do
			self:_apply(factName, box.value, box.abstained)
		end
	end)
end

--[=[
	Every fact this realm has been told about, live, each carrying its [AccessReplicationState]. A fact
	absent from this map is `NOT_YET_ARRIVED`, which is the state that must never be mistaken for a
	denial.

	@return ObservableMap<string, { value: boolean?, state: string }>
]=]
function AccessReplicationServiceClient.GetValues(self: AccessReplicationServiceClient): any
	return self._values
end

function AccessReplicationServiceClient._apply(
	self: AccessReplicationServiceClient,
	factName: string,
	value: boolean?,
	abstained: boolean?
): ()
	-- Mock-safe, the same way every other client service resolves this: a headless test has no real
	-- LocalPlayer, and a client service that only works with one cannot be tested at all.
	local player = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if not player then
		return
	end

	self._values:Set(factName, {
		value = value,
		state = AccessReplicationStateUtils.fromEntry({ value = value, abstained = abstained }),
	})
	self._accessDataService:SetServerFactValue(player, factName, value)
end

function AccessReplicationServiceClient.Destroy(self: AccessReplicationServiceClient): ()
	self._maid:DoCleaning()
end

return AccessReplicationServiceClient
