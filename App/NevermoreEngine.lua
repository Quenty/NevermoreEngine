-- see readme.md
-- @author Quenty

local NevermoreEngine 
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local MarketplaceService  = game:GetService('MarketplaceService')
local TestService         = game:GetService('TestService')
local ServerStorage      
local ServerScriptService

local Configuration = {	
	Blacklist              = "128527647,129834516"; -- Ban list
	ClientName             = "NevermoreClient";
	CustomCharacters       = false; -- When enabled, allows the client to set Player.Character itself.
	IsClient               = script.Parent ~= nil;
	ReplicatedPackageName  = "NevermoreResources";
	SoloTestMode           = (game:FindService("NetworkServer") == nil and game.PlaceId == 0); -- Are we testing in solo test mode?
	SplashScreen           = true; -- Should a splashscreen be rendered?
	CharacterRespawnTime   = 0.5; -- How long does it take for characters to respawn? Only kept updated on the server-side.
	DataSteamName          = "NevermoreDataStream";
	NevermoreRequestPrefix = "NevermoreEngineRequest"; -- For network requests, what should it prefix it as?
	EnableFiltering        = false; -- Set Workspace.FilteringEnabled
}
Configuration.IsServer = not Configuration.IsClient

if Configuration.EnableFiltering then
	Workspace.FilteringEnabled = true
	print("**** Workspace.FilteringEnabled is enabled")
end

if Configuration.SoloTestMode then
	Configuration.PrintHeader = "[NevermoreEngineSolo] - "
else
	print(game:FindService("NetworkServer") == nil, game.PlaceId == 0)
	if Configuration.IsServer then
		Configuration.PrintHeader = "[NevermoreEngine] - "
	else
		Configuration.PrintHeader = "[NevermoreEngineLocal] - "
	end
end

Players.CharacterAutoLoads = false;

local RbxUtility = LoadLibrary("RbxUtility")

if not Configuration.IsClient then
	ServerStorage       = game:GetService("ServerStorage")
	ServerScriptService = game:GetService("ServerScriptService")
end

NevermoreEngine = {}

-- DEBUG -- 
-- print("script.Parent == " .. tostring(script.Parent))
-- print(Configuration.PrintHeader .. "Nevermore is Loadingg.")

-----------------------
-- UTILITY FUNCTIONS --
-----------------------
local function Warn(WarningText)
	--- Used to yell at the player
	-- @param WarningText The text to warn with.

	Spawn(function()
		--TestService:Warn(false, WarningText)
		error("[WARNING] - " .. WarningText, 2)
	end)
end

local function WaitForChild(Parent, Name)
	--- Yields until a child is added. Warns after 5 seconds of yield.
	-- @param Parent The parent to wait for the child of
	-- @param Name The name of the child
	-- @return The child found

	local Child = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned = false;
	while not Child do
		wait(0)
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + 5 <= tick() then
			Warned = true;
			Warn(Configuration.PrintHeader .. " " .. Name .. " has not replicated after 5 seconds, may not be able to execute Nevermore.")
		end
	end
	return Child
end

local function pack(...)
	--- Packs a tuple into a table and returns it
	-- @return The packed tuple

	return {...}
end

------------------------------
-- Load Dependent Resources --
------------------------------
local NevermoreContainer, ModulesContainer, ApplicationContainer, ReplicatedPackage, DataStreamContainer, EventStreamContainer
do
	local function LoadResource(Parent, ResourceName)
		--- Loads a resource or errors. Makes sure that a resource is available.
		-- @param Parent The parent of the resource to load
		-- @param ResourceName The name of the resource attempting to load

		local Resource = Parent:FindFirstChild(ResourceName)
		if not Resource then
			error(Configuration.PrintHeader .. "Failed to load required resource '" .. ResourceName .. "', expected at '" .. Parent:GetFullName() .. "'", 2)
			return nil
		else
			return Resource
		end
	end

	if Configuration.IsServer then
		-- Load Resources --

		NevermoreContainer          = LoadResource(ServerScriptService, "Nevermore")
		ModulesContainer            = LoadResource(NevermoreContainer, "Modules")
		ApplicationContainer        = LoadResource(NevermoreContainer, "App")

		-- Create the replicated package --
		ReplicatedPackage = ReplicatedStorage:FindFirstChild(Configuration.ReplicatedPackageName)
		if not ReplicatedPackage then
			ReplicatedPackage            = Instance.new("Backpack")
			ReplicatedPackage.Name       = Configuration.ReplicatedPackageName
			ReplicatedPackage.Parent     = ReplicatedStorage
			ReplicatedPackage.Archivable = false;		
		end
		ReplicatedPackage:ClearAllChildren()

		DataStreamContainer = ReplicatedPackage:FindFirstChild("DataStreamContainer")
		if not DataStreamContainer then
			DataStreamContainer            = Instance.new("Backpack")
			DataStreamContainer.Name       = "DataStreamContainer"
			DataStreamContainer.Parent     = ReplicatedPackage
			DataStreamContainer.Archivable = false;
		end

		EventStreamContainer = ReplicatedPackage:FindFirstChild("EventStreamContainer")
		if not EventStreamContainer then
			EventStreamContainer            = Instance.new("Backpack")
			EventStreamContainer.Name       = "EventStreamContainer"
			EventStreamContainer.Parent     = ReplicatedPackage
			EventStreamContainer.Archivable = false;
		end
	
		DataStreamContainer:ClearAllChildren()		
	else
		-- Handle replication for clients

		-- Load Resource Package --
		ReplicatedPackage    = WaitForChild(ReplicatedStorage, Configuration.ReplicatedPackageName)
		DataStreamContainer  = WaitForChild(ReplicatedPackage, "DataStreamContainer")
		EventStreamContainer = WaitForChild(ReplicatedPackage, "EventStreamContainer")
	end
end

--print(Configuration.PrintHeader .. "Loaded dependent resources module")
------------------------
-- RESOURCE MANAGMENT --
------------------------
local NetworkingRemoteFunction
local ResouceManager = {} do
	--- Handles resource loading and replication
	local ResourceCache = {}
	local MainResourcesServer, MainResourcesClient

	if Configuration.IsServer then
		MainResourcesServer = {} -- Resources to load.
		MainResourcesClient = {}
	else
		MainResourcesClient = {}
	end

	local function GetDataStreamObject(Name, Parent)
		--- Products a new DataStream object if it doesn't already exist, otherwise
		--  return's the current datastream.
		-- @param Name The Name of the DataStream
		-- @param [Parent] The parent to add to

		Parent = Parent or DataStreamContainer

		local DataStreamObject = Parent:FindFirstChild(Name)
		if not DataStreamObject then
			if Configuration.IsServer then
				DataStreamObject            = Instance.new("RemoteFunction")
				DataStreamObject.Name       = Name;
				DataStreamObject.Archivable = false;
				DataStreamObject.Parent     = Parent
			else
				DataStreamObject = WaitForChild(Parent, Name) -- Client side, we must wait.'
			end
		end
		return DataStreamObject
	end
	ResouceManager.GetDataStreamObject = GetDataStreamObject

	local function GetEventStreamObject(Name, Parent)
		--- Products a new EventStream object if it doesn't already exist, otherwise
		--  return's the current datastream. 
		-- @param Name The Name of the EventStream
		-- @param [Parent] The parent to add to

		Parent = Parent or EventStreamContainer

		local DataStreamObject = Parent:FindFirstChild(Name)
		if not DataStreamObject then
			if Configuration.IsServer then
				DataStreamObject            = Instance.new("RemoteEvent")
				DataStreamObject.Name       = Name;
				DataStreamObject.Archivable = false;
				DataStreamObject.Parent     = Parent
			else
				DataStreamObject = WaitForChild(Parent, Name) -- Client side, we must wait.
			end
		end
		return DataStreamObject
	end
	ResouceManager.GetEventStreamObject = GetEventStreamObject

	if Configuration.IsClient then
		NetworkingRemoteFunction = WaitForChild(DataStreamContainer, Configuration.DataSteamName)
	else
		NetworkingRemoteFunction = GetDataStreamObject(Configuration.DataSteamName, DataStreamContainer)
	end

	local function IsMainResource(Item)
		--- Finds out if an Item is considered a MainResource
		-- @return Boolean is a main resource

		if Item:IsA("Script") then
			if not Item.Disabled then
				-- If an item is not disabled, then it's disabled, but yell at 
				-- the user.

				if Item.Name:lower():match("\.main$") == nil then
					error(Configuration.PrintHeader .. Item:GetFullName() .. " is not disabled, and does not end with .Main.")
				end

				return true
			end
			return Item.Name:lower():match("\.main$") ~= nil -- Check to see if it ends
			                                                  -- in .main, ignoring caps
		else
			return false;
		end
	end

	local function GetLoadablesForServer()
		--- Get's the loadable items for the server, that should be insta-ran
		-- @return A table full of the resources to be loaded

		return MainResourcesServer
	end
	ResouceManager.GetLoadablesForServer = GetLoadablesForServer

	local function GetLoadablesForClient()
		--- Get's the loadable items for the Client, that should be insta-ran
		-- @return A table full of the resources to be loaded
		
		return MainResourcesClient
	end
	ResouceManager.GetLoadablesForClient = GetLoadablesForClient

	local PopulateResourceCache
	if Configuration.IsClient then
		function PopulateResourceCache()
			--- Populates the resource cache. For the client.
			-- Should only be called once. Used internally. 

			local Populate
			function Populate(Parent)
				for _, Item in pairs(Parent:GetChildren()) do
					if (Item:IsA("LocalScript") or Item:IsA("ModuleScript")) then
						ResourceCache[Item.Name] = Item;

						if IsMainResource(Item) then
							MainResourcesClient[#MainResourcesClient+1] = Item;
						end
					else
						Populate(Item)
					end
				end
			end

			Populate(ReplicatedPackage)
		end
	else -- Configuration.IsServer then
		function PopulateResourceCache()
			--- Populates the resource cache. For the server. Also populates
			-- the replication cache. Used internally. 
			-- Should be called once. 

			--[[local NevermoreModule = script:Clone()
			NevermoreModule.Archivable = false;
			NevermoreModule.Parent = ReplicatedStorage--]]

			local Populate
			function Populate(Parent)
				for _, Item in pairs(Parent:GetChildren()) do
					if Item:IsA("Script") or Item:IsA("ModuleScript") then -- Will catch LocalScripts as they inherit from script
						if ResourceCache[Item.Name] then
							error(Configuration.PrintHeader .. "There are two Resources called '" .. Item:GetFullName() .."'. Nevermore failed to populate the cache..", 2)
						else
							if Item:IsA("LocalScript") or Item:IsA("ModuleScript") then
								-- Clone the item into the replication packet for
								-- replication. However, we do not clone server scripts.

								local ItemClone      = Item:Clone()
								ItemClone.Archivable = false;
								ItemClone.Parent     = ReplicatedPackage

								if Item:IsA("ModuleScript") then
									ResourceCache[Item.Name] = ItemClone;
								elseif IsMainResource(Item) then
									MainResourcesClient[#MainResourcesClient+1] = Item
								end
							else -- Do not replicate local scripts
								if IsMainResource(Item) then
									MainResourcesServer[#MainResourcesServer+1] = Item
								end
								ResourceCache[Item.Name] = Item								
							end
						end					
					else
						Populate(Item)
						--error(Configuration.PrintHeader .. "The resource '" .. Item:GetFullName() .."' is not a LocalScript, Script, or ModuleScript, and cannot be included. Nevermore failed to populate the cache..", 2)
					end
				end
			end

			Populate(ModulesContainer)
		end
	end
	ResouceManager.PopulateResourceCache = PopulateResourceCache

	local function GetResource(ResourceName)
		--- This script will load another script, module script, et cetera, if it is 
		--  available.  It will return the resource in question.
		-- @param ResourceName The name of the resource 
		-- @return The found resource

		local ResourceFound = ResourceCache[ResourceName]

		if ResourceFound then
			return ResourceFound
		else
			error(Configuration.PrintHeader .. "The resource '" .. ResourceName .. "' does not exist, cannot load", 2)
		end
	end
	ResouceManager.GetResource = GetResource

	local function LoadScript(ScriptName)
		--- Runs a script, and can be called multiple times if the script is not
		--  a modular script. 
		-- @param ScriptName The name of the script to load.
		
		local ScriptToLoad = GetResource(ScriptName)
		if ScriptToLoad and ScriptToLoad:IsA("Script") then
			local NewScript = ScriptToLoad:Clone()
			NewScript.Disabled = true;

			--[[if Configuration.SoloTestMode then
				if NewScript:IsA("LocalScript") then
					NewScript.Parent = Players.LocalPlayer:FindFirstChild("PlayerGui")
				else
					NewScript.Parent = script;
				end
			else
				NewScript.Parent = script;
			end--]]
			if Configuration.IsServer then
				NewScript.Parent = NevermoreContainer;
			else
				NewScript.Parent = Players.LocalPlayer:FindFirstChild("Backpack")
			end

			Spawn(function()
				wait(0)
				NewScript.Disabled = false;
			end)
		else
			error(Configuration.PrintHeader .. "The script '" .. ScriptName .. "' is a '".. (ScriptToLoad and ScriptToLoad.ClassName or "nil value") .. "' and cannot be loaded", 2)
		end
	end
	ResouceManager.LoadScript = LoadScript

	if Configuration.IsServer then
		local function LoadScriptOnClient(Script, Client)
			--- Runs a script on the client. Used internally.
			-- @param Script The script to load. Should be a script object
			-- @param Client The client to run the script on. Should be a Player
			--               object

			if Script and Script:IsA("LocalScript") then
				local NewScript = Script:Clone()
				NewScript.Disabled = true;
				NewScript.Parent = Client:FindFirstChild("Backpack")

				Spawn(function()
					wait(0)
					NewScript.Disabled = false;
				end)
			else
				error(Configuration.PrintHeader .. "The script '" .. tostring(Script) .. "' is a '" .. (Script and Script.ClassName or "nil value") .. "' and cannot be loaded", 2)
			end
		end
		ResouceManager.LoadScriptOnClient = LoadScriptOnClient

		local function ExecuteExecutables()
			--- Executes all the executable scripts on the server.

			for _, Item in pairs(GetLoadablesForServer()) do
				LoadScript(Item.Name)
			end
		end
		ResouceManager.ExecuteExecutables = ExecuteExecutables
	end

	local NativeImports

	local function ImportLibrary(LibraryDefinition, Environment, Prefix)
		--- Imports a library into a given environment, potentially adding a PreFix 
		--  into any of the values of the library,
		--  incase that's wanted. :)
		-- @param LibraryDefinition Table, the libraries definition
		-- @param Environment Another table, probably received by getfenv() in Lua 5.1, and __ENV in Lua 5.2
		-- @Param [Prefix] Optional string that will be prefixed to each function imported into the environment.

		if type(LibraryDefinition) ~= "table" then
			error(Configuration.PrintHeader .. "The LibraryDefinition argument must be a table, got '" .. tostring(LibraryDefinition) .. "'", 2)
		elseif type(Environment) ~= "table" then
			error(Configuration.PrintHeader .. "The Environment argument must be a table, got '" .. tostring(Environment) .. "'", 2)
		else
			Prefix = Prefix or "";

			for Name, Value in pairs(LibraryDefinition) do
				if Environment[Prefix .. Name] == nil and not NativeImports[Name] then
					Environment[Prefix .. Name] = LibraryDefinition[Name]
				elseif not NativeImports[Name] then
					error(Configuration.PrintHeader .. "Failed to import function '" .. (Prefix .. Name) .. "' as it already exists in the environment", 2)
				end
			end
		end
	end
	ResouceManager.ImportLibrary = ImportLibrary

	-- List of functions to import into each library. In this case, only the 
	-- environmental import functions and added to each library. 
	NativeImports = {
		import = ImportLibrary;
		Import = ImportLibrary;
	}

	local function LoadLibrary(LibraryName)
		--- Load's a modular script and packages it as a library. 
		-- @param LibraryName A string of the resource that ist the LibraryName

		-- print(Configuration.PrintHeader .. "Loading Library " .. LibraryName)

		local ModularScript = GetResource(LibraryName)

		if ModularScript then
			if ModularScript:IsA("ModuleScript") then
				-- print(Configuration.PrintHeader .. "Loading Library " .. ModularScript:GetFullName())
				local LibraryDefinition = require(ModularScript)

				if type(LibraryDefinition) == "table" then
					-- Import native definitions
					for Name, Value in pairs(NativeImports) do
						if LibraryDefinition[Name] == nil then
							LibraryDefinition[Name] = Value
						end
					end
				else
					error(Configuration.PrintHeader .. " Library '" .. LibraryName .. "' did not return a table, returned a '" .. type(LibraryDefinition) .. "' value, '" .. tostring(LibraryDefinition) .. "'")
				end

				return LibraryDefinition
			else
				error(Configuration.PrintHeader .. " The resource " .. LibraryName 
					.. " is not a ModularScript, as expected, it is a " 
					.. ModularScript.ClassName, 2
				)
			end
		else
			error(Configuration.PrintHeader .. " Could not identify a library known as '" .. LibraryName .. "'", 2)
		end
	end
	ResouceManager.LoadLibrary = LoadLibrary
end

--print(Configuration.PrintHeader .. "Loaded resource manager module")

-----------------------------
-- NETWORKING STREAM SETUP --
-----------------------------
local Network = {} -- API goes in here
--[[
Contains the following API:

Network.GetDataStream
Network.GetDataStream

--]]
do
	--- Handles networking and PlayerLoading
	local DataStreamMain
	local GetDataStream
	local DataStreamCache = {}
	-- setmetatable(DataStreamCache, {__mode = "v"});

	local function GetCachedDataStream(RemoteFunction)
		--- Creates a datastream filter that will take requests and 
		--  filter them out. 
		-- @param RemoteFunction A remote function to connect to

		-- Execute on the server:
		--- Execute ( Player Client , [...] )
		-- Execute on the client:
		--- Execute ( [...] )
		if DataStreamCache[RemoteFunction] then
			if Configuration.IsClient then
				DataStreamCache[RemoteFunction].ReloadConnection()
			end
			return DataStreamCache[RemoteFunction]
		else
			local DataStream = {}
			local RequestTagDatabase = {}

			-- Set request handling, for solo test mode. The problem here is that Server and Client scripts share the same
			-- code base, because both load the same engine in replicated storage. 
			local function Send(...)
				-- print(Configuration.PrintHeader .. " Sending SoloTestMode")
				-- print(...)

				local Arguments = {...}
				local PossibleClient = Arguments[1]
				if PossibleClient and type(PossibleClient) == "userdata" and PossibleClient:IsA("Player") then
					local Request = Arguments[2]
					if type(Request) == "string" then 
						local OtherArguments = {}
						for Index=3, #Arguments do
							OtherArguments[#OtherArguments+1] = Arguments[Index]
						end

						return RemoteFunction:InvokeClient(PossibleClient, Request:lower(), unpack(OtherArguments))
					else
						error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
						return nil
					end
				elseif type(PossibleClient) == "string" then
					local Request = PossibleClient

					if type(Request) == "string" then 
						local OtherArguments = {}
						for Index=2, #Arguments do
							OtherArguments[#OtherArguments+1] = Arguments[Index]
						end
						
						-- print("Invoke server")
						return RemoteFunction:InvokeServer(Request:lower(), unpack(OtherArguments))
					else
						error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
						return nil
					end
				else
					error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request))
				end
			end

			local function SpawnSend(...)
				--- Sends the data, but doesn't wait for a response or return one. 

				local Data = {...}
				Spawn(function()
					Send(unpack(Data))
				end)
			end

			if Configuration.IsServer or Configuration.SoloTestMode then
				function RemoteFunction.OnServerInvoke(Client, Request, ...)
					--- Handles incoming requests
					-- @param Client The client the request is being sent to
					-- @param Request The request string that is being sent
					-- @param [...] The extra parameters of the request
					-- @return The results, if successfully executed

					if type(Request) == "string" then 
						-- print(Configuration.PrintHeader .. "Server request received")
						-- print(...)

						if Client == nil then
							if Configuration.SoloTestMode then
								Client = Players.LocalPlayer
							else
								error(Configuration.PrintHeader .. "No client provided")
							end
						end

						local RequestExecuter = RequestTagDatabase[Request:lower()]
						local RequestArguments = {...}
						if RequestExecuter then
							--[[local Results
							Results = pack(RequestExecuter(Client, unpack(RequestArguments)))
							return unpack(Results)--]]

							return RequestExecuter(Client, unpack(RequestArguments))
						else
							-- Warn(Configuration.PrintHeader .. "Unregistered request called, request tag '" .. Request .. "'.")
							return nil
						end
					else
						error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
						return nil
					end
				end

				if not Configuration.SoloTestMode then
					function Send(Client, Request, ...)
						--- Sends a request to the client
						-- @param Client Player object, the client to send the request too
						-- @param Request the request to send it too.
						-- @return The results / derived data from the feedback

						-- DEBUG --
						--print(Configuration.PrintHeader .. " Sending Request '" .. Request .. "' to Client '" .. tostring(Client) .. "'.")
						
						return RemoteFunction:InvokeClient(Client, Request:lower(), ...)
					end
				end
			end	
			if Configuration.IsClient or Configuration.SoloTestMode then -- Handle clientside streaming.
				-- We do this for solotest mode, to connect the OnClientInvoke and the OnServerInvoke 
				

				function DataStream.ReloadConnection()
					--- Reloads the OnClientInvoke event, which gets disconnected when scripts die on the client.
					-- However, this fixes it, because those scripts have to request the events every time. 

					--[[
						-- Note: When using RemoteFunctions, in a module script, on ROBLOX, and you load the ModuleScript
						with a LOCAL SCRIPT. When this LOCAL SCRIPT is killed, your OnClientInvoke function will be GARBAGE
						COLLECTED. You must thus, reload the OnClientInvoke function everytime the local script is loaded.

					--]]

					function RemoteFunction.OnClientInvoke(Request, ...)
						--- Handles incoming requests
						-- @param Request The request string that is being sent
						-- @param [...] The extra parameters of the request
						-- @return The results, if successfully executed


						if type(Request) == "string" then 
							-- print(Configuration.PrintHeader .. "Client request received")
							-- print(...)

							local RequestExecuter = RequestTagDatabase[Request:lower()]
							local RequestArguments = {...}
							if RequestExecuter then
								Spawn(function()
									RequestExecuter(unpack(RequestArguments))
								end)
							else
								-- Warn(Configuration.PrintHeader .. "Unregistered request called, request tag '" .. Request .. "'.")
							end
						else
							error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
						end
					end
				end

				--- Reload the initial connection.
				DataStream.ReloadConnection()

				if not Configuration.SoloTestMode then
					function Send(Request, ...)
						--- Sends a request to the server
						-- @param Request the request to send it too.
						-- @return The results / derived data from the feedback

						return RemoteFunction:InvokeServer(Request:lower(), ...)
					end
				end
			end
			DataStream.Send = Send
			DataStream.send = Send
			DataStream.Call = Send
			DataStream.call = Send
			DataStream.SpawnSend = SpawnSend
			DataStream.spawnSend = SpawnSend
			DataStream.spawn_send = SpawnSend

			local function RegisterRequestTag(RequestTag, Execute)
				--- Registers a request when sent
				-- @param RequestTag The tag that is expected
				-- @param Execute The functon to execute. It will be sent
				--                all remainig arguments.
				-- Request tags are not case sensitive

				--if not RequestTagDatabase[RequestTag:lower()] then
				RequestTagDatabase[RequestTag:lower()] = Execute;
				--else
					--error(Configuration.PrintHeader .. "The request tag " .. RequestTag:lower() .. " is already registered.")
				--end
			end
			DataStream.RegisterRequestTag = RegisterRequestTag
			DataStream.registerRequestTag = RegisterRequestTag

			local function UnregisterRequestTag(RequestTag)
				--- Unregisters the request from the tag
				-- @param RequestTag String the tag to reregister
				RequestTagDatabase[RequestTag:lower()] = nil;
			end
			DataStream.UnregisterRequestTag = UnregisterRequestTag
			DataStream.unregisterRequestTag = UnregisterRequestTag

			DataStreamCache[RemoteFunction] = DataStream
			return DataStream
		end
	end

	local function GetCachedEventStream(RemoteEvent)
		-- Like GetCachedDataStream, but with RemoteEvents
		-- @param RemoteEvent The remote event to get the stream for. 

		if DataStreamCache[RemoteEvent] then
			if Configuration.IsClient then
				DataStreamCache[RemoteEvent].ReloadConnection()
			end
			return DataStreamCache[RemoteEvent]
		else
			local DataStream = {}
			local RequestTagDatabase = {}

			local function Fire(...)
				local Arguments = {...}
				local PossibleClient = Arguments[1]
				if PossibleClient and type(PossibleClient) == "userdata" and PossibleClient:IsA("Player") then
					local Request = Arguments[2]
					if type(Request) == "string" then 
						local OtherArguments = {}
						for Index=3, #Arguments do
							OtherArguments[#OtherArguments+1] = Arguments[Index]
						end

						return RemoteEvent:FireClient(PossibleClient, Request:lower(), unpack(OtherArguments))
					else
						error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
						return nil
					end
				elseif type(PossibleClient) == "string" then
					local Request = PossibleClient

					if type(Request) == "string" then 
						local OtherArguments = {}
						for Index=2, #Arguments do
							OtherArguments[#OtherArguments+1] = Arguments[Index]
						end
						
						return RemoteEvent:FireServer(Request:lower(), unpack(OtherArguments))
					else
						error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
						return nil
					end
				else
					error(Configuration.PrintHeader .. "Invalid request DataType to the DataStream, DataType '" .. type(Request))
				end
			end

			local function FireAllClients(Request, ...)
				if type(Request) == "string" then
					RemoteEvent:FireAllClients(Request, ...)
				else
					error(Configuration.PrintHeader .. "Invalid reques DataType  to the DataStream, DataType '" .. type(Request))
				end
			end

			if Configuration.IsServer or Configuration.SoloTestMode then
				RemoteEvent.OnServerEvent:connect(function(Client, Request, ...)
					--- Handles incoming requests
					-- @param Client The client the request is being sent to
					-- @param Request The request string that is being sent
					-- @param [...] The extra parameters of the request
					-- @return The results, if successfully executed

					if type(Request) == "string" then 
						if Client == nil then
							if Configuration.SoloTestMode then
								Client = Players.LocalPlayer
							else
								error(Configuration.PrintHeader .. "No client provided")
							end
						end

						local RequestExecuter = RequestTagDatabase[Request:lower()]
						local RequestArguments = {...}
						if RequestExecuter then
							RequestExecuter(Client, unpack(RequestArguments))
						else
							-- Warn(Configuration.PrintHeader .. "Unregistered request called, request tag '" .. Request .. "'.")
						end
					else
						error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
					end
				end)

				if not Configuration.SoloTestMode then
					function Fire(Client, Request, ...)
						--- Sends a request to the client
						-- @param Client Player object, the client to send the request too
						-- @param Request the request to send it too.
						-- @return The results / derived data from the feedback
				
						RemoteEvent:FireClient(Client, Request:lower(), ...)
					end
				end
			end	
			if Configuration.IsClient or Configuration.SoloTestMode then -- Handle clientside streaming.
				-- We do this for solotest mode, to connect the OnClientInvoke and the OnServerInvoke 
				
				local Event 
				function DataStream.ReloadConnection()
					--- Reloads the OnClientInvoke event, which gets disconnected when scripts die on the client.
					-- However, this fixes it, because those scripts have to request the events every time. 

					if Event then
						Event:disconnect()
					end

					Event = RemoteEvent.OnClientEvent:connect(function(Request, ...)
						--- Handles incoming requests
						-- @param Request The request string that is being sent
						-- @param [...] The extra parameters of the request
						-- @return The results, if successfully executed

						if type(Request) == "string" then 
							local RequestExecuter = RequestTagDatabase[Request:lower()]
							local RequestArguments = {...}
							if RequestExecuter then
								Spawn(function()
									RequestExecuter(unpack(RequestArguments))
								end)
							else
								-- Warn(Configuration.PrintHeader .. "Unregistered request called, request tag '" .. Request .. "'.")
							end
						else
							error(Configuration.PrintHeader .. "Invalid request to the DataStream, DataType '" .. type(Request) .. "' received. Resolved into '" .. tostring(Request) .. "'")
						end
					end)
				end

				--- Reload the initial connection.
				DataStream.ReloadConnection()

				if not Configuration.SoloTestMode then
					function Fire(Request, ...)
						--- Sends a request to the server
						-- @param Request the request to send it too.
						-- @return The results / derived data from the feedback

						RemoteEvent:FireServer(Request:lower(), ...)
					end
				end
			end
			DataStream.Fire = Fire
			DataStream.fire = Fire
			DataStream.FireAllClients = FireAllClients
			DataStream.fireAllClients = FireAllClients

			local function RegisterRequestTag(RequestTag, Execute)
				--- Registers a request when sent
				-- @param RequestTag The tag that is expected
				-- @param Execute The functon to execute. It will be sent
				--                all remainig arguments.
				-- Request tags are not case sensitive

				RequestTagDatabase[RequestTag:lower()] = Execute;
			end
			DataStream.RegisterRequestTag = RegisterRequestTag
			DataStream.registerRequestTag = RegisterRequestTag

			local function UnregisterRequestTag(RequestTag)
				--- Unregisters the request from the tag
				-- @param RequestTag String the tag to reregister

				RequestTagDatabase[RequestTag:lower()] = nil;
			end
			DataStream.UnregisterRequestTag = UnregisterRequestTag
			DataStream.unregisterRequestTag = UnregisterRequestTag

			DataStreamCache[RemoteEvent] = DataStream
			return DataStream
		end
	end

	local DataStreamMain = GetCachedDataStream(NetworkingRemoteFunction)

	local function GetDataStream(DataStreamName)
		--- Get's a dataStream channel
		-- @param DataSteamName The channel to log in to. 
		-- @return The main datastream, if no DataSteamName is provided

		if DataStreamName then
			return GetCachedDataStream(ResouceManager.GetDataStreamObject(DataStreamName, DataStreamContainer))
		else
			error("[NevermoreEngine] - Paramter DataStreamName was nil")
		end
	end
	Network.GetDataStream = GetDataStream

	local function GetEventStream(EventStreamName)
		--- Get's an EventStream chanel
		-- @param DataSteamName The channel to log in to. 
		-- @return The main datastream, if no DataSteamName is provided

		if EventStreamName then
			return GetCachedEventStream(ResouceManager.GetEventStreamObject(EventStreamName, EventStreamContainer))
		else
			error("[NevermoreEngine] - Paramter EventStreamName was nil")
		end
	end
	Network.GetEventStream = GetEventStream

	local function GetMainDatastream()
		--- Return's the main datastream, used internally for networking

		return DataStreamMain
	end
	Network.GetMainDatastream = GetMainDatastream

	if Configuration.IsServer then
		local function CheckIfPlayerIsBlacklisted(Player, BlackList)
			--- Checks to see if a player is blacklisted from the server
			-- @param Player The player to check for
			-- @param Blacklist The string blacklist
			-- @return Boolean is blacklisted

			for Id in string.gmatch(BlackList, "%d+") do
				local ProductInformation = (MarketplaceService:GetProductInfo(Id))
				if ProductInformation then
					if string.match(ProductInformation["Description"], Player.Name..";") then
						return true;
					end
				end
			end
			for Name in string.gmatch(BlackList, "[%a%d]+") do
				if Player.Name:lower() == Name:lower() then
					return true;
				end
			end
			return false;
		end

		local function CheckPlayer(player)
			--- Makes sure a player has all necessary components.
			-- @return Boolean If the player has all the right components

			return player and player:IsA("Player") 
				and player:FindFirstChild("Backpack") 
				and player:FindFirstChild("StarterGear")
				-- and player.PlayerGui:IsA("PlayerGui") -- PlayerGui does not replicate to other clients.
		end

		local function CheckCharacter(player)
			--- Make sure that a character has all necessary components
			--  @return Boolean If the player has all the right components

			local character = player.Character;
			return character
				and character:FindFirstChild("Humanoid") 
				and character:FindFirstChild("Torso")
				and character:FindFirstChild("Head")
				and character.Humanoid:IsA("Humanoid")
				and character.Head:IsA("BasePart")
				and character.Torso:IsA("BasePart")
		end

		local function GenerateInitialSplashScreen(Player)
			--- Generates the initial SplashScreen for the player.  
			-- @param Player The player to genearte the SplashScreen in.
			-- @return The generated splashsreen

			local Configuration = {
				BackgroundColor3       = Color3.new(237/256, 236/256, 233/256);       -- Color of background of loading screen.
				AccentColor3           = Color3.new(8/256, 130/256, 83/256);          -- Not used. 
				LogoSize               = 200;
				LogoTexture            = "http://www.roblox.com/asset/?id=129733987";
				LogoSpacingUp          = 70; -- Pixels up from loading frame.
				ParticalOrbitDistance  = 50;                                         -- How far out the particals orbit
			}

			local ScreenGui = Instance.new("ScreenGui", Player:FindFirstChild("PlayerGui"))
			ScreenGui.Name = "SplashScreen";

			local MainFrame = Instance.new('Frame')
				MainFrame.Name             = "SplashScreen";
				MainFrame.Position         = UDim2.new(0, 0, 0, -2);
				MainFrame.Size             = UDim2.new(1, 0, 1, 22); -- Sized ans positioned weirdly because ROBLOX's ScreenGui doesn't cover the whole screen.
				MainFrame.BackgroundColor3 = Configuration.BackgroundColor3;
				MainFrame.Visible          = true;
				MainFrame.ZIndex           = 9;
				MainFrame.BorderSizePixel  = 0;
				MainFrame.Parent           = ScreenGui;

			local ParticalFrame = Instance.new('Frame')
				ParticalFrame.Name            = "ParticalFrame";
				ParticalFrame.Position        = UDim2.new(0.5, -Configuration.ParticalOrbitDistance, 0.7, -Configuration.ParticalOrbitDistance);
				ParticalFrame.Size            = UDim2.new(0, Configuration.ParticalOrbitDistance*2, 0, Configuration.ParticalOrbitDistance*2); -- Sized ans positioned weirdly because ROBLOX's ScreenGui doesn't cover the whole screen.
				ParticalFrame.Visible         = true;
				ParticalFrame.BackgroundTransparency = 1
				ParticalFrame.ZIndex          = 9;
				ParticalFrame.BorderSizePixel = 0;
				ParticalFrame.Parent          = MainFrame;

			local LogoLabel = Instance.new('ImageLabel')
				LogoLabel.Name            = "LogoLabel";
				LogoLabel.Position        = UDim2.new(0.5, -Configuration.LogoSize/2, 0.7, -Configuration.LogoSize/2 - Configuration.ParticalOrbitDistance*2 - Configuration.LogoSpacingUp);
				LogoLabel.Size            = UDim2.new(0, Configuration.LogoSize, 0, Configuration.LogoSize); -- Sized ans positioned weirdly because ROBLOX's ScreenGui doesn't cover the whole screen.
				LogoLabel.Visible         = true;
				LogoLabel.BackgroundTransparency = 1
				LogoLabel.Image           = Configuration.LogoTexture;
				LogoLabel.ZIndex          = 9;
				LogoLabel.BorderSizePixel = 0;
				LogoLabel.Parent          = MainFrame;

			return ScreenGui
		end

		local function DumpExecutables(Player)
			--- Executes all "MainResources" for the player
			-- @param Player The player to load the resources on 

			print(Configuration.PrintHeader .. "Loading executables onto " .. tostring(Player))
			for _, Item in pairs(ResouceManager.GetLoadablesForClient()) do
				ResouceManager.LoadScriptOnClient(Item, Player)
			end
		end

		local function SetupPlayer(Player)
			--- Setups up a player
			-- @param Player The player to setup

			Spawn(function()
				-- Wait for initial load
				while not (Player and Player.Parent) do
					wait(0)
				end

				if Configuration.BlackList and CheckIfPlayerIsBlacklisted(Player, Configuration.BlackList) then
					Player:Kick()
					Warn("Kicked Player " .. Player.Name .. " who was blacklisted")
				else
					local PlayerSplashScreen
					local HumanoidDiedEvent

					local function SetupCharacter()
						--- Setup's up a player's character
						Spawn(function()
							if not Configuration.CustomCharacters then
								if Player and Player.Parent == Players then
									while not (Player.Character 
										and Player.Character:FindFirstChild("Humanoid") 
										and Player.Character.Humanoid:IsA("Humanoid")) 
										and Player.Parent == Players do

										wait(0) -- Wait for the player's character to load
									end

									-- Make sure the player is still in game.
									if Player.Parent == Players then
										if HumanoidDiedEvent then
											HumanoidDiedEvent:disconnect()
											HumanoidDiedEvent = nil
										end
									
										HumanoidDiedEvent = Player.Character.Humanoid.Died:connect(function()
											wait(Configuration.CharacterRespawnTime)
											Player:LoadCharacter()
										end)

										DumpExecutables(Player)
									else
										print(Configuration.PrintHeader .. "is not int he game. Cannot finish load.")
									end
								else
									print(Configuration.PrintHeader .. " is not in the game. Cannot load.")
								end
							end
						end)
					end

					local function LoadSplashScreen()
						--- Load's the splash screen into the player

						if Configuration.SplashScreen then
							PlayerSplashScreen = GenerateInitialSplashScreen(Player)

							if Configuration.SoloTestMode then
								Network.AddSplashToNevermore(NevermoreEngine)
							end
						end
					end

					local function InitialCharacterLoad()
						-- Makes sure the character loads, and sets up the character if it has already loaded

						if not Player.Character then -- Incase the characters do start auto-loading. 
							if PlayerSplashScreen then
								PlayerSplashScreen.Parent = nil;
							end
						
							if Configuration.CustomCharacters then
								Player:LoadCharacter()
								if not Player.Character then
									Player.CharacterAdded:wait()
								end
								Player.Character:Destroy()
							else
								Player:LoadCharacter()
							end

							if PlayerSplashScreen then
								PlayerSplashScreen.Parent = Player.PlayerGui
							end
						else
							SetupCharacter()
						end
					end

					-- WHAT MUST HAPPEN
					-- Character must be loaded at least once
					-- Nevermore must run on the client to get a splash running. However, this can be seen as optinoal. 
					-- Nevermore must load the splash into the player. 

					-- SETUP EVENT FIRST
					Player.CharacterAdded:connect(SetupCharacter)
					InitialCharacterLoad() -- Force load the character, no matter what.
					LoadSplashScreen()
				end
			end)
		end

		local function ConnectPlayers()
			--- Connects all the events and adds players into the system. 

			-- Setup all the players that joined...
			for _, Player in pairs(game.Players:GetPlayers()) do
				SetupPlayer(Player)
			end

			-- And when they are added...
			Players.PlayerAdded:connect(function(Player)
				SetupPlayer(Player)
			end)
		end
		Network.ConnectPlayers = ConnectPlayers
	end
	if Configuration.IsClient or Configuration.SoloTestMode then 
		-- Setup the Splash Screen.
		-- However, in SoloTestMode, we need to setup the splashscreen in the
		-- replicated storage module, which is technically the server module. 

		local function AnimateSplashScreen(ScreenGui)
			--- Creates a Windows 8 style loading screen, finishing the loading animation
			-- of pregenerated spash screens.
			-- @param ScreenGui The ScreenGui generated by the splash initiator. 

			-- Will only be called if SpashScreens are enabled. 

			local Configuration = {
				OrbitTime              = 5;                                           -- How long the orbit should last.
				OrbitTimeBetweenStages = 0.5;
				Texture                = "http://www.roblox.com/asset/?id=129689248"; -- AssetId of orbiting object (Decal)
				ParticalOrbitDistance  = 50;                                         -- How far out the particals orbit
				ParticalSize           = 10;                                          -- How big the particals are, probably should be an even number..
				ParticalCount          = 5;                                           -- How many particals to generate
				ParticleSpacingTime    = 0.25;                                         -- How long to wait between earch partical before releasing the next one
			}

			local Splash = {}

			local IsActive = true;
			local MainFrame = ScreenGui.SplashScreen
			local ParticalFrame = MainFrame.ParticalFrame
			local ParticalList = {}

			local function Destroy()
				-- Can be called to Destroy the SplashScreen. Will have the Alias
				-- ClearSplash in NevermoreEngine

				IsActive = false;
				ScreenGui:Destroy()
			end
			Splash.Destroy = Destroy

			Spawn(function()
				if IsActive then
					local function MakePartical(Parent, RotationRadius, Size, Texture)
						-- Creates a partical that will circle around the center of it's Parent.  
						-- RotationRadius is how far away it orbits
						-- Size is the size of the ball...
						-- Texture is the asset id of the texture to use... 

						-- Create a new ImageLabel to be our rotationg partical
						local Partical = Instance.new("ImageLabel")
							Partical.Name                   = "Partical";
							Partical.Size                   = UDim2.new(0, Size, 0, Size);
							Partical.BackgroundTransparency = 1;
							Partical.Image                  = Texture;
							Partical.BorderSizePixel        = 0;
							Partical.ZIndex                 = 10;
							Partical.Parent                 = Parent;
							Partical.Visible                = false;

						local ParticalData = {
							Frame          = Partical;
							RotationRadius = RotationRadius;
							StartTime      = math.huge;
							Size           = Size;
							SetPosition    = function(ParticalData, CurrentPercent)
								-- Will set the position of the partical relative to CurrentPercent.  CurrentPercent @ 0 should be 0 radians.

								local PositionX = math.cos(math.pi * 2 * CurrentPercent) * ParticalData.RotationRadius
								local PositionY = math.sin(math.pi * 2 * CurrentPercent) * ParticalData.RotationRadius
								ParticalData.Frame.Position = UDim2.new(0.5 + PositionX/2,  -ParticalData.Size/2, 0.5 + PositionY/2, -ParticalData.Size/2)
								--ParticalData.Frame:TweenPosition(UDim2.new(0.5 + PositionX/2,  -ParticalData.Size/2, 0.5 + PositionY/2, -ParticalData.Size/2), "Out", "Linear", 0.03, true)
							end;
						}

						return ParticalData;
					end

					local function EaseOut(Percent, Amount)
						-- Just return's the EaseOut smoothed out percentage 

						return -(1 - Percent^Amount) + 1
					end

					local function EaseIn(Percent, Amount)
						-- Just return's the Easein smoothed out percentage 

						return Percent^Amount
					end

					local function EaseInOut(Percent, Amount)
						-- Return's a smoothed out percentage, using in-out.  'Amount' 
						-- is the powered amount (So 2 would be a quadratic EaseInOut, 
						-- 3 a cubic, and so forth.  Decimals supported)

						if Percent < 0.5 then
							return ((Percent*2)^Amount)/2
						else
							return (-((-(Percent*2) + 2)^Amount))/2 + 1
						end
					end

					local function GetFramePercent(Start, Finish, CurrentPercent)
						-- Return's the  relative percentage to the overall 
						-- 'CurrentPercentage' which ranges from 0 to 100; So in one 
						-- case, 0 to 0.07, at 50% would be 0.035;

						return ((CurrentPercent - Start) / (Finish - Start))
					end

					local function GetTransitionedPercent(Origin, Target, CurrentPercent)
						-- Return's the Transitional percentage (How far around the 
						-- circle the little ball is), when given a Origin ((In degrees)
						-- and a Target (In degrees), and the percentage transitioned 
						-- between the two...)

						return (Origin + ((Target - Origin) * CurrentPercent)) / 360;
					end

					-- Start the beautiful update loop
					
					-- Add / Create particals
					for Index = 1, Configuration.ParticalCount do
						ParticalList[Index] = MakePartical(ParticalFrame, 1, Configuration.ParticalSize, Configuration.Texture)
					end

					local LastStartTime       = 0; -- Last time a partical was started
					local ActiveParticalCount = 0;
					local NextRunTime         = 0 -- When the particals can be launched again...

					while IsActive do
						local CurrentTime = tick();
						for Index, Partical in ipairs(ParticalList) do
							-- Calculate the CurrentPercentage from the time and 
							local CurrentPercent = ((CurrentTime - Partical.StartTime) / Configuration.OrbitTime);

							if CurrentPercent < 0 then 
								if LastStartTime + Configuration.ParticleSpacingTime <= CurrentTime and ActiveParticalCount == (Index - 1) and NextRunTime <= CurrentTime then
									-- Launch Partical...

									Partical.Frame.Visible = true;
									Partical.StartTime     = CurrentTime;
									LastStartTime          = CurrentTime
									ActiveParticalCount    = ActiveParticalCount + 1;

									if Index == Configuration.ParticalCount then
										NextRunTime = CurrentTime + Configuration.OrbitTime + Configuration.OrbitTimeBetweenStages;
									end
									Partical:SetPosition(45/360)
								end
							elseif CurrentPercent > 1 then
								Partical.Frame.Visible = false;
								Partical.StartTime = math.huge;
								ActiveParticalCount = ActiveParticalCount - 1;
							elseif CurrentPercent <= 0.08 then
								Partical:SetPosition(GetTransitionedPercent(45, 145, EaseOut(GetFramePercent(0, 0.08, CurrentPercent), 1.2)))
							elseif CurrentPercent <= 0.39 then
								Partical:SetPosition(GetTransitionedPercent(145, 270, GetFramePercent(0.08, 0.39, CurrentPercent)))
							elseif CurrentPercent <= 0.49 then
								Partical:SetPosition(GetTransitionedPercent(270, 505, EaseInOut(GetFramePercent(0.39, 0.49, CurrentPercent), 1.1)))
							elseif CurrentPercent <= 0.92 then
								Partical:SetPosition(GetTransitionedPercent(505, 630, GetFramePercent(0.49, 0.92, CurrentPercent)))
							elseif CurrentPercent <= 1 then
								Partical:SetPosition(GetTransitionedPercent(630, 760, EaseOut(GetFramePercent(0.92, 1, CurrentPercent), 1.1)))
							end
						end
						wait()
					end
				end
			end)

			return Splash;
		end

		local function SetupSplashScreenIfEnabled()
			--- Sets up the Splashscreen if it's enabled, and returnst he disabling / removing function.
			-- @return The removing function, even if the splashscreen doesn't exist.

			local SplashEnabled = false

			local ScreenGui = Players.LocalPlayer.PlayerGui:FindFirstChild("SplashScreen")
			local SplashScreen
			if Configuration.SplashScreen and ScreenGui then
				SplashEnabled = true
				SplashScreen = AnimateSplashScreen(ScreenGui)
			else
				print(Configuration.PrintHeader .. "Splash Screen could not be found, or is not enabled")
			end

			local function ClearSplash()
				-- print(Configuration.PrintHeader .. "Clearing splash.")

				--- Destroys and stops all animation of the current splashscreen, if it exists.
				if SplashScreen then
					SplashEnabled = false
					SplashScreen.Destroy()
					SplashScreen = nil;
				--else
					--print(Configuration.PrintHeader .. "No splash to clear.")
				end
			end

			local function GetSplashEnabled()
				return SplashEnabled
			end
			
			return ClearSplash, GetSplashEnabled
		end
		-- Network.SetupSplashScreenIfEnabled = SetupSplashScreenIfEnabled

		local function AddSplashToNevermore(NevermoreEngine)
			local ClearSplash, GetSplashEnabled = SetupSplashScreenIfEnabled()

			NevermoreEngine.ClearSplash  = ClearSplash
			NevermoreEngine.clearSplash  = ClearSplash
			NevermoreEngine.clear_splash = ClearSplash

			NevermoreEngine.GetSplashEnabled = GetSplashEnabled
			NevermoreEngine.getSplashEnabled = GetSplashEnabled
			NevermoreEngine.get_splash_enabled = GetSplashEnabled
		end
		Network.AddSplashToNevermore = AddSplashToNevermore
	end


	local function ExecuteCode(Code)
		local Execute, Error = loadstring(Code)
		if Execute then
			local RegularOutput
			local ErrorOutput = ypcall(function()
				RegularOutput = pack(Execute())
			end)
			if type(ErrorOutput) == "string" then
				error(ErrorOutput, 2)
				return nil
			else
				return RegularOutput
			end
		else
			error(Error, 2)
		end
	end

	if Configuration.SoloTestMode then
		function Network.CallClient(Client, Code)
			--- Executes code on the client. Will yield. Client must have required Nevermore for it to run.
			-- @param Client The client to execute the code on
			-- @param Code String of the code to be executed
			-- @return Output

			if Client == Players.LocalPlayer then
				return ExecuteCode(Code)
			else
				error(Configuration.PrintHeader .. "Client was nil/not the local player for call client")
			end
		end

		Network.ExecuteCode = ExecuteCode

	elseif Configuration.IsClient then
		-- Client side networking.

		local function CallServer(Code)
			--- Executes the code on the server. 
			-- @param Code String of the code to be executed. It will yield. 

			return DataStreamMain.Send(Configuration.NevermoreRequestPrefix .. "CallServer", Code)
		end
		Network.CallServer = CallServer

		local function CallClient(Client, Code)
			--- Executes code on the client. Will yield. Routes the request rhrough the server.
			-- @param Client The client to execute the code on
			-- @param Code String of the code to be executed
			-- @return Output

			if Client and Client:IsA("Player") then
				if Code and tostring(Code) then
					return DataStreamMain.Send(Configuration.NevermoreRequestPrefix .. "CallClient", Client, Code)
				else
					error(Configuration.PrintHeader .. " Could not execute Code sent as the code sent as a request was not a string.", 2)
				end
			else
				error(Configuration.PrintHeader .. " Could not send code request because client did not exist.", 2)
			end
		end
		Network.CallClient = CallClient

		-- Setup code to for incoming client requests

		local function ExecuteCodeLocal(Code)
			if type(Code) == "string" then
				ExecuteCode(Code)
			else
				error(Configuration.PrintHeader .. " Could not execute Code sent as the code sent as a request was not a string.", 2)
			end
		end

		DataStreamMain.RegisterRequestTag(Configuration.NevermoreRequestPrefix .. "CallClient", function(Code)
			ExecuteCodeLocal(Code)
		end)
	else
		-- Serverside networking

		local function CallServer(Code, ClientRequesting)
			--- Executes the code on the server.  It will yeild. 
			-- @param [ClientRequesting] The cilent requesting the code. Optional.
			-- @param Code String of the code to be executed
			-- @return The output of the executed code. 

			if type(Code) == "string" then
				ExecuteCode(Code)
			else
				error(Configuration.PrintHeader .. " Could not execute Code sent by '" .. tostring(ClientRequesting) .. "' as the code sent as a request was not a string.", 2)
			end
		end
		Network.CallServer = CallServerf

		DataStreamMain.RegisterRequestTag(Configuration.NevermoreRequestPrefix .. "CallServer", function(Client, Code)
			return CallServer(Code, Client)
		end)

		local function CallClient(Client, Code)
			--- Executes code on the client. Will yield. Client must have required Nevermore for it to run.
			-- @param Client The client to execute the code on
			-- @param Code String of the code to be executed
			-- @return Output

			print(tostring(Client), tostring(Code))

			if type(Code) == "string" then
				if Client and Client:IsA("Player") then
					return DataStreamMain.Send(Client, Configuration.NevermoreRequestPrefix .. "CallClient", Code)
				else
					error(Configuration.PrintHeader .. " Could not send code request because client did not exist.", 2)
					return nil
				end
			else
				error(Configuration.PrintHeader .. " Could not execute Code sent to client '" .. tostring(Client) .. "' as the code sent as a request was not a string.", 2)
				return nil
			end
		end
		Network.CallClient = CallClient

		-- Setup incoming requests for other clients
		DataStreamMain.RegisterRequestTag(Configuration.NevermoreRequestPrefix .. "CallClient", function(Client, ClientToCall, Code)
			print("CallClient from the server came in, ClientToCall = " .. tostring(ClientToCall) .. " Code = " .. tostring(Code))
			return CallClient(ClientToCall, Code)
		end)
	end
end

--print(Configuration.PrintHeader .. "Loaded network module")

-----------------------
-- UTILITY NEVERMORE --
-----------------------
local SetRespawnTime
if Configuration.IsServer then
	local function SetRespawnTime(NewTime)
		--- Sets how long it takes for a character to respawn.
		-- @param NewTime The new time it takes for a character to respawn
		if type(NewTime) == "number" then
			Configuration.CharacterRespawnTime = NewTime
		else
			error(Configuration.PrintHeader .. " Could not set respawn time to '" .. tostring(NewTime) .. "', number expected, got '" .. type(NewTime) .. "'")
		end
	end

	Network.GetMainDatastream().RegisterRequestTag(Configuration.NevermoreRequestPrefix .. "SetRespawnTime", function(Client, NewTime)
		SetRespawnTime(NewTime)
	end)
else
	local function SetRespawnTime(NewTime)
		--- Sends a request to the server to set the respawn time.
		-- @param NewTime The new respawn time.

		DataStreamMain.Send(Configuration.NevermoreRequestPrefix .. "SetRespawnTime", NewTime)
	end
end

--print(Configuration.PrintHeader .. "Loaded Nevermore Utilities")

------------------------
-- INITIATE NEVERMORE --
------------------------

--print(Configuration.PrintHeader .. "Setup splashscreen")

NevermoreEngine.SetRespawnTime          = SetRespawnTime
NevermoreEngine.setRespawnTime          = SetRespawnTime
NevermoreEngine.set_respawn_time        = SetRespawnTime

NevermoreEngine.GetResource             = ResouceManager.GetResource
NevermoreEngine.getResource             = ResouceManager.GetResource
NevermoreEngine.get_resource            = ResouceManager.GetResource

NevermoreEngine.LoadScript              = ResouceManager.LoadScript
NevermoreEngine.loadScript              = ResouceManager.LoadScript
NevermoreEngine.load_script             = ResouceManager.LoadScript

NevermoreEngine.LoadLibrary             = ResouceManager.LoadLibrary
NevermoreEngine.loadLibrary             = ResouceManager.LoadLibrary
NevermoreEngine.load_library            = ResouceManager.LoadLibrary

NevermoreEngine.ImportLibrary           = ResouceManager.ImportLibrary
NevermoreEngine.importLibrary           = ResouceManager.ImportLibrary
NevermoreEngine.import_library          = ResouceManager.ImportLibrary

NevermoreEngine.Import                  = ResouceManager.ImportLibrary
NevermoreEngine.import                  = ResouceManager.ImportLibrary

-- These 2 following are used to get the raw objects. 
NevermoreEngine.GetDataStreamObject     = ResouceManager.GetDataStreamObject
NevermoreEngine.getDataStreamObject     = ResouceManager.GetDataStreamObject
NevermoreEngine.get_data_stream_object  = ResouceManager.GetDataStreamObject

NevermoreEngine.GetEventStreamObject    = ResouceManager.GetEventStreamObject
NevermoreEngine.getEventStreamObject    = ResouceManager.GetEventStreamObject
NevermoreEngine.get_event_stream_object = ResouceManager.GetEventStreamObject

NevermoreEngine.GetDataStream           = Network.GetDataStream
NevermoreEngine.getDataStream           = Network.GetDataStream
NevermoreEngine.get_data_stream         = Network.GetDataStream

NevermoreEngine.GetEventStream          = Network.GetEventStream
NevermoreEngine.getEventStream          = Network.GetEventStream
NevermoreEngine.get_event_stream        = Network.GetEventStream

NevermoreEngine.CallServer              = Network.CallServer
NevermoreEngine.CallServer              = Network.CallServer
NevermoreEngine.CallServer              = Network.CallServer

NevermoreEngine.CallClient              = Network.CallClient
NevermoreEngine.callClient              = Network.CallClient
NevermoreEngine.call_client             = Network.CallClient

NevermoreEngine.SoloTestMode            = Configuration.SoloTestMode
-- NevermoreEngine.IsServer             = Configuration.IsServer
-- NevermoreEngine.IsClient             = Configuration.IsClient

-- Internally used
NevermoreEngine.GetMainDatastream       = Network.GetMainDatastream

NevermoreEngine.NevermoreContainer      = NevermoreContainer
NevermoreEngine.nevermoreContainer      = NevermoreContainer
NevermoreEngine.nevermore_container     = NevermoreContainer

NevermoreEngine.ReplicatedPackage       = ReplicatedPackage
NevermoreEngine.replicatedPackage       = ReplicatedPackage
NevermoreEngine.replicated_package      = ReplicatedPackage

if Configuration.IsServer then
	local function Initiate()
		--print(Configuration.PrintHeader .. "Nevermore is initiating.")
		--- Initiates Nevermore. This should only be called once. 
		-- Since Nevermore sets all of its executables, and executes them manually, 
		-- there is no need to wait for Nevermore when these run. 

		NevermoreEngine.Initiate = nil
		ResouceManager.PopulateResourceCache()

		if Configuration.IsServer then
			Network.ConnectPlayers()
			ResouceManager.ExecuteExecutables()
		end

		-- if Configuration.SoloTestMode then
			-- print(Configuration.PrintHeader .. "SoloTestMode enabled for NevermoreEngine.")
			-- SetupSplash()
		-- end
	end
	NevermoreEngine.Initiate = Initiate
else
	ResouceManager.PopulateResourceCache()
	Network.AddSplashToNevermore(NevermoreEngine)
end	
	--print(Configuration.PrintHeader .. "Nevermore is initiated successfully."

--print(Configuration.PrintHeader .. "#ReturnValues = ".. (#ReturnValues))

return NevermoreEngine