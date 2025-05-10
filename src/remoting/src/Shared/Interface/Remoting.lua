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
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local RemoteFunctionUtils = require("RemoteFunctionUtils")
local RemotingMember = require("RemotingMember")
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

		-- Public methods
		DeclareEvent: (self: Remoting, memberName: string) -> (),
		DeclareMethod: (self: Remoting, memberName: string) -> (),
		Connect: (self: Remoting, memberName: string, callback: (...any) -> ()) -> Maid.Maid,
		Bind: (self: Remoting, memberName: string, callback: (...any) -> ()) -> Maid.Maid,
		FireClient: (self: Remoting, memberName: string, player: Player, ...any) -> (),
		FireAllClients: (self: Remoting, memberName: string, ...any) -> (),
		FireAllClientsExcept: (self: Remoting, memberName: string, excludePlayer: Player, ...any) -> (),
		FireServer: (self: Remoting, memberName: string, ...any) -> (),
		PromiseFireServer: (self: Remoting, memberName: string, ...any) -> Promise.Promise<()>,
		PromiseInvokeServer: (self: Remoting, memberName: string, ...any) -> Promise.Promise<...any>,
		GetContainerClass: (self: Remoting) -> string,

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
		_promiseContainer: (self: Remoting, maid: Maid.Maid) -> Promise.Promise<Folder>,
		_promiseRemoteEvent: (self: Remoting, maid: Maid.Maid, memberName: string) -> Promise.Promise<RemoteEvent>,
		_getOrCreateRemoteEvent: (self: Remoting, memberName: string) -> RemoteEvent | BindableEvent,
		_getOrCreateRemoteFunction: (self: Remoting, memberName: string) -> RemoteFunction | BindableFunction,
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
			self:DeclareEvent(memberName)

			self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnClientEvent"))
			local bindableEvent: BindableEvent =
				self:_getOrCreateRemoteEvent(self:_getDummyMemberName(memberName, "OnServerEvent")) :: any
			connectMaid:GiveTask(bindableEvent.Event:Connect(callback))
		else
			local remoteEvent: RemoteEvent = self:_getOrCreateRemoteEvent(memberName) :: any
			connectMaid:GiveTask(remoteEvent.OnServerEvent:Connect(callback))
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
	invoke. On the client, it waits for the event to exist and then binds to it.

	@param memberName string
	@param callback any
]=]
function Remoting.Bind(self: Remoting, memberName: string, callback: (...any) -> ...any): Maid.Maid
	assert(type(memberName) == "string", "Bad memberName")
	assert(type(callback) == "function", "Bad callback")

	local bindMaid: Maid.Maid = Maid.new()

	if self._remotingRealm == RemotingRealms.SERVER then
		if self._useDummyObject then
			self:DeclareMethod(memberName)

			local bindableFunction: BindableFunction =
				self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnServerInvoke")) :: any
			bindableFunction.OnInvoke = self:_translateCallback(bindMaid, memberName, callback)
		else
			local remoteFunction: RemoteFunction = self:_getOrCreateRemoteFunction(memberName) :: any
			remoteFunction.OnServerInvoke = self:_translateCallback(bindMaid, memberName, callback)
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
	Forward declares an event on the remoting object

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
			return table.unpack(results)
		end
	end
end

--[=[
	Fires the client with the individual request. Should consider this syntax instead.

	```lua
	local remoting = Remoting.new(workspace, "Test")
	remoting.Event:FireClient(otherPlayer, ...)
	```

	Equivalent of [RemoteFunction.FireClient].


	@param memberName string
	@param player Player
	@param ... any
]=]
function Remoting.FireClient(self: Remoting, memberName: string, player: Player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireClient must be called on server")

	if self._useDummyObject then
		local bindableEvent: BindableEvent = self:_getOrCreateRemoteEvent(memberName) :: any
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
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._remotingRealm == RemotingRealms.SERVER, "InvokeClient must be called on server")

	if self._useDummyObject then
		local bindableFunction: BindableFunction =
			self:_getOrCreateRemoteFunction(self:_getDummyMemberName(memberName, "OnClientInvoke")) :: any
		bindableFunction:Invoke(...)
		return
	end

	local remoteFunction: RemoteFunction = self:_getOrCreateRemoteFunction(memberName) :: any
	remoteFunction:InvokeClient(player, ...)
end

--[=[
	Fires all clients with the event.

	Equivalent of [RemoteEvent.FireAllClients].

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
		typeof(excludePlayer) == "Instance" and excludePlayer:IsA("Player") or excludePlayer == nil,
		"Bad excludePlayer"
	)
	assert(self._remotingRealm == RemotingRealms.SERVER, "FireAllClientsExcept must be called on server")

	if self._useDummyObject then
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

	self:PromiseFireServer(memberName, ...)
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
				bindableEvent:Fire(Players.LocalPlayer, table.unpack(args, 1, args.n))
			end)
	else
		promise = self:_promiseRemoteEvent(fireMaid, memberName):Then(function(remoteEvent)
			remoteEvent:FireServer(table.unpack(args, 1, args.n))
		end)
	end

	promise:Finally(function()
		self._maid[fireMaid] = nil
	end)
	self._maid[fireMaid] = fireMaid
	fireMaid:GiveTask(function()
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
						Players.LocalPlayer,
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

	promise:Finally(function()
		self._maid[invokeMaid] = nil
	end)
	self._maid[invokeMaid] = invokeMaid
	invokeMaid:GiveTask(function()
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
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

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

	promise:Finally(function()
		self._maid[invokeMaid] = nil
	end)

	self._maid[invokeMaid] = invokeMaid
	invokeMaid:GiveTask(function()
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

function Remoting._getOrCreateRemoteFunction(self: Remoting, memberName: string): RemoteFunction | BindableFunction
	assert(type(memberName) == "string", "Bad memberName")

	local remoteFunctionName = self:_getMemberName(memberName, REMOTE_FUNCTION_SUFFIX)

	if self._remoteObjects[remoteFunctionName] then
		return self._remoteObjects[remoteFunctionName] :: any
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
	remoteFunction.Parent = container

	self._remoteObjects[remoteFunctionName] = remoteFunction :: any
	self._maid[remoteFunction] = remoteFunction

	return remoteFunction :: any
end

function Remoting._getOrCreateRemoteEvent(self: Remoting, memberName: string): RemoteEvent | BindableEvent
	assert(type(memberName) == "string", "Bad memberName")

	local remoteEventName = self:_getMemberName(memberName, REMOTE_EVENT_SUFFIX)

	if self._remoteObjects[remoteEventName] then
		return self._remoteObjects[remoteEventName] :: any
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
	remoteEvent.Parent = container

	self._maid[remoteEvent] = remoteEvent
	self._remoteObjects[remoteEventName] = remoteEvent :: any

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
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return Remoting
