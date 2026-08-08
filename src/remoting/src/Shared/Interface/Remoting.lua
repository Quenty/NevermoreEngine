--!strict
--[=[
	Offers a thin wrapper around Roblox remoting instances and events. Designed to reduce
	the amount of code needed to construct a large set of RemoteFunction/RemoteEvent instances.

	@class Remoting
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local RemoteFunctionUtils = require("RemoteFunctionUtils")
local RemotingMember = require("RemotingMember")
local RemotingObservableClientRelay = require("RemotingObservableClientRelay")
local RemotingObservableServerRelay = require("RemotingObservableServerRelay")
local RemotingRealmUtils = require("RemotingRealmUtils")
local RemotingRealms = require("RemotingRealms")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local promiseChild = require("promiseChild")

local RAW_MEMBERS = {
	_name = true,
	_maid = true,
	_instance = true,
	_remoteObjects = true,
	_container = true,
	_defaultRemotingRealm = true,
}

local REMOTE_EVENT_SUFFIX = "Event"
local REMOTE_FUNCTION_SUFFIX = "Function"

local Remoting = {}
Remoting.ClassName = "Remoting"
Remoting.__index = Remoting

Remoting.Realms = RemotingRealms

Remoting.Server = {
	new = function(instance: Instance, name: string)
		return Remoting.new(instance, name, RemotingRealms.SERVER)
	end,
}

Remoting.Client = {
	new = function(instance: Instance, name: string)
		return Remoting.new(instance, name, RemotingRealms.CLIENT)
	end,
}

export type Remoting = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_instance: Instance,
		_name: string,
		_remoteObjects: { [string]: RemoteEvent | BindableEvent | RemoteFunction },
		_container: Folder?,
		_remotingRealm: RemotingRealms.RemotingRealm,
		_useDummyObject: boolean,
		_remoteFolderName: string,
		_observableRelays: { [string]: any },
		_boundMemberKinds: { [string]: string },

		-- Public methods
		DeclareEvent: (self: Remoting, memberName: string) -> (),
		DeclareMethod: (self: Remoting, memberName: string) -> (),
		Connect: (self: Remoting, memberName: string, callback: (...any) -> ()) -> Maid.Maid,
		Bind: (self: Remoting, memberName: string, callback: (...any) -> ()) -> Maid.Maid,
		BindObservable: (
			self: Remoting,
			memberName: string,
			factory: RemotingObservableServerRelay.ObservableFactory
		) -> Maid.Maid,
		Observe: (self: Remoting, memberName: string, ...any) -> Observable.Observable<...any>,
		FireClient: (self: Remoting, memberName: string, player: Player, ...any) -> (),
		FireAllClients: (self: Remoting, memberName: string, ...any) -> (),
		FireAllClientsExcept: (self: Remoting, memberName: string, excludePlayer: Player, ...any) -> (),
		FireServer: (self: Remoting, memberName: string, ...any) -> (),
		PromiseFireServer: (self: Remoting, memberName: string, ...any) -> Promise.Promise<()>,
		PromiseInvokeServer: (self: Remoting, memberName: string, ...any) -> Promise.Promise<...any>,
		InvokeServer: (self: Remoting, memberName: string, ...any) -> ...any,
		InvokeClient: (self: Remoting, memberName: string, player: Player, ...any) -> ...any,
		PromiseInvokeClient: (self: Remoting, memberName: string, player: Player, ...any) -> Promise.Promise<...any>,
		GetContainerClass: (self: Remoting) -> string,
		Destroy: (self: Remoting) -> (),

		-- Private methods
		_getDummyMemberName: (self: Remoting, memberName: string, suffix: string) -> string,
		_getMemberName: (self: Remoting, memberName: string, objectType: string) -> string,
		_getDebugMemberName: (self: Remoting, memberName: string) -> string,
		_ensureContainer: (self: Remoting) -> Folder,
		_observeFolderBrio: (self: Remoting) -> Observable.Observable<Brio.Brio<Folder>>,
		_observeRemoteEventBrio: (
			self: Remoting,
			memberName: string
		) -> Observable.Observable<Brio.Brio<RemoteEvent>>,
		_observeRemoteFunctionBrio: (
			self: Remoting,
			memberName: string
		) -> Observable.Observable<Brio.Brio<RemoteFunction>>,
		_observeUpstreamRemoteEventBrio: (
			self: Remoting,
			memberName: string
		) -> Observable.Observable<Brio.Brio<RemoteEvent | BindableEvent>>,
		_fireUpstreamRemoteEvent: (self: Remoting, remoteEvent: RemoteEvent | BindableEvent, ...any) -> (),
		_promiseContainer: (self: Remoting, maid: Maid.Maid) -> Promise.Promise<Folder>,
		_promiseRemoteEvent: (self: Remoting, maid: Maid.Maid, memberName: string) -> Promise.Promise<RemoteEvent>,
		_getOrCreateRemoteEvent: (
			self: Remoting,
			memberName: string,
			attachHandler: ((RemoteEvent | BindableEvent) -> ())?
		) -> RemoteEvent | BindableEvent,
		_getOrCreateRemoteFunction: (
			self: Remoting,
			memberName: string,
			attachHandler: ((RemoteFunction | BindableFunction) -> ())?
		) -> RemoteFunction | BindableFunction,
		_promiseRemoteFunction: (
			self: Remoting,
			maid: Maid.Maid,
			memberName: string
		) -> Promise.Promise<RemoteFunction>,
		_translateCallback: (
			self: Remoting,
			maid: Maid.Maid,
			memberName: string,
			callback: (...any) -> ...any
		) -> (...any) -> ...any,

		-- Public remoting member export
		[string]: RemotingMember.RemotingMember,
	},
	{} :: typeof({ __index = Remoting })
))

--[=[
	Creates a new remoting instance

	@param instance Instance
	@param name string
	@param remotingRealm RemotingRealm?
	@return Remoting
]=]
function Remoting.new(instance: Instance, name: string, remotingRealm: RemotingRealms.RemotingRealm?): Remoting
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(name) == "string", "Bad name")
	assert(RemotingRealmUtils.isRemotingRealm(remotingRealm) or remotingRealm == nil, "Bad remotingRealm")

	local self: Remoting = setmetatable({} :: any, Remoting)

	self._maid = Maid.new()

	self._instance = assert(instance, "No instance")
	self._name = assert(name, "No name")
	self._remotingRealm = remotingRealm or RemotingRealmUtils.inferRemotingRealm()
	self._useDummyObject = not RunService:IsRunning()

	self._remoteFolderName = string.format("%sRemotes", self._name)
	self._remoteObjects = {}
	self._observableRelays = {}
	self._boundMemberKinds = {}

	return self
end

(Remoting :: any).__index = function(self, index)
	if Remoting[index] then
		return Remoting[index]
	elseif RAW_MEMBERS[index] then
		return rawget(self :: any, index)
	else
		return RemotingMember.new(self, index, self._remotingRealm)
	end
end

--[=[
	Connects to a given remote event.

	@param memberName string
	@param callback (...) -> ()
	@return MaidTask
]=]
function Remoting.Connect(self: Remoting, memberName: string, callback: (...any) -> ())
	assert(type(memberName) == "string", "Bad memberName")
	assert(type(callback) == "function", "Bad callback")

	local connectMaid = Maid.new()

	if self._remotingRealm == RemotingRealms.SERVER then
		if self._useDummyObject then
			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnClientEvent"))
			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnServerEvent"), function(event)
				connectMaid:GiveTask((event :: BindableEvent).Event:Connect(callback))
			end)
		else
			self:_getOrCreateRemoteEvent(memberName, function(event)
				connectMaid:GiveTask((event :: RemoteEvent).OnServerEvent:Connect(callback))
			end)
		end

		-- TODO: Cleanup if nothing else is expecting this
	elseif self._remotingRealm == RemotingRealms.CLIENT then
		connectMaid._warning = task.delay(5, function()
			warn(
				string.format(
					"[Remoting] - Failed to find RemoteEvent %q, event may never connect",
					self:_getDebugMemberName(memberName)
				)
			)
		end)

		if self._useDummyObject then
			connectMaid:GiveTask(
				self:_observeRemoteEventBrio(self:_getDummyMemberName(memberName, "OnClientEvent"))
					:Subscribe(function(brio)
						if brio:IsDead() then
							return
						end

						connectMaid._warning = nil

						local maid, bindableEvent: any = brio:ToMaidAndValue()
						maid:GiveTask((bindableEvent :: BindableEvent).Event:Connect(callback))
					end)
			)
		else
			connectMaid:GiveTask(self:_observeRemoteEventBrio(memberName):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				connectMaid._warning = nil

				local maid, remoteEvent = brio:ToMaidAndValue()
				maid:GiveTask(remoteEvent.OnClientEvent:Connect(callback))
			end))
		end
	else
		error("[Remoting.Connect] - Unknown RunService state")
	end

	self._maid[connectMaid] = connectMaid
	connectMaid:GiveTask(function()
		self._maid[connectMaid] = nil
	end)

	return connectMaid
end

--[=[
	If on the server, creates a new [RemoteFunction] with the name `memberName` and binds the
	invoke. On the client, it waits for the function to exist and then binds to it.

	@param memberName string
	@param callback any
]=]
function Remoting.Bind(self: Remoting, memberName: string, callback: (...any) -> ...any): Maid.Maid
	assert(type(memberName) == "string", "Bad memberName")
	assert(type(callback) == "function", "Bad callback")
	assert(
		self._boundMemberKinds[memberName] ~= "Observable",
		string.format("[Remoting.Bind] - %q is already bound as an observable", self:_getDebugMemberName(memberName))
	)

	self._boundMemberKinds[memberName] = "Method"

	local bindMaid: Maid.Maid = Maid.new()

	if self._remotingRealm == RemotingRealms.SERVER then
		if self._useDummyObject then
			self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnServerInvoke"), function(func)
				(func :: BindableFunction).OnInvoke = self:_translateCallback(bindMaid, memberName, callback)
			end)
			self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnClientInvoke"))
		else
			self:_getOrCreateRemoteFunction(memberName, function(func)
				(func :: RemoteFunction).OnServerInvoke = self:_translateCallback(bindMaid, memberName, callback)
			end)
		end

		-- TODO: Cleanup if nothing else is expecting this
	elseif self._remotingRealm == RemotingRealms.CLIENT then
		bindMaid._warning = task.delay(5, function()
			warn(
				string.format(
					"[Remoting] - Failed to find RemoteEvent %q, event may never fire",
					self:_getDebugMemberName(memberName)
				)
			)
		end)

		if self._useDummyObject then
			bindMaid:GiveTask(
				self:_observeRemoteFunctionBrio(self:_getDummyMemberName(memberName, "OnClientInvoke"))
					:Subscribe(function(brio)
						if brio:IsDead() then
							return
						end

						bindMaid._warning = nil

						local maid, remoteFunction: any = brio:ToMaidAndValue()
						remoteFunction.OnInvoke = self:_translateCallback(maid, memberName, callback)
					end)
			)
		else
			bindMaid:GiveTask(self:_observeRemoteFunctionBrio(memberName):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				bindMaid._warning = nil

				local maid, remoteFunction = brio:ToMaidAndValue()
				remoteFunction.OnClientInvoke = self:_translateCallback(maid, memberName, callback)
			end))
		end

		-- TODO: Warn if remote function doesn't exist
	else
		error("[Remoting.Bind] - Unknown RunService state")
	end

	self._maid[bindMaid] = bindMaid
	bindMaid:GiveTask(function()
		self._maid[bindMaid] = nil
	end)

	return bindMaid
end

--[=[
	Binds an observable factory to the member. The factory is invoked once per client
	subscription, so it can vary the stream by player and by the arguments the client
	passed to [Remoting.Observe].

	```lua
	remoting:BindObservable("Health", function(player, entityId)
		return observeHealth(player, entityId)
	end)
	```

	The stream lives for as long as the client stays subscribed. It is torn down when the
	client unsubscribes, when the source completes or fails, when the player leaves, or
	when this remoting is destroyed.

	@server
	@param memberName string
	@param factory (player: Player, ...any) -> Observable
	@return MaidTask
]=]
function Remoting.BindObservable(
	self: Remoting,
	memberName: string,
	factory: RemotingObservableServerRelay.ObservableFactory
): Maid.Maid
	assert(type(memberName) == "string", "Bad memberName")
	assert(type(factory) == "function", "Bad factory")
	assert(self._remotingRealm == RemotingRealms.SERVER, "BindObservable must be called on server")
	assert(
		self._boundMemberKinds[memberName] ~= "Method",
		string.format(
			"[Remoting.BindObservable] - %q is already bound as a method",
			self:_getDebugMemberName(memberName)
		)
	)
	assert(
		not self._observableRelays[memberName],
		string.format(
			"[Remoting.BindObservable] - %q is already bound as an observable",
			self:_getDebugMemberName(memberName)
		)
	)

	self._boundMemberKinds[memberName] = "Observable"

	local relay = RemotingObservableServerRelay.new(self, memberName, factory)
	self._observableRelays[memberName] = relay

	local bindMaid = Maid.new()
	bindMaid:GiveTask(function()
		-- Destroy already drained the table, so it owns the teardown in that case
		if self._observableRelays[memberName] == relay then
			self._observableRelays[memberName] = nil
			self._boundMemberKinds[memberName] = nil
			relay:Destroy()
		end
	end)

	self._maid[bindMaid] = bindMaid
	bindMaid:GiveTask(function()
		self._maid[bindMaid] = nil
	end)

	return bindMaid
end

--[=[
	Observes the member bound on the server with [Remoting.BindObservable].

	```lua
	maid:GiveTask(remoting:Observe("Health", entityId):Subscribe(print))
	```

	The observable is cold. Every subscription opens its own stream on the server, so pipe
	it through [Rx.share] if more than one consumer needs the same values.

	Unlike most observables in Nevermore this cannot emit synchronously on subscribe. The
	first value is at least one round trip away, and combinators like [Rx.combineLatest]
	will not emit until it lands.

	@client
	@param memberName string
	@param ... any
	@return Observable<...any>
]=]
function Remoting.Observe(self: Remoting, memberName: string, ...): Observable.Observable<...any>
	assert(type(memberName) == "string", "Bad memberName")
	assert(self._remotingRealm == RemotingRealms.CLIENT, "Observe must be called on client")

	local relay = self._observableRelays[memberName]
	if not relay then
		relay = RemotingObservableClientRelay.new(self, memberName)
		self._observableRelays[memberName] = relay
	end

	return relay:Observe(...)
end

--[=[
	Forward declares an event on the remoting object

	@param memberName string
]=]
function Remoting.DeclareEvent(self: Remoting, memberName: string)
	assert(type(memberName) == "string", "Bad memberName")

	if self._remotingRealm == RemotingRealms.SERVER then
		if self._useDummyObject then
			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnClientEvent"))
			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnServerEvent"))
		else
			self:_getOrCreateRemoteEvent(memberName)
		end
	end
end

--[=[
	Forward declares a method on the remoting object

	@param memberName string
]=]
function Remoting.DeclareMethod(self: Remoting, memberName: string)
	assert(type(memberName) == "string", "Bad memberName")

	if self._remotingRealm == RemotingRealms.SERVER then
		if self._useDummyObject then
			self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnServerInvoke"))
			self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnClientInvoke"))
		else
			self:_getOrCreateRemoteFunction(memberName)
		end
	end
end

function Remoting._translateCallback(self: Remoting, maid: Maid.Maid, memberName: string, callback: (...any) -> ...any)
	local alive = true
	maid:GiveTask(function()
		alive = false
	end)

	return function(...)
		if not alive then
			error(
				string.format(
					"[Remoting] - Function for %s is disconnected and can't be called",
					self:_getDebugMemberName(memberName)
				)
			)
			return
		end

		local results = table.pack(callback(...))

		local hasPromise = false
		for i = 1, results.n do
			if Promise.isPromise(results[i]) then
				hasPromise = true
				break
			end
		end

		if hasPromise then
			local promise
			if results.n == 1 then
				promise = results[1]
			else
				local data = {}
				for i = 1, results.n do
					table.insert(data, results[i])
				end

				promise = PromiseUtils.combine(data)
			end

			promise = maid:GivePromise(promise)

			local yielded = table.pack(promise:Wait())
			return table.unpack(yielded, 1, yielded.n)
		else
			return table.unpack(results, 1, results.n)
		end
	end
end

--[=[
	Fires the client with the individual request. Should consider this syntax instead.

	```lua
	local remoting = Remoting.new(workspace, "Test")
	remoting.Event:FireClient(otherPlayer, ...)
	```

	Equivalent of [RemoteEvent:FireClient].


	@param memberName string
	@param player Player
	@param ... any
]=]
function Remoting.FireClient(self: Remoting, memberName: string, player: Player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireClient must be called on server")

	if self._useDummyObject then
		-- The one simulated client is the (mocked) local player; a fire targeted at anyone else
		-- has no simulated receiver, so it is dropped -- mirroring the engine's player targeting.
		if player ~= (Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()) then
			return
		end

		local bindableEvent: BindableEvent =
			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnClientEvent")) :: any
		bindableEvent:Fire(...)
		return
	end

	local remoteEvent: RemoteEvent = self:_getOrCreateRemoteEvent(memberName) :: any
	remoteEvent:FireClient(player, ...)
end

--[=[
	Invokes the client, yielding as needed

	Equivalent of [RemoteFunction.InvokeClient].

	@server
	@param memberName string
	@param player Player
	@param ... any
]=]
function Remoting.InvokeClient(self: Remoting, memberName: string, player: Player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "InvokeClient must be called on server")

	if self._useDummyObject then
		local bindableFunction: BindableFunction =
			self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnClientInvoke")) :: any
		return bindableFunction:Invoke(...)
	end

	local remoteFunction: RemoteFunction = self:_getOrCreateRemoteFunction(memberName) :: any
	return remoteFunction:InvokeClient(player, ...)
end

--[=[
	Fires all clients with the event.

	Equivalent of [RemoteEvent:FireAllClients].

	@server
	@param memberName string
	@param ... any
]=]
function Remoting.FireAllClients(self: Remoting, memberName: string, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireAllClients must be called on server")

	if self._useDummyObject then
		local bindableEvent: BindableEvent =
			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnClientEvent")) :: any
		bindableEvent:Fire(...)
		return
	end

	local remoteEvent: RemoteEvent = self:_getOrCreateRemoteEvent(memberName) :: any
	remoteEvent:FireAllClients(...)
end

--[=[
	Fires all clients with the event except the excluded player. The excluded player may be nil to support
	NPC actions.

	@server
	@param memberName string
	@param excludePlayer Player | nil
	@param ... any
]=]
function Remoting.FireAllClientsExcept(self: Remoting, memberName: string, excludePlayer: Player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(
		typeof(excludePlayer) == "Instance" and (excludePlayer:IsA("Player") or PlayerMock.isMock(excludePlayer))
			or excludePlayer == nil,
		"Bad excludePlayer"
	)
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireAllClientsExcept must be called on server")

	if self._useDummyObject then
		-- The one simulated client is the (mocked) local player -- honor the exclusion for it.
		if excludePlayer ~= nil and excludePlayer == (Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()) then
			return
		end

		local bindableEvent: BindableEvent =
			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnClientEvent")) :: any
		bindableEvent:Fire(...)
		return
	end

	local remoteEvent: RemoteEvent = self:_getOrCreateRemoteEvent(memberName) :: any
	for _, player in Players:GetPlayers() do
		if player ~= excludePlayer then
			remoteEvent:FireClient(player, ...)
		end
	end
end

--[=[
	Fires the server

	@client
	@param memberName string
	@param ... any
]=]
function Remoting.FireServer(self: Remoting, memberName: string, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(self._remotingRealm == RemotingRealms.CLIENT, "FireServer must be called on client")

	self:PromiseFireServer(memberName, ...):Catch(function(err)
		if err ~= nil then
			warn(
				string.format(
					"[Remoting.FireServer] - Failed to fire %q: %s",
					self:_getDebugMemberName(memberName),
					tostring(err)
				)
			)
		end
	end)
end

--[=[
	Fires the server, resolving the promise once it is fired.

	@client
	@param memberName string
	@param ... any
	@return Promise
]=]
function Remoting.PromiseFireServer(self: Remoting, memberName: string, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(self._remotingRealm == RemotingRealms.CLIENT, "PromiseFireServer must be called on client")

	local fireMaid = Maid.new()
	local args = table.pack(...)

	local promise
	if self._useDummyObject then
		promise = self:_promiseRemoteEvent(fireMaid, self:_getDummyMemberName(memberName, "OnServerEvent"))
			:Then(function(bindableEvent)
				bindableEvent:Fire(
					Players.LocalPlayer or PlayerMock.getMockedLocalPlayer(),
					table.unpack(args, 1, args.n)
				)
			end)
	else
		promise = self:_promiseRemoteEvent(fireMaid, memberName):Then(function(remoteEvent)
			remoteEvent:FireServer(table.unpack(args, 1, args.n))
		end)
	end

	-- Registered before Finally is attached: the promise settles synchronously whenever the
	-- remote already exists, and a Finally attached first would fire before there was
	-- anything to remove, stranding the maid for the lifetime of the remoting
	self._maid[fireMaid] = fireMaid
	fireMaid:GiveTask(function()
		self._maid[fireMaid] = nil
	end)

	promise:Finally(function()
		self._maid[fireMaid] = nil
	end)

	-- TODO: Warn if remote event doesn't exist

	return promise
end

--[=[
	Invokes the server from the client

	@client
	@param memberName string
	@param ... any
	@return any
]=]
function Remoting.InvokeServer(self: Remoting, memberName: string, ...): ...any
	assert(type(memberName) == "string", "Bad memberName")

	return self:PromiseInvokeServer(memberName, ...):Wait()
end

--[=[
	Invokes the server from the client

	@client
	@param memberName string
	@param ... any
	@return Promise<...any>
]=]
function Remoting.PromiseInvokeServer(self: Remoting, memberName: string, ...): Promise.Promise<...any>
	assert(type(memberName) == "string", "Bad memberName")

	local invokeMaid = Maid.new()
	local args = table.pack(...)

	local promise
	if self._useDummyObject then
		promise = self:_promiseRemoteFunction(invokeMaid, self:_getDummyMemberName(memberName, "OnServerInvoke"))
			:Then(function(remoteFunction)
				return invokeMaid:GivePromise(
					RemoteFunctionUtils.promiseInvokeBindableFunction(
						remoteFunction,
						Players.LocalPlayer or PlayerMock.getMockedLocalPlayer(),
						table.unpack(args, 1, args.n)
					)
				)
			end)
	else
		promise = self:_promiseRemoteFunction(invokeMaid, memberName):Then(function(remoteFunction)
			return invokeMaid:GivePromise(
				RemoteFunctionUtils.promiseInvokeServer(remoteFunction, table.unpack(args, 1, args.n))
			)
		end)
	end

	-- Registered before Finally is attached -- see PromiseFireServer
	self._maid[invokeMaid] = invokeMaid
	invokeMaid:GiveTask(function()
		self._maid[invokeMaid] = nil
	end)

	promise:Finally(function()
		self._maid[invokeMaid] = nil
	end)

	-- TODO: Warn if remote function doesn't exist

	return promise
end

--[=[
	Invokes the client from the server

	@server
	@param memberName string
	@param player Player
	@param ... any
	@return Promise<any>
]=]
function Remoting.PromiseInvokeClient(self: Remoting, memberName: string, player: Player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	local invokeMaid: Maid.Maid = Maid.new()

	local promise
	if self._useDummyObject then
		local bindableFunction: BindableFunction =
			self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnClientInvoke")) :: any
		promise = invokeMaid:GivePromise(RemoteFunctionUtils.promiseInvokeBindableFunction(bindableFunction, ...))
	else
		local remoteFunction: RemoteFunction = self:_getOrCreateRemoteFunction(memberName) :: any
		promise = invokeMaid:GivePromise(RemoteFunctionUtils.promiseInvokeClient(remoteFunction, player, ...))
	end

	-- Registered before Finally is attached -- see PromiseFireServer
	self._maid[invokeMaid] = invokeMaid
	invokeMaid:GiveTask(function()
		self._maid[invokeMaid] = nil
	end)

	promise:Finally(function()
		self._maid[invokeMaid] = nil
	end)

	return promise
end

function Remoting.GetContainerClass(_self: Remoting): string
	return "Configuration"
end

function Remoting._ensureContainer(self: Remoting): Folder
	assert(self._remotingRealm == RemotingRealms.SERVER, "Folder should only be created on server")

	if self._container then
		return self._container
	end

	local created: Folder = self._maid:Add(Instance.new(self:GetContainerClass())) :: any
	created.Name = self._remoteFolderName
	created.Archivable = false
	created.Parent = self._instance

	self._maid:GiveTask(created)
	self._container = created

	return created
end

function Remoting._observeRemoteFunctionBrio(self: Remoting, memberName: string)
	assert(type(memberName) == "string", "Bad memberName")

	local remoteFunctionName = self:_getMemberName(memberName, REMOTE_FUNCTION_SUFFIX)

	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(item)
			if self._useDummyObject then
				return RxInstanceUtils.observeLastNamedChildBrio(item, "BindableFunction", remoteFunctionName)
			else
				return RxInstanceUtils.observeLastNamedChildBrio(item, "RemoteFunction", remoteFunctionName)
			end
		end) :: any,
	})
end

function Remoting._observeRemoteEventBrio(self: Remoting, memberName: string)
	assert(type(memberName) == "string", "Bad memberName")

	local remoteFunctionName = self:_getMemberName(memberName, REMOTE_EVENT_SUFFIX)

	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(item)
			if self._useDummyObject then
				return RxInstanceUtils.observeLastNamedChildBrio(item, "BindableEvent", remoteFunctionName)
			else
				return RxInstanceUtils.observeLastNamedChildBrio(item, "RemoteEvent", remoteFunctionName)
			end
		end) :: any,
	})
end

--[[
	Resolves the raw event the client sends relay messages over. Sends bypass
	PromiseFireServer so ordering is preserved -- see RemotingObservableClientRelay.
]]
function Remoting._observeUpstreamRemoteEventBrio(self: Remoting, memberName: string)
	assert(type(memberName) == "string", "Bad memberName")
	assert(self._remotingRealm == RemotingRealms.CLIENT, "Upstream events are only observed on the client")

	if self._useDummyObject then
		return self:_observeRemoteEventBrio(self:_getDummyMemberName(memberName, "OnServerEvent"))
	else
		return self:_observeRemoteEventBrio(memberName)
	end
end

function Remoting._fireUpstreamRemoteEvent(self: Remoting, remoteEvent: RemoteEvent | BindableEvent, ...)
	if self._useDummyObject then
		local bindableEvent = remoteEvent :: BindableEvent
		bindableEvent:Fire(Players.LocalPlayer or PlayerMock.getMockedLocalPlayer(), ...)
	else
		local realRemoteEvent = remoteEvent :: RemoteEvent
		realRemoteEvent:FireServer(...)
	end
end

function Remoting._promiseContainer(self: Remoting, maid: Maid.Maid): Promise.Promise<Folder>
	return maid:GivePromise(promiseChild(self._instance, self._remoteFolderName, 5))
end

function Remoting._promiseRemoteEvent(self: Remoting, maid: Maid.Maid, memberName: string): Promise.Promise<RemoteEvent>
	local remoteEventName = self:_getMemberName(memberName, REMOTE_EVENT_SUFFIX)
	return self:_promiseContainer(maid):Then(function(container)
		return maid:GivePromise(promiseChild(container, remoteEventName, 5))
	end)
end

function Remoting._promiseRemoteFunction(
	self: Remoting,
	maid: Maid.Maid,
	memberName: string
): Promise.Promise<RemoteFunction>
	local remoteEventName = self:_getMemberName(memberName, REMOTE_FUNCTION_SUFFIX)
	return self:_promiseContainer(maid):Then(function(container)
		return maid:GivePromise(promiseChild(container, remoteEventName, 5))
	end)
end

function Remoting._observeFolderBrio(self: Remoting): Observable.Observable<Brio.Brio<Folder>>
	assert(self._instance, "Not initialized")

	return RxInstanceUtils.observeLastNamedChildBrio(
			self._instance,
			self:GetContainerClass(),
			self._remoteFolderName
		) :: any
end

--[[
	Creates the remote function if it does not exist yet, otherwise returns the existing one.

	attachHandler runs against the function before it is parented, so a caller watching for the
	function to appear can never see one that exists but has no invoke bound. Existing functions
	are already parented, so it runs immediately for them.
]]
function Remoting._getOrCreateRemoteFunction(
	self: Remoting,
	memberName: string,
	attachHandler: ((RemoteFunction | BindableFunction) -> ())?
): RemoteFunction | BindableFunction
	assert(type(memberName) == "string", "Bad memberName")

	local remoteFunctionName = self:_getMemberName(memberName, REMOTE_FUNCTION_SUFFIX)

	local existing = self._remoteObjects[remoteFunctionName]
	if existing then
		if attachHandler then
			attachHandler(existing :: any)
		end

		return existing :: any
	end

	local container = self:_ensureContainer()

	local remoteFunction: Instance
	if self._useDummyObject then
		remoteFunction = Instance.new("BindableFunction")
	else
		remoteFunction = Instance.new("RemoteFunction")
	end

	remoteFunction.Name = remoteFunctionName
	remoteFunction.Archivable = false

	self._remoteObjects[remoteFunctionName] = remoteFunction :: any
	self._maid[remoteFunction] = remoteFunction

	if attachHandler then
		attachHandler(remoteFunction :: any)
	end

	remoteFunction.Parent = container

	return remoteFunction :: any
end

--[[
	Creates the remote event if it does not exist yet, otherwise returns the existing one.

	attachHandler runs against the event before it is parented, so a listener watching for the
	event to appear can never see one that exists but is not yet handling anything. Existing
	events are already parented, so it runs immediately for them.
]]
function Remoting._getOrCreateRemoteEvent(
	self: Remoting,
	memberName: string,
	attachHandler: ((RemoteEvent | BindableEvent) -> ())?
): RemoteEvent | BindableEvent
	assert(type(memberName) == "string", "Bad memberName")

	local remoteEventName = self:_getMemberName(memberName, REMOTE_EVENT_SUFFIX)

	local existing = self._remoteObjects[remoteEventName]
	if existing then
		if attachHandler then
			attachHandler(existing :: any)
		end

		return existing :: any
	end

	local container = self:_ensureContainer()

	local remoteEvent: Instance
	if self._useDummyObject then
		remoteEvent = Instance.new("BindableEvent")
	else
		remoteEvent = Instance.new("RemoteEvent")
	end

	remoteEvent.Name = remoteEventName
	remoteEvent.Archivable = false

	self._maid[remoteEvent] = remoteEvent
	self._remoteObjects[remoteEventName] = remoteEvent :: any

	if attachHandler then
		attachHandler(remoteEvent :: any)
	end

	remoteEvent.Parent = container

	return remoteEvent :: any
end

function Remoting._getMemberName(_self: Remoting, memberName: string, objectType: string): string
	return memberName .. objectType
end

function Remoting._getDummyMemberName(self: Remoting, memberName: string, suffix: string): string
	assert(self._useDummyObject, "Not dummy mode")

	return memberName .. "_" .. suffix .. "_"
end

function Remoting._getDebugMemberName(self: Remoting, memberName: string): string
	return string.format("%s.%s", self._name, memberName)
end

--[=[
	Cleans up the remoting object
]=]
function Remoting.Destroy(self: Remoting)
	-- Drained before the maid so relays can end their streams while the remotes still exist
	local relays = self._observableRelays
	self._observableRelays = {}

	for _, relay in relays do
		relay:Destroy()
	end

	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return Remoting
