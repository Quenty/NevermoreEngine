-- @Author Vorlias
-- Main variables
local replicated = game:GetService("ReplicatedStorage");
local server = game:FindService("NetworkServer");
local remoteStorage = replicated;

local functionStorage = remoteStorage:FindFirstChild("RemoteFunctions") or Instance.new("Folder",remoteStorage);
functionStorage.Name = "RemoteFunctions";

local eventStorage = remoteStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder",remoteStorage);
eventStorage.Name = "RemoteEvents";

local filtering = workspace.FilteringEnabled;
local localServer = (game.JobId == '');

local client = not server;
local remote = {
	Events = {};
	Functions = {};
	event = {};
	func = {};
	internal = {};
	Version = 3.18;
};

-- This warning will only show on the server
if (not filtering and server and not remote.HideFilteringWarning) then
	error("[ModRemote] ModRemote 3.0 does not work with filterless games due to security vulnerabilties. Please consider using Filtering or use ModRemote 2.7x");
end

--if (script.Parent ~= game:GetService("ReplicatedStorage")) then
--	error("[ModRemote] Parent of Module should be ReplicatedStorage.");
--end



function remote.internal:CreateEventMetatable(instance)
	local _event = {
		Instance = instance;
	};
	local _mt = {
		__index = (function(self, i)
			if (rawget(remote.event,i) ~= nil) then
				return rawget(remote.event,i);
			else
				return rawget(self, i);
			end
		end);
		__newindex = (function(self, i, v)
			if (i == 'OnRecieved' and type(v) == 'function') then
				self:Listen(v);
			end
		end);
	};
	return setmetatable(_event, _mt)
end


function remote:RegisterChildren(instance)
	assert(server, "RegisterChildren can only be called from the server.");
	local parent = instance or getfenv(0).script; -- getfenv~!!!!111 dragunss!!!~~!~!~!~!1`1`1`
	if (parent) then
		for i,child in pairs(parent:GetChildren()) do
			if (child:IsA("RemoteEvent")) then
				remote.internal:CreateEvent(child.Name, child);
			elseif (child:IsA("RemoteFunction")) then
				remote.internal:CreateFunction(child.Name, child);
			end
		end
	end
end


function remote.internal:CreateFunctionMetatable(instance)
	local _event = {
		Instance = instance;
	};
	local _mt = {
		__index = (function(self, i)
			if (rawget(remote.func,i) ~= nil) then
				return rawget(remote.func,i);
			else
				return rawget(self, i);
			end
		end);
		__newindex = (function(self, i, v)
			if (i == 'OnCallback' and type(v) == 'function') then
				self:Callback(v);
			end
		end);
		
		__call = (function(self,...)
			if (server) then
				return self:CallPlayer(...);
			else
				return self:CallServer(...);
			end
		end)
	};
	return setmetatable(_event, _mt)
end



--======================================= R E M O T E    E V E N T ========================================



function remote.internal:CreateEvent(name, instance)
	
	local instance = instance or eventStorage:FindFirstChild(name) or Instance.new("RemoteEvent", eventStorage);
	instance.Name = name;
	instance.Parent = eventStorage;
	
	local _event = remote.internal:CreateEventMetatable(instance);
	
	remote.Events[name] = _event;
	
	return _event;
end


function remote:GetEventFromInstance(instance)
	local _event = remote.internal:CreateEventMetatable(instance);
	return _event;
end


function remote.internal:GetEvent(name)
	local ev =  (eventStorage:FindFirstChild(name));
	
	return ev;
end

--- Creates an event 
-- @param string name - the name of the event.
function remote:CreateEvent(name)
	if (not server) then
		warn("[ModRemote] CreateEvent should be used by the server."); end
	
	return remote.internal:CreateEvent(name);
end


--- Gets an event if it exists, otherwise errors
-- @param string name - the name of the event.
function remote:GetEvent(name)
		
	assert(type(name) == 'string', "[ModRemote] GetEvent - Name must be a string");
	assert(eventStorage:FindFirstChild(name),"[ModRemote] GetEvent - Event " .. name .. " not found, create it using CreateEvent.");
	
	local _event = remote.Events[name];
	if (_event) then
		return _event;
	else
		local _ev = remote.internal:CreateEvent(name);
		return _ev;
	end
end

do --[[REMOTE EVENT OBJECT METHODS]]
	local remEnv = remote.event;
	
	function remEnv:SendToPlayers(playerList, ...) 
		assert(server, "[ModRemote] SendToPlayers should be called from the Server side.");
		for _, player in pairs(playerList) do
			self.Instance:FireClient(player, ...);
		end	
	end
	
	function remEnv:SendToPlayer(player, ...)  
		assert(server, "[ModRemote] SendToPlayers should be called from the Server side.");
		self.Instance:FireClient(player, ...);
	end
	
	function remEnv:SendToServer(...) 
		assert(client, "SendToServer should be called from the Client side.");
		self.Instance:FireServer(...);
	end
	
	function remEnv:SendToAllPlayers(...) 
				
		
		assert(server, "[ModRemote] SendToPlayers should be called from the Server side.");
		self.Instance:FireAllClients(...);	
	end
	
	function remEnv:Listen(func)
					
		
		if (server) then
			self.Instance.OnServerEvent:connect(func);
		else
			self.Instance.OnClientEvent:connect(func);
		end
	end
	
	function remEnv:Wait()
		if (server) then
			self.Instance.OnServerEvent:wait();
		else
			self.Instance.OnClientEvent:wait();
		end	
	end
	
	function remEnv:GetInstance() 
		return self.Instance; 
	end
	
	function remEnv:Destroy() 
		self.Instance:Destroy();	
	end
end

--====

function remote.internal:GetFunction(name)
	return (functionStorage:FindFirstChild(name));
end


function remote:GetFunctionFromInstance(instance)
			
	
	local _func = remote.internal:CreateFunctionMetatable(instance);
	return _func;
end


function remote.internal:CreateFunction(name, instance)
	
	
	local instance = instance or functionStorage:FindFirstChild(name) or Instance.new("RemoteFunction", functionStorage);
	instance.Name = name;
	instance.Parent = functionStorage;

	local _event = remote.internal:CreateFunctionMetatable(instance);	
	remote.Events[name] = _event;
	
	return _event;
end

--- Gets a function if it exists, otherwise errors
-- @param string name - the name of the function.
function remote:GetFunction(name)
		
	
	assert(type(name) == 'string', "[ModRemote] GetFunction - Name must be a string");
	assert(functionStorage:FindFirstChild(name),"[ModRemote] GetFunction - Function " .. name .. " not found, create it using CreateFunction.");
	
	local _event = remote.Functions[name];
	if (_event) then
		return _event;
	else
		local _ev = remote.internal:CreateFunction(name);
		return _ev;
	end
end

--- Creates a function
-- @param string name - the name of the function.
function remote:CreateFunction(name)
		
	
	if (not server) then
		warn("[ModRemote] CreateFunction should be used by the server."); end
	
	return remote.internal:CreateFunction(name);
end


--======== REMOTE FUNCTION ===========
remote.FuncCache = {};

do -- [[REMOTE FUNCTION OBJECT METHODS ]]
	local remFunc = remote.func;

	function remFunc:CallPlayer(player, ...) 
		
		assert(server, "[ModRemote] CallPlayer should be called from the server side."); 	
		
		local args = {...};
		local attempt, err = pcall(function()
			return self.Instance:InvokeClient(player, unpack(args));
		end);
		
		if (not attempt) then
			warn("[ModRemote] CallPlayer - Failed to recieve response from " .. player.Name);
			return nil;
		end	
	end
	
	function remFunc:CallServerIntl(...) 
		assert(client, "[ModRemote] CallServer should be called from the client side."); 	
		return self.Instance:InvokeServer(...);
	end
	
	function remFunc:Callback(func)
		if (server) then
			self.Instance.OnServerInvoke = func;
		else
			self.Instance.OnClientInvoke = func;
		end	
	end
	
	function remFunc:GetInstance()
		return self.Instance;
	end
	
	function remFunc:Destroy()
		self.Instance:Destroy();
	end
	
	function remFunc:SetClientCache(seconds, useAction)
		
		
		seconds = seconds or 10;
		assert(server, "SetClientCache must be called on the server.");
		local instance = self:GetInstance();
		
		if (seconds == false or seconds < 1) then
			local cache = instance:FindFirstChild("ClientCache");
			if (cache) then
				cache:Destroy();
			end
		else
			local cache = instance:FindFirstChild("ClientCache") or Instance.new("IntValue", instance);
			cache.Name = "ClientCache";
			cache.Value = seconds;
		end
		
		if (useAction) then
			local cache = instance:FindFirstChild("UseActionCaching") or Instance.new("BoolValue", instance);
			cache.Name = "UseActionCaching";
			cache.Value = true;
		else
			local cache = instance:FindFirstChild("UseActionCaching");
			if (cache) then
				cache:Destroy();
			end			
		end
		
	end
	
	function remFunc:ResetClientCache()
				
		
		assert(client, "ResetClientCache must be used on the client.");
		
		local clientCache = self.Instance:FindFirstChild("ClientCache");
		if (clientCache) then
			remote.FuncCache[self.Instance:GetFullName()] = {Expires = 0, Value = nil};
		else
			warn(self.Instance:GetFullName() .. " does not have a cache.");
		end		
	end
	
	function remFunc:CallServer(...)
		local args = {...};
		 
		local clientCache = self.Instance:FindFirstChild("ClientCache");
		if (clientCache) then
			local cacheName = self.Instance:FindFirstChild("UseActionCaching") and self.Instance:GetFullName() .. "-" .. tostring(args[1]) or self.Instance:GetFullName();
			
 			local cached = remote.FuncCache[cacheName];
			if (cached and os.time() < cached.Expires) then
				
				return unpack(cached.Value);
			else
				
				local newVal = {self:CallServerIntl(unpack(args))};
				remote.FuncCache[cacheName] = {Expires = os.time() + clientCache.Value, Value = newVal};
				return unpack(newVal);
			end
		else
			return self:CallServerIntl(...);
		end
	end
end

local remoteMT = {
	__call = (function(self, ...)
		assert(server, "ModRemote can only be called from server.");
		
		local args = {...};
		if (#args > 0) then
			for _, dir in pairs(args) do
				remote:RegisterChildren(dir);
			end
		else
			remote:RegisterChildren();
		end
		
		return self;
	end)
};

return setmetatable(remote, remoteMT);
