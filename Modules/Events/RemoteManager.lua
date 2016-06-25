-- Table Wrapper for handling client/server networking
-- @author Narrev
-- @original https://github.com/Vorlias/ROBLOX-ModRemote

-- Configurable
local CLIENT_CACHE_TIME = 5

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module
local RemoteManager = {}
local remoteEvent = {}
local remoteFunction = {}
local RemoteEvents = {}
local RemoteFunctions = {}

-- Server Only
local LastContact = {}
local Blacklist = {}

-- Client Only
local clientLastContact = 0 

-- Helper functions
local Load = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local Make = Load("Make")
local CallOnChildren = Load("CallOnChildren")

-- Localize frequently called functions
local time = os.time
local tick = tick
local next = next
local unpack = unpack
local newInstance = Instance.new
local connect = script.ChildAdded.connect
local _connection = connect(script.ChildAdded, function() end)
local disconnect = _connection.disconnect
disconnect(_connection)

local FindFirstChild = script.FindFirstChild
local Destroy = script.Destroy

-- Connection Wrappers
local function WaitForResponse(...)
	print("Updating clientLastContact")
	clientLastContact = tick()
	return ...
end

local function ClientRefresh(func)
	return function(...)
		return WaitForResponse(func(...))
	end
end

local function ServerRefresh(func)
	return function(player, ...)
		local playerName = player.Name
		if LastContact[playerName] then
			local timeDifference = tick() - LastContact[playerName]
			if timeDifference > 1.5 then
				print("[RemoteManager]", playerName, "is laggy. Blocking data")
				Blacklist[playerName] = time()
			end
			
			if timeDifference > 3 then
				print("[RemoteManager]", playerName, "is getting booted from the server")
				player:Kick("You have lost connection to the game")
			end	
		end
		print("Updating Last Contact")
		LastContact[playerName] = tick()
		local BlacklistTime = Blacklist[playerName]
		if not BlacklistTime or BlacklistTime and time() - BlacklistTime > 2 then
			return func(player, ...)
		else
			print("Blocked data from", playerName)
		end
	end
end

-- Metamethods
function remoteEvent:__index(i)
	if i == "OnServerEvent" then
		return self._OnServerEvent
	elseif i == "OnClientEvent" then
		return self._OnClientEvent
	end
	return rawget(remoteEvent, i) or self._Instance[i]
end

function remoteEvent:__newindex(i, v)
	if i == "OnServerEvent" then
		self._OnServerEvent:connect(v)
	elseif i == "OnClientEvent" then
		self._OnClientEvent:connect(v)
	else
		self._Instance[i] = v
	end
end

function remoteFunction:__index(i)
--	if i == "_cacheDuration" or i == "_cacheByValue" then return false end
	return rawget(remoteFunction, i) or self._Instance[i]
end

function remoteFunction:__newindex(i, v)
	if i == "OnServerInvoke" then
		self._Instance.OnServerInvoke = ServerRefresh(v)
	elseif i == "OnClientInvoke" then
		self._Instance.OnClientInvoke = ClientRefresh(v)
	else
		self._Instance[i] = v
	end
end

-- MetatableWrap function
local functionStorage, eventStorage, MetatableWrap do
	
	-- OnEvent Object
	local OnEvent = {}

	OnEvent.__index = OnEvent

	function OnEvent:connect(func) -- expand to support managing connections by index or value
		local connections = self._Connections
		local _Event = self._Event
		local connection = connect(self._Instance[_Event], _Event == "OnServerEvent" and ServerRefresh(func) or func)
		connections[#connections + 1] = connection
		return connection
	end

	function OnEvent:disconnect() -- expand to support managing connections by index or value
		local connections = self._Connections
		for a = 1, #connections do
			disconnect(connections[a])
		end
	end

	function OnEvent:wait()
		self._Instance[self._Event]:wait()
	end
	
	function MetatableWrap(instance, bool, Storage)
		--- Gives a metatable to instance, and puts instance in Storage
		-- @param Instance instance the instance to give the metatable to
		-- @param bool true for function, false for Event
		--	@default false
		-- @param RobloxObject Storage The parent the instance should be parented to
		--	@default functionStorage or eventStorage

		local remoteTable = bool and RemoteFunctions or RemoteEvents
		instance.Parent, instance.Archivable = Storage
		local instanceName = instance.Name
		local WrappedRemote = remoteTable[instanceName]

		if not WrappedRemote then
			local RemoteWrapper = bool and setmetatable({
					_Instance = instance;
					_cacheDuration = false;
					_cacheByValue = false;
					_cache = false;
				}, remoteFunction) or setmetatable({
					_Instance = instance;
					_OnServerEvent = setmetatable({_Connections = {}; _Instance = instance; _Event = "OnServerEvent"}, OnEvent);
					_OnClientEvent = setmetatable({_Connections = {}; _Instance = instance; _Event = "OnClientEvent"}, OnEvent);
				}, remoteEvent)

			remoteTable[instanceName] = RemoteWrapper
			return RemoteWrapper
		else
			return WrappedRemote
		end
	end
end

local ResourceFolder = FindFirstChild(ReplicatedStorage, "NevermoreResources")
local ExtractMethods_Event = newInstance("RemoteEvent")
local ExtractMethods_Function = newInstance("RemoteFunction")

local function GetRemote(name, bool)
	--- Gets a Remote if it exists, otherwise errors
	-- @param string name - the name of the function
	-- @param boolean bool - true for function, false for Event

	local Storage = bool and functionStorage or eventStorage

	assert(type(name) == "string", "[RemoteManager] Remote retrieval failed: Name must be a string")
	assert(FindFirstChild(Storage, name), "[RemoteManager] " .. name .. " not found, create it using CreateFunction/CreateEvent on the Server.")

	return MetatableWrap(Storage[name], bool, Storage)
end

local function GetFunction(name1, name2)
	--- Creates a RemoteFunction
	-- @param string name - the name of the function.

	return GetRemote(type(name2) == "string" and name2 or type(name1) == "string" and name1, true)
end
RemoteManager.GetFunction = GetFunction
RemoteManager.GetRemoteFunction = GetFunction

local function GetEvent(name1, name2)
	--- Helper function that gets a RemoteEvent
	-- Designed to function properly with either '.' or ':'
	-- @ServerSide Creates new RemoteEvent if nonexistant
	-- @param string name - the name of the event.

	return GetRemote(type(name2) == "string" and name2 or type(name1) == "string" and name1)
end
RemoteManager.GetEvent = GetEvent
RemoteManager.GetRemoteEvent = GetEvent

if RunService:IsServer() then
	
	local FireClient = ExtractMethods_Event.FireClient
	local FireAllClients = ExtractMethods_Event.FireAllClients
	local InvokeClient = ExtractMethods_Function.InvokeClient

	functionStorage = FindFirstChild(ResourceFolder, "RemoteFunctions") or Make("Folder" , {
		Parent	= ResourceFolder;
		Name	= "RemoteFunctions";
	})

	eventStorage = FindFirstChild(ResourceFolder, "RemoteEvents") or Make("Folder", {
		Parent	= ResourceFolder;
		Name	= "RemoteEvents";
	})

	function GetRemote(name, bool)
		--- Creates RemoteEvent/Function with name
		-- @param bool true for function, false for Event

		local Storage = bool and functionStorage or eventStorage
		local instance = FindFirstChild(Storage, name) or newInstance(bool and "RemoteFunction" or "RemoteEvent")
		instance.Name = name
		
		return MetatableWrap(instance, bool, Storage)
	end
	RemoteManager.CreateFunction = GetFunction
	RemoteManager.CreateRemoteFunction = GetFunction	
	RemoteManager.CreateEvent = GetEvent
	RemoteManager.CreateRemoteEvent = GetEvent

	local function Register(child)
		local bool = child:IsA("RemoteFunction")
		MetatableWrap(child, bool, bool and functionStorage or eventStorage)
	end

	-- RemoteManager Methods
	function RemoteManager:RegisterChildren(instance)
		--- Registers the Children inside of an instance
		-- @param Instance instance the object with Remotes in
		--	@default the script this was imported in to
		
		CallOnChildren(instance or ResourceFolder or ReplicatedStorage, Register)
	end

	-- RemoteEvent Object Methods
	local function SendToPlayer(self, player, ...)
		FireClient(self._Instance, player, ...)
	end
	remoteEvent.FireClient = SendToPlayer
	remoteEvent.FirePlayer = SendToPlayer
	remoteEvent.SendToPlayer = SendToPlayer
	remoteEvent.SendToClient = SendToPlayer

	local function SendToPlayers(self, playerList, ...)
		for a = 1, #playerList do
			FireClient(self._Instance, playerList[a], ...)
		end
	end
	remoteEvent.FireClients = SendToPlayers
	remoteEvent.FirePlayers = SendToPlayers
	remoteEvent.SendToPlayers = SendToPlayers
	remoteEvent.SendToClients = SendToPlayers

	local function SendToAllPlayers(self, ...)
		FireAllClients(self._Instance, ...)
	end
	remoteEvent.FireAllClients = SendToAllPlayers
	remoteEvent.FireAllPlayers = SendToAllPlayers
	remoteEvent.SendAllPlayers = SendToAllPlayers
	remoteEvent.SendAllClients = SendToAllPlayers
	remoteEvent.SendToAllPlayers = SendToAllPlayers
	remoteEvent.SendToAllClients = SendToAllPlayers

	-- RemoteFunction Object Methods
	local function ClientCallPack(player, playerName, successful, ...)
		if successful then
			print("Updating Last Contact")
			LastContact[playerName] = tick()
			return ...
		else
			return warn("[RemoteManager] InvokeClient - Failed to recieve response from", playerName, "Error Message:", ...)
		end
	end

	local function ClientCallHelper(playerName, instance, player, ...)
		return InvokeClient(instance, player, ...)
	end

	local function ClientCall(self, player, ...)
		local playerName = player.Name
		return ClientCallPack(player, playerName, pcall(ClientCallHelper, playerName, self._Instance, player, ...))
	end
	remoteFunction.CallPlayer = ClientCall
	remoteFunction.CallClient = ClientCall
	remoteFunction.InvokeClient = ClientCall
	remoteFunction.InvokePlayer = ClientCall

	local function DestroyInstance(self)
		self = Destroy(self._Instance)
	end
	remoteEvent.Destroy = DestroyInstance
	remoteFunction.Destroy = DestroyInstance

	local CacheManager = GetRemote("CacheManager")
	CacheManager.OnServerEvent = function(player)
		--LastContact[player.Name] = tick()
	end

	local function newPlayerAdded(player)
		local playerName = player.Name
		local startCount = time()

		for FunctionName, RemoteFunction in next, RemoteFunctions do
			if RemoteFunction._cacheDuration then
				FireClient(CacheManager._Instance, player, FunctionName, "_cacheDuration", RemoteFunction._cacheDuration)
			end
			if RemoteFunction._cacheByValue then
				FireClient(CacheManager._Instance, player, FunctionName, "_cacheByValue", RemoteFunction._cacheByValue)
			end
		end

		local function gracePeriod()
			return wait() and time() - startCount >= 20
		end

		repeat until LastContact[playerName] or gracePeriod()
		print("Updating Last Contact")
		LastContact[playerName] = tick()
	end

	local function PlayerRemoving(player)
		local playerName = player.Name
		LastContact[playerName], Blacklist[playerName] = wait() and nil
	end
	
	playerList = Players:GetPlayers()

	connect(Players.PlayerAdded, newPlayerAdded)
	connect(Players.PlayerRemoving, PlayerRemoving)

	for a = 1, #playerList do
		newPlayerAdded(playerList[a])
	end

	local function SetClientCache(self, seconds, _cacheByValue)
		-- @param boolean _cacheByValue determines whether or not the function should be cached depending on the first value of the call
		assert(type(not _cacheByValue) == "boolean", "[RemoteManger] SetClientCache's last parameter must be a boolean")
		assert(type(seconds) == "number", "[RemoteManger] SetClientCache's first parameter must be a number")

		local oldcache = self._cacheDuration
		local old_cacheByValue = self._cacheByValue

		local _cacheDuration = (seconds or CLIENT_CACHE_TIME) > 0 and seconds

		if _cacheDuration ~= oldcache then
			self._cacheDuration = _cacheDuration
			FireAllClients(CacheManager._Instance, self._Instance.Name, "_cacheDuration", _cacheDuration)
		end

		if _cacheByValue ~= old_cacheByValue then
			self._cacheByValue = _cacheByValue
			FireAllClients(CacheManager._Instance, self._Instance.Name, "_cacheByValue", _cacheByValue)
		end
	end
	remoteFunction.SetClientCache = SetClientCache
	remoteFunction.SetCache = SetClientCache
end

if RunService:IsClient() then

	functionStorage = FindFirstChild(ResourceFolder, "RemoteFunctions") or error("[RemoteManager] NevermoreResources Function Storage not found")
	eventStorage = FindFirstChild(ResourceFolder, "RemoteEvents") or error("[RemoteManager] NevermoreResources Event Storage not found")

	local FireServer = ExtractMethods_Event.FireServer
	local InvokeServer = ExtractMethods_Function.InvokeServer

	local CacheManager = GetRemote("CacheManager")
	local ContentProvider = game:GetService("ContentProvider")
	
	local function SendToServer(self, ...)
		print("Updating clientLastContact")
		clientLastContact = tick()
		return FireServer(self._Instance, ...)
	end
	remoteEvent.FireServer = SendToServer
	remoteEvent.SendToServer = SendToServer
	
	local function ResetClientCache(self)
		self._cache = self._cache and {} or not warn(self._Instance.Name, "does not have a cache") and {}
	end
	remoteFunction.ResetClientCache = ResetClientCache
	remoteFunction.ResetCache = ResetClientCache

	-- CallServer helper function
	local function Cache(cache, cacheDuration, ...)
		cache.Expires = time() + cacheDuration
		cache.Data = {...}
		return ...
	end
	
	local function WaitForResponse(...)
		print("Updating clientLastContact")
		clientLastContact = tick()
		return ...
	end

	local function CallServer(self, ...)
		local cacheDuration = self._cacheDuration

		if not cacheDuration then
			print("Updating clientLastContact")
			clientLastContact = tick()
			return InvokeServer(self._Instance, ...)
		else
			local cache

			if self._cacheByValue then
				local cacheName = ({...})[1]
				cache = self._cache[cacheName]
				if not cache then
					cache = {}
					self._cache[cacheName] = cache
					print("Updating clientLastContact")
					clientLastContact = tick()
					return Cache(cache, cacheDuration, InvokeServer(self._Instance, ...))
				end
			else
				cache = self._cache
				if not cache then
					cache = {}
					self._cache = cache
					print("Updating clientLastContact")
					clientLastContact = tick()
					return Cache(cache, cacheDuration, InvokeServer(self._Instance, ...))
				end
			end
			
			if time() >= cache.Expires then
				print("Updating clientLastContact")
				clientLastContact = tick()
				return Cache(cache, cacheDuration, InvokeServer(self._Instance, ...))
			else
				return unpack(cache.Data)
			end
		end
	end
	remoteFunction.CallServer = CallServer
	remoteFunction.ServerCall = CallServer
	remoteFunction.InvokeServer = CallServer
	remoteFunction.ServerInvoke = CallServer

	CacheManager.OnClientEvent:connect(function(Name, key, value)
		local remoteFunction = GetRemote(Name, true)
		remoteFunction[key] = value

		if key == "_cacheByValue" then
			remoteFunction._cache = {}
		end
	end)

	spawn(function() -- Open a new thread
		repeat until wait() and ContentProvider.RequestQueueSize == 0
		SendToServer(CacheManager)
		while true do -- Ugh
			local newTick = tick()
			print("Waiting", 1 - newTick + clientLastContact)
			wait(1 - newTick + clientLastContact)
			if newTick - clientLastContact > .99 then -- Let server know we're still here!
				SendToServer(CacheManager)
			end
		end
	end)
end

Destroy(ExtractMethods_Event)
Destroy(ExtractMethods_Function)

return RemoteManager