--!strict
--[=[
	Helper class for the [Remoting] object which allows more natural syntax
	to be used against the remoting API surface.

	@class RemotingMember
]=]

local require = require(script.Parent.loader).load(script)

local RemotingRealms = require("RemotingRealms")

local RemotingMember = {}
RemotingMember.ClassName = "RemotingMember"
RemotingMember.__index = RemotingMember

export type RemotingMember = typeof(setmetatable({}, RemotingMember))

--[=[
	Constructs a new RemotingMember

	@param remoting Remoting
	@param memberName string
	@param remotingRealm RemotingRealms
	@return RemotingMember
]=]
function RemotingMember.new(remoting, memberName: string, remotingRealm: RemotingRealms.RemotingRealm): RemotingMember
	local self = setmetatable({}, RemotingMember)

	self._remoting = assert(remoting, "No remoting")
	self._memberName = assert(memberName, "No memberName")
	self._remotingRealm = assert(remotingRealm, "Bad remotingRealm")

	return self
end

--[=[
	Binds to the member.

	On the server this will create the remote function. On the client
	this will connect to the remote event once it's created.

	@param callback function
	@return MaidTask
]=]
function RemotingMember:Bind(callback: (...any) -> ...any)
	assert(type(callback) == "function", "Bad callback")

	return self._remoting:Bind(self._memberName, callback)
end

--[=[
	Connects to the equivalent of a RemoteEvent for this member.

	On the server this will create the remote event. On the client
	this will connect to the remote event once it's created.

	See [Remoting.Connect] for additional details.

	@param callback function
	@return MaidTask
]=]
function RemotingMember:Connect(callback: (...any) -> ())
	assert(type(callback) == "function", "Bad callback")

	return self._remoting:Connect(self._memberName, callback)
end

--[=[
	Forward declares an event on the remoting object
]=]
function RemotingMember:DeclareEvent()
	return self._remoting:DeclareEvent(self._memberName)
end

--[=[
	Forward declares a method on the remoting object
]=]
function RemotingMember:DeclareMethod()
	return self._remoting:DeclareMethod(self._memberName)
end

--[=[
	Fires the remote event on the server

	@client
	@param ... any
]=]
function RemotingMember:FireServer(...)
	assert(self._remotingRealm == RemotingRealms.CLIENT, "FireServer must be called on client")
	self._remoting:FireServer(self._memberName, ...)
end

--[=[
	Invokes the server from the client

	@client
	@param ... any
]=]
function RemotingMember:InvokeServer(...)
	assert(self._remotingRealm == RemotingRealms.CLIENT, "InvokeServer must be called on client")

	return self._remoting:InvokeServer(self._memberName, ...)
end

--[=[
	Invokes the client from the server.

	@client
	@param ... any
]=]
function RemotingMember:PromiseInvokeServer(...)
	assert(self._remotingRealm == RemotingRealms.CLIENT, "PromiseInvokeServer must be called on client")

	return self._remoting:PromiseInvokeServer(self._memberName, ...)
end

--[=[
	Fires the server from the client. Promise resolves once the event is sent.

	@client
	@param ... any
	@return Promise
]=]
function RemotingMember:PromiseFireServer(...)
	assert(self._remotingRealm == RemotingRealms.CLIENT, "PromiseInvokeServer must be called on client")

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
function RemotingMember:PromiseInvokeClient(player: Player, ...)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "PromiseInvokeClient must be called on client")

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
function RemotingMember:InvokeClient(player, ...)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "InvokeClient must be called on client")

	return self._remoting:InvokeClient(self._memberName, player, ...)
end

--[=[
	Fires all clients.

	See [Remoting.FireAllClients].

	@server
	@param ... any
]=]
function RemotingMember:FireAllClients(...)
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireAllClients must be called on client")

	self._remoting:FireAllClients(self._memberName, ...)
end

--[=[
	Fires all clients with the event except the excluded player. The excluded player may be nil to support
	NPC actions.

	@server
	@param excludePlayer Player | nil
	@param ... any
]=]
function RemotingMember:FireAllClientsExcept(excludePlayer: Player, ...)
	assert(
		typeof(excludePlayer) == "Instance" and excludePlayer:IsA("Player") or excludePlayer == nil,
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
function RemotingMember:FireClient(player: Player, ...)
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireClient must be called on client")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	self._remoting:FireClient(self._memberName, player, ...)
end

return RemotingMember