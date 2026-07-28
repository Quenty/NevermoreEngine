--!strict
--[=[
	Helper class for the [Remoting] object which allows more natural syntax
	to be used against the remoting API surface.

	@class RemotingMember
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local RemotingObservableServerRelay = require("RemotingObservableServerRelay")
local RemotingRealms = require("RemotingRealms")

local RemotingMember = {}
RemotingMember.ClassName = "RemotingMember"
RemotingMember.__index = RemotingMember

export type RemotingMember = typeof(setmetatable(
	{} :: {
		_remoting: any,
		_memberName: string,
		_remotingRealm: RemotingRealms.RemotingRealm,
	},
	{} :: typeof({ __index = RemotingMember })
))

--[=[
	Constructs a new RemotingMember

	@param remoting Remoting
	@param memberName string
	@param remotingRealm RemotingRealms
	@return RemotingMember
]=]
function RemotingMember.new(
	remoting: any,
	memberName: string,
	remotingRealm: RemotingRealms.RemotingRealm
): RemotingMember
	local self: RemotingMember = setmetatable({} :: any, RemotingMember)

	self._remoting = assert(remoting, "No remoting")
	self._memberName = assert(memberName, "No memberName")
	self._remotingRealm = assert(remotingRealm, "Bad remotingRealm")

	return self
end

--[=[
	Binds to the member.

	On the server this will create the remote function. On the client
	this will bind to the remote function once it's created.

	@param callback function
	@return MaidTask
]=]
function RemotingMember.Bind(self: RemotingMember, callback: (...any) -> ...any): Maid.Maid
	assert(type(callback) == "function", "Bad callback")

	return self._remoting:Bind(self._memberName, callback)
end

--[=[
	Binds an observable factory to the member.

	See [Remoting.BindObservable].

	@server
	@param factory (player: Player, ...any) -> Observable
	@return MaidTask
]=]
function RemotingMember.BindObservable(
	self: RemotingMember,
	factory: RemotingObservableServerRelay.ObservableFactory
): Maid.Maid
	assert(type(factory) == "function", "Bad factory")
	assert(self._remotingRealm == RemotingRealms.SERVER, "BindObservable must be called on server")

	return self._remoting:BindObservable(self._memberName, factory)
end

--[=[
	Observes the member bound on the server with [RemotingMember.BindObservable].

	```lua
	maid:GiveTask(remoting.Health:Observe(entityId):Subscribe(print))
	```

	See [Remoting.Observe].

	@client
	@param ... any
	@return Observable<...any>
]=]
function RemotingMember.Observe(self: RemotingMember, ...): Observable.Observable<...any>
	assert(self._remotingRealm == RemotingRealms.CLIENT, "Observe must be called on client")

	return self._remoting:Observe(self._memberName, ...)
end

--[=[
	Connects to the equivalent of a RemoteEvent for this member.

	On the server this will create the remote event. On the client
	this will connect to the remote event once it's created.

	See [Remoting.Connect] for additional details.

	@param callback function
	@return MaidTask
]=]
function RemotingMember.Connect(self: RemotingMember, callback: (...any) -> ())
	assert(type(callback) == "function", "Bad callback")

	return self._remoting:Connect(self._memberName, callback)
end

--[=[
	Forward declares an event on the remoting object
]=]
function RemotingMember.DeclareEvent(self: RemotingMember): ()
	return self._remoting:DeclareEvent(self._memberName)
end

--[=[
	Forward declares a method on the remoting object
]=]
function RemotingMember.DeclareMethod(self: RemotingMember): ()
	return self._remoting:DeclareMethod(self._memberName)
end

--[=[
	Fires the remote event on the server

	@client
	@param ... any
]=]
function RemotingMember.FireServer(self: RemotingMember, ...)
	assert(self._remotingRealm == RemotingRealms.CLIENT, "FireServer must be called on client")
	self._remoting:FireServer(self._memberName, ...)
end

--[=[
	Invokes the server from the client

	@client
	@param ... any
]=]
function RemotingMember.InvokeServer(self: RemotingMember, ...): Promise.Promise<...any>
	assert(self._remotingRealm == RemotingRealms.CLIENT, "InvokeServer must be called on client")

	return self._remoting:InvokeServer(self._memberName, ...)
end

--[=[
	Invokes the server from the client.

	@client
	@param ... any
]=]
function RemotingMember.PromiseInvokeServer(self: RemotingMember, ...): Promise.Promise<...any>
	assert(self._remotingRealm == RemotingRealms.CLIENT, "PromiseInvokeServer must be called on client")

	return self._remoting:PromiseInvokeServer(self._memberName, ...)
end

--[=[
	Fires the server from the client. Promise resolves once the event is sent.

	@client
	@param ... any
	@return Promise
]=]
function RemotingMember.PromiseFireServer(self: RemotingMember, ...): Promise.Promise<...any>
	assert(self._remotingRealm == RemotingRealms.CLIENT, "PromiseFireServer must be called on client")

	return self._remoting:PromiseFireServer(self._memberName, ...)
end

--[=[
	Invokes the client from the server.

	See [Remoting.PromiseInvokeClient].

	@server
	@param player Player
	@param ... any
	@return Promise<any>
]=]
function RemotingMember.PromiseInvokeClient(self: RemotingMember, player: Player, ...): Promise.Promise<...any>
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "PromiseInvokeClient must be called on server")

	return self._remoting:PromiseInvokeClient(self._memberName, player, ...)
end

--[=[
	Invokes the client from the server

	See [Remoting.InvokeClient].

	@server
	@param player Player
	@param ... any
	@return ... any
]=]
function RemotingMember.InvokeClient(self: RemotingMember, player: Player, ...): ...any
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "InvokeClient must be called on server")

	return self._remoting:InvokeClient(self._memberName, player, ...)
end

--[=[
	Fires all clients.

	See [Remoting.FireAllClients].

	@server
	@param ... any
]=]
function RemotingMember.FireAllClients(self: RemotingMember, ...)
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireAllClients must be called on server")

	self._remoting:FireAllClients(self._memberName, ...)
end

--[=[
	Fires all clients with the event except the excluded player. The excluded player may be nil to support
	NPC actions.

	@server
	@param excludePlayer Player | nil
	@param ... any
]=]
function RemotingMember.FireAllClientsExcept(self: RemotingMember, excludePlayer: Player, ...)
	assert(
		typeof(excludePlayer) == "Instance" and (excludePlayer:IsA("Player") or PlayerMock.isMock(excludePlayer))
			or excludePlayer == nil,
		"Bad excludePlayer"
	)
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireAllClientsExcept must be called on server")

	self._remoting:FireAllClientsExcept(self._memberName, excludePlayer, ...)
end

--[=[
	Fires the client with the data

	See [Remoting.FireClient].

	@server
	@param player Instance
	@param ... any
]=]
function RemotingMember.FireClient(self: RemotingMember, player: Player, ...)
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireClient must be called on server")
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	self._remoting:FireClient(self._memberName, player, ...)
end

return RemotingMember
