--[=[
	Offers a thin wrapper around Roblox remoting instances and events. Designed to reduce
	the amount of code needed to construct a large set of RemoteFunction/RemoteEvent instances.

	@class Remoting
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Maid = require("Maid")
local Promise = require("Promise")
local promiseChild = require("promiseChild")
local PromiseUtils = require("PromiseUtils")
local RemoteFunctionUtils = require("RemoteFunctionUtils")
local RemotingMember = require("RemotingMember")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RAW_MEMBERS = {
	_name = true;
	_maid = true;
	_instance = true;
	_remoteObjects = true;
	_remoteFolder = true;
}

local REMOTE_EVENT_SUFFIX = "Event"
local REMOTE_FUNCTION_SUFFIX = "Function"

local Remoting = {}
Remoting.ClassName = "Remoting"
Remoting.__index = Remoting

--[=[
	Creates a new remoting instance

	@param instance Instance
	@param name string
	@return Remoting
]=]
function Remoting.new(instance, name)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(name) == "string", "Bad name")

	local self = setmetatable({}, Remoting)

	self._maid = Maid.new()

	self._instance = assert(instance, "No instance")
	self._name = assert(name, "No name")

	self._remoteFolderName = string.format("%sRemotes", self._name)
	self._remoteObjects = {}

	return self
end

function Remoting:__index(index)
	if Remoting[index] then
		return Remoting[index]
	elseif RAW_MEMBERS[index] then
		return rawget(self, index)
	else
		return RemotingMember.new(self, index)
	end
end

--[=[
	Connects to a given remote event.

	@param memberName string
	@param callback string
	@return MaidTask
]=]
function Remoting:Connect(memberName, callback)
	assert(type(memberName) == "string", "Bad memberName")
	assert(type(callback) == "function", "Bad callback")

	local connectMaid = Maid.new()

	if RunService:IsServer() then
		local remoteEvent = self:_getOrCreateRemoteEvent(memberName)
		connectMaid:GiveTask(remoteEvent.OnServerEvent:Connect(callback))

		-- TODO: Cleanup if nothing else is expecting this
	elseif RunService:IsClient() then
		connectMaid._warning = task.delay(5, function()
			warn(string.format("[Remoting] - Failed to find RemoteEvent %q, event may never connect", memberName))
		end)

		connectMaid:GiveTask(self:_observeRemoteEventBrio(memberName):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			connectMaid._warning = nil

			local remoteEvent = brio:GetValue()
			local maid = brio:ToMaid()

			maid:GiveTask(remoteEvent.OnClientEvent:Connect(callback))
		end))
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
function Remoting:Bind(memberName, callback)
	assert(type(memberName) == "string", "Bad memberName")
	assert(type(callback) == "function", "Bad callback")

	local bindMaid = Maid.new()

	if RunService:IsServer() then
		local remoteFunction = self:_getOrCreateRemoteFunction(memberName)
		remoteFunction.OnServerInvoke = self:_translateCallback(bindMaid, memberName, callback)

		-- TODO: Cleanup if nothing else is expecting this
	elseif RunService:IsClient() then
		bindMaid._warning = task.delay(5, function()
			warn(string.format("[Remoting] - Failed to find RemoteEvent %q, event may never fire", memberName))
		end)

		bindMaid:GiveTask(self:_observeRemoteFunctionBrio(memberName):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			bindMaid._warning = nil

			local remoteFunction = brio:GetValue()
			local maid = brio:ToMaid()

			remoteFunction.OnClientInvoke = self:_translateCallback(maid, memberName, callback)
		end))

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
function Remoting:DeclareEvent(memberName)
	assert(type(memberName) == "string", "Bad memberName")

	if RunService:IsServer() then
		self:_getOrCreateRemoteEvent(memberName)
	end
end

--[=[
	Forward declares an event on the remoting object

	@param memberName string
]=]
function Remoting:DeclareMethod(memberName)
	assert(type(memberName) == "string", "Bad memberName")

	if RunService:IsServer() then
		self:_getOrCreateRemoteFunction(memberName)
	end
end

function Remoting:_translateCallback(maid, memberName, callback)
	local alive = true
	maid:GiveTask(function()
		alive = false
	end)

	return function(...)
		if not alive then
			error(string.format("[Remoting] - Function for %s is disconnected and can't be called", memberName))
			return
		end

		local results = table.pack(callback(...))

		local hasPromise = false
		for i=1, results.n do
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
				for i=1, results.n do
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
function Remoting:FireClient(memberName, player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(RunService:IsServer(), "FireClient must be called on server")

	local remoteEvent = self:_getOrCreateRemoteEvent(memberName)
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
function Remoting:InvokeClient(memberName, player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(RunService:IsServer(), "InvokeClient must be called on server")

	local remoteEvent = self:_getOrCreateRemoteFunction(memberName)
	remoteEvent:InvokeClient(player, ...)
end

--[=[
	Fires all clients with the event.

	Equivalent of [RemoteEvent.FireAllClients].

	@server
	@param memberName string
	@param ... any
]=]
function Remoting:FireAllClients(memberName, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(RunService:IsServer(), "FireAllClients must be called on server")

	local remoteEvent = self:_getOrCreateRemoteEvent(memberName)
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
function Remoting:FireAllClientsExcept(memberName, excludePlayer, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(excludePlayer) == "Instance" and excludePlayer:IsA("Player") or excludePlayer == nil, "Bad excludePlayer")
	assert(RunService:IsServer(), "FireAllClientsExcept must be called on server")

	local remoteEvent = self:_getOrCreateRemoteEvent(memberName)
	for _, player in pairs(Players:GetPlayers()) do
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
function Remoting:FireServer(memberName, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(RunService:IsClient(), "FireServer must be called on server")

	self:PromiseFireServer(memberName, ...)
end

--[=[
	Fires the server, resolving the promise once it is fired.

	@client
	@param memberName string
	@param ... any
	@return Promise
]=]
function Remoting:PromiseFireServer(memberName, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(RunService:IsClient(), "PromiseFireServer must be called on server")

	local fireMaid = Maid.new()
	local args = table.pack(...)

	local promise = self:_promiseRemoteEvent(fireMaid, memberName)
		:Then(function(remoteEvent)
			remoteEvent:FireServer(table.unpack(args, 1, args.n))
		end)

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
function Remoting:InvokeServer(memberName, ...)
	assert(type(memberName) == "string", "Bad memberName")

	return self:PromiseInvokeServer(memberName, ...):Wait()
end

--[=[
	Invokes the server from the client

	@client
	@param memberName string
	@param ... any
	@return Promise<any>
]=]
function Remoting:PromiseInvokeServer(memberName, ...)
	assert(type(memberName) == "string", "Bad memberName")

	local invokeMaid = Maid.new()
	local args = table.pack(...)

	local promise = self:_promiseRemoteFunction(invokeMaid, memberName)
		:Then(function(remoteFunction)
			return invokeMaid:GivePromise(RemoteFunctionUtils.promiseInvokeServer(remoteFunction, table.unpack(args, 1, args.n)))
		end)

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
function Remoting:PromiseInvokeClient(memberName, player, ...)
	assert(type(memberName) == "string", "Bad memberName")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local remoteFunction = self:_getOrCreateRemoteFunction(memberName)

	local invokeMaid = Maid.new()

	local promise = invokeMaid:GivePromise(RemoteFunctionUtils.promiseInvokeClient(remoteFunction, player, ...))
	promise:Finally(function()
		self._maid[invokeMaid] = nil
	end)

	self._maid[invokeMaid] = invokeMaid
	invokeMaid:GiveTask(function()
		self._maid[invokeMaid] = nil
	end)

	return promise
end

function Remoting:_ensureFolder()
	assert(RunService:IsServer(), "Folder should only be created on server")

	if self._remoteFolder then
		return self._remoteFolder
	end

	self._remoteFolder = Instance.new("Folder")
	self._remoteFolder.Name = self._remoteFolderName
	self._remoteFolder.Archivable = false
	self._remoteFolder.Parent = self._instance

	return self._remoteFolder
end

function Remoting:_observeRemoteFunctionBrio(memberName)
	assert(type(memberName) == "string", "Bad memberName")

	local remoteFunctionName = self:_getMemberName(memberName, REMOTE_FUNCTION_SUFFIX)

	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(item)
			return RxInstanceUtils.observeLastNamedChildBrio(item, "RemoteFunction", remoteFunctionName)
		end)
	})
end

function Remoting:_observeRemoteEventBrio(memberName)
	assert(type(memberName) == "string", "Bad memberName")

	local remoteFunctionName = self:_getMemberName(memberName, REMOTE_EVENT_SUFFIX)

	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(item)
			return RxInstanceUtils.observeLastNamedChildBrio(item, "RemoteEvent", remoteFunctionName)
		end)
	})
end

function Remoting:_promiseFolder(maid)
	return maid:GivePromise(promiseChild(self._instance, self._remoteFolderName, 5))
end

function Remoting:_promiseRemoteEvent(maid, memberName)
	local remoteEventName = self:_getMemberName(memberName, REMOTE_EVENT_SUFFIX)
	return self:_promiseFolder(maid)
		:Then(function(folder)
			return maid:GivePromise(promiseChild(folder, remoteEventName, 5))
		end)
end

function Remoting:_promiseRemoteFunction(maid, memberName)
	local remoteEventName = self:_getMemberName(memberName, REMOTE_FUNCTION_SUFFIX)
	return self:_promiseFolder(maid)
		:Then(function(folder)
			return maid:GivePromise(promiseChild(folder, remoteEventName, 5))
		end)
end


function Remoting:_observeFolderBrio()
	assert(self._instance, "Not initialized")

	return RxInstanceUtils.observeLastNamedChildBrio(self._instance, "Folder", self._remoteFolderName)
end

function Remoting:_getOrCreateRemoteFunction(memberName)
	assert(type(memberName) == "string", "Bad memberName")

	local remoteFunctionName = self:_getMemberName(memberName, REMOTE_FUNCTION_SUFFIX)

	if self._remoteObjects[remoteFunctionName] then
		return self._remoteObjects[remoteFunctionName]
	end

	local folder = self:_ensureFolder()

	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = remoteFunctionName
	remoteFunction.Archivable = false
	remoteFunction.Parent = folder

	self._remoteObjects[remoteFunctionName] = remoteFunction
	self._maid[remoteFunction] = remoteFunction

	return remoteFunction
end

function Remoting:_getOrCreateRemoteEvent(memberName)
	assert(type(memberName) == "string", "Bad memberName")

	local remoteEventName = self:_getMemberName(memberName, REMOTE_EVENT_SUFFIX)

	if self._remoteObjects[remoteEventName] then
		return self._remoteObjects[remoteEventName]
	end

	local folder = self:_ensureFolder()

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = remoteEventName
	remoteEvent.Archivable = false
	remoteEvent.Parent = folder

	self._maid[remoteEvent] = remoteEvent
	self._remoteObjects[remoteEventName] = remoteEvent

	return remoteEvent
end

function Remoting:_getMemberName(memberName, objectType)
	return memberName .. objectType
end

--[=[
	Cleans up the remoting object
]=]
function Remoting:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return Remoting
