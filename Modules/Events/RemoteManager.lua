-- @Author Vorlias
-- Edited by Narrev

--[[
	ModRemote v4.00
		ModuleScript for handling networking via client/server
		
	Documentation for this ModuleScript can be found at
		https://github.com/VoidKnight/ROBLOX-RemoteModule/tree/master/Version-3.x
]]

-- Constants
local client_Max_Wait_For_Remotes = 1
local default_Client_Cache = 10

-- Services
local ReplicatedStorage	= game:GetService("ReplicatedStorage")
local server		= game:FindService("NetworkServer")
local remote		= {remoteEvent = {}; remoteFunction = {}}

-- Localize Tables
local remoteEvent, remoteFunction, FuncCache, RemoteEvents, RemoteFunctions = remote.remoteEvent, remote.remoteFunction, {}, {}, {}

-- Localize Functions
local time, newInstance, traceback = os.time, Instance.new, debug.traceback

assert(workspace.FilteringEnabled or not server, "[ModRemote] ModRemote 4.0 does not work with filterless games due to security vulnerabilties. Please consider using Filtering or use ModRemote 2.7x")

-- Utility functions
local function Make(ClassType, Properties)
	-- @param ClassType The type of class to instantiate
	-- @param Properties The properties to use

	assert(type(Properties) == "table", "Properties is not a table")

	local Object = newInstance(ClassType)
	
	for Index, Value in next, Properties do
		Object[Index] = Value
	end

	return Object
end

local function WaitForChild(Parent, Name, TimeLimit)
	-- Waits for a child to appear. Not efficient, but it shouldn't have to be. It helps with
	-- debugging. Useful when ROBLOX lags out, and doesn't replicate quickly. Will warn
	-- @param Parent The Parent to search in for the child.
	-- @param Name The name of the child to search for
	-- @param TimeLimit If TimeLimit is given, then it will return after the timelimit, even if it
	--     hasn't found the child.

	assert(Parent, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")

	local Child     = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned    = false

	while not Child do
		wait()
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + (TimeLimit or 5) <= tick() then
			Warned = true
			warn("[WaitForChild] - Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")\n" .. traceback())
			if TimeLimit then
				return Parent:FindFirstChild(Name)
			end
		end
	end

	return Child
end

-- Get storage or create if nonexistent
local functionStorage = ReplicatedStorage:FindFirstChild("RemoteFunctions") or Make("Folder" , {
	Parent	= ReplicatedStorage;
	Name	= "RemoteFunctions";
})

local eventStorage = ReplicatedStorage:FindFirstChild("RemoteEvents") or Make("Folder", {
	Parent	= ReplicatedStorage;
	Name	= "RemoteEvents";
})

-- Metatables
local functionMetatable = {
	__index = function(self, i)
		if rawget(remoteFunction, i) then
			return rawget(remoteFunction, i)
		else
			return rawget(self, i)
		end
	end;

	__newindex = function(self, i, v)
		if i == 'OnCallback' and type(v) == 'function' then
			self:Callback(v)
		end
	end;
	
	__call = function(self, ...)
		if server then
			return self:CallPlayer(...)
		else
			return self:CallServer(...)
		end
	end;
}

local eventMetatable = {
	__index = function(self, i)
		if rawget(remoteEvent, i) then
			return rawget(remoteEvent, i)
		else
			return rawget(self, i)
		end
	end;

	__newindex = function(self, i, v)
		if (i == 'OnRecieved' and type(v) == 'function') then
			self:Listen(v)
		end
	end;
}

local remoteMetatable = {
	__call = function(self, ...)
		assert(server, "ModRemote can only be called from server.")
		
		local args = {...}

		if #args > 0 then
			for a = 1, #args do
				remote:RegisterChildren(args[a])
			end
		else
			remote:RegisterChildren()
		end
		
		return self
	end;
}

-- Helper Functions
local function CreateFunctionMetatable(instance)
	return setmetatable({Instance = instance}, functionMetatable)
end

local function CreateEventMetatable(instance)
	return setmetatable({Instance = instance}, eventMetatable)
end

local function CreateFunction(name, instance)
	local instance = instance or functionStorage:FindFirstChild(name) or newInstance("RemoteFunction")
	instance.Parent = functionStorage
	instance.Name = name
	
	local _event = CreateFunctionMetatable(instance)
	
	RemoteFunctions[name] = _event
	
	return _event
end

local function CreateEvent(name, instance)
	local instance = instance or eventStorage:FindFirstChild(name) or newInstance("RemoteEvent")
	instance.Parent = eventStorage
	instance.Name = name
	
	local _event = CreateEventMetatable(instance)
	
	RemoteEvents[name] = _event
	
	return _event
end

-- remote Object Methods
function remote:RegisterChildren(instance)
	--- Registers the Children inside of an instance
	-- @param Instance instance the object with Remotes in
	--	@default the script this was imported in to
	assert(server, "RegisterChildren can only be called from the server.")
	local parent = instance or getfenv(0).script

	if parent then
		local children = parent:GetChildren()
		for a = 1, #children do
			local child = children[a]
			if child:IsA("RemoteEvent") then
				CreateEvent(child.Name, child)
			elseif child:IsA("RemoteFunction") then
				CreateFunction(child.Name, child)
			end
		end
	end
end

function remote:GetFunctionFromInstance(instance)
	return CreateFunctionMetatable(instance)
end

function remote:GetEventFromInstance(instance)
	return CreateEventMetatable(instance)
end

function remote:GetFunction(name)
	--- Gets a function if it exists, otherwise errors
	-- @param string name - the name of the function.

	assert(type(name) == 'string', "[ModRemote] GetFunction - Name must be a string")
	assert(WaitForChild(functionStorage, name, client_Max_Wait_For_Remotes), "[ModRemote] GetFunction - Function " .. name .. " not found, create it using CreateFunction.")

	return RemoteFunctions[name] or CreateFunction(name)
end

function remote:GetEvent(name)
	--- Gets an event if it exists, otherwise errors
	-- @param string name - the name of the event.

	assert(type(name) == 'string', "[ModRemote] GetEvent - Name must be a string")
	assert(WaitForChild(eventStorage, name, client_Max_Wait_For_Remotes), "[ModRemote] GetEvent - Event " .. name .. " not found, create it using CreateEvent.")
	
	return RemoteEvents[name] or CreateEvent(name)
end

function remote:CreateFunction(name)
	--- Creates a function
	-- @param string name - the name of the function.

	if not server then warn("[ModRemote] CreateFunction should be used by the server.") end
	return CreateFunction(name)
end

function remote:CreateEvent(name)
	--- Creates an event 
	-- @param string name - the name of the event.

	if not server then warn("[ModRemote] CreateEvent should be used by the server.") end
	return CreateEvent(name)
end

-- RemoteEvent Object Methods
function remoteEvent:SendToPlayers(playerList, ...)
	assert(server, "[ModRemote] SendToPlayers should be called from the Server side.")
	for a = 1, #playerList do
		self.Instance:FireClient(playerList[a], ...)
	end
end

function remoteEvent:SendToPlayer(player, ...)
	assert(server, "[ModRemote] SendToPlayers should be called from the Server side.")
	self.Instance:FireClient(player, ...)
end

function remoteEvent:SendToServer(...)
	assert(not server, "SendToServer should be called from the Client side.")
	self.Instance:FireServer(...)
end

function remoteEvent:SendToAllPlayers(...)
	assert(server, "[ModRemote] SendToPlayers should be called from the Server side.")
	self.Instance:FireAllClients(...)
end

function remoteEvent:Listen(func)
	if server then
		self.Instance.OnServerEvent:connect(func)
	else
		self.Instance.OnClientEvent:connect(func)
	end
end

function remoteEvent:Wait()
	if server then
		self.Instance.OnServerEvent:wait()
	else
		self.Instance.OnClientEvent:wait()
	end
end

function remoteEvent:GetInstance()
	return self.Instance
end

function remoteEvent:Destroy()
	self.Instance:Destroy()
end

-- RemoteFunction Object Methods
function remoteFunction:CallPlayer(player, ...)

	assert(server, "[ModRemote] CallPlayer should be called from the server side.")
	
	local args = {...}
	local attempt, err = pcall(function()
		return self.Instance:InvokeClient(player, unpack(args))
	end)
	
	if not attempt then
		return warn("[ModRemote] CallPlayer - Failed to recieve response from " .. player.Name)
	end	
end

function remoteFunction:Callback(func)
	if server then
		self.Instance.OnServerInvoke = func
	else
		self.Instance.OnClientInvoke = func
	end
end

function remoteFunction:GetInstance()
	return self.Instance
end

function remoteFunction:Destroy()
	self.Instance:Destroy()
end

function remoteFunction:SetClientCache(seconds, useAction)
	
	local seconds = seconds or default_Client_Cache
	assert(server, "SetClientCache must be called on the server.")
	local instance = self.Instance

	if seconds <= 0 then
		local cache = instance:FindFirstChild("ClientCache")
		if cache then cache:Destroy() end
	else
		local cache = instance:FindFirstChild("ClientCache") or Make("IntValue", {
			Parent = instance;
			Name = "ClientCache";
			Value = seconds;
		})
	end
	
	if useAction then
		-- Put a BoolValue object inside of self.Instance to mark that we are UseActionCaching
		-- Possible Future Update: Come up with a better way to mark we are UseActionCaching
		--			We could change the ClientCache string, but that might complicate things
		--			*We could try using the Value of the ClientCache object inside the remoteFunction
		local cache = instance:FindFirstChild("UseActionCaching") or Make("BoolValue", {
			Parent = instance;
			Name = "UseActionCaching";
		})
	else
		local cache = instance:FindFirstChild("UseActionCaching")
		if cache then cache:Destroy() end			
	end
end

function remoteFunction:ResetClientCache()

	assert(not server, "ResetClientCache must be used on the client.")
	local instance = self.Instance

	if instance:FindFirstChild("ClientCache") then
		FuncCache[instance:GetFullName()] = {Expires = 0, Value = nil}
	else
		warn(instance:GetFullName() .. " does not have a cache.")
	end		
end

function remoteFunction:CallServer(...)
	assert(not server, "[ModRemote] CallServer should be called from the client side.")

	local instance = self.Instance
	local clientCache = instance:FindFirstChild("ClientCache")

	if clientCache then
		local cacheName = instance:GetFullName() .. (instance:FindFirstChild("UseActionCaching") and tostring(({...})[1]) or "")
		
		local cache = FuncCache[cacheName]
		if cache and time() < cache.Expires then
			-- If the cache exists in FuncCache and the time hasn't expired
			-- Return cached arguments
			return unpack(cache.Value)
		else
			-- The cache isn't in FuncCache or time has expired
			-- Invoke the server with the arguments
			-- Cache Arguments
			
			local cacheValue = {instance:InvokeServer(...)}
			FuncCache[cacheName] = {Expires = time() + clientCache.Value, Value = cacheValue}
			return unpack(cacheValue)
		end
	else
		return instance:InvokeServer(...)
	end
end

return setmetatable(remote, remoteMetatable)
