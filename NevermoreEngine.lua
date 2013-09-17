local Players            = game:GetService("Players")
local Lighting           = game:GetService('Lighting')
local MarketplaceService = game:GetService('MarketplaceService')
local ProjectMain        = script.Parent
local LocalScripts       = {}
local RanScripts         = {}
local ServerScripts      = {}
local Libraries          = {}
local FailedLibraries    = {}
local Modulars           = {}
local GlobalRequestId    = 0 -- Each 'request' to load a library receives an ID for debugging purposes. This is a counter.
local NativeImports
local NevermoreEngine

local Settings = {
	YieldTimeout      = 60; -- Time it'll wait for a library to load before giving up and erroring. Important. 
	DoYieldTimeout    = true; -- If set to false, it won't YieldTimeout. 
	WhitelistChildren = {
		NevermoreEngineClient = true; -- Children to ignore. (Names)
		LibraryRequestBin        = true;
	};
	SoloTestMode      = (game:FindFirstChild("NetworkServer") == nil and game.PlaceId == 0);
	SystemName        = "Nevermore";
	ClientName        = "Client"; -- What "Client" script should we search for?
	BlackList         = "";
	CustomCharacters  = true; 
	SplashScreen      = true; -- Should a splash screen be generated?
	CharacterRespawnTime = 5;
}

Players.CharacterAutoLoads = false;

-- Load and Verify required assets
local Mailbox = ProjectMain:FindFirstChild("Mailbox")
assert(Mailbox, "[NevermoreEngine] - Could not identify Mailbox, essential component")
local qSystemsBin = Lighting:FindFirstChild(Settings.SystemName)
assert(qSystemsBin, "[NevermoreEngine] - qSystemsBin could not be identified")
local ResourceBin = qSystemsBin:FindFirstChild("Resources");
assert(ResourceBin, "[NevermoreEngine] - ResourceBin could not be identified")
local LibraryBin = ResourceBin:FindFirstChild("Libraries");
assert(LibraryBin, "[NevermoreEngine] - LibraryBin could not be identified")
local ClientBin = qSystemsBin:FindFirstChild("Client");
assert(ClientBin, "[NevermoreEngine] - ClientBin could not be identified")
local ServerBin = qSystemsBin:FindFirstChild("Server");
assert(ServerBin, "[NevermoreEngine] - ServerBin could not be identified")
local SettingsBin = qSystemsBin:FindFirstChild("Settings");
assert(SettingsBin, "[NevermoreEngine] - SettingsBin could not be identified")
local NevermoreEngineClient = script:FindFirstChild(Settings.ClientName) 
assert(NevermoreEngineClient, "[NevermoreEngine] - Dependent script '"..Settings.ClientName.."' could not be found")

-- Load Settings from Bin into the Settings. 
for _, Value in pairs(SettingsBin:GetChildren()) do
	if Value:IsA("Instance") and string.find(Value.ClassName, "Value") then
		Settings[Value.Name] = Value.Value;
		Value.Changed:connect(function()
			Settings[Value.Name] = Value.Value;
		end)
	end
end

-- Create initial Variables for the LibrarySystem...
local LibraryAdded = Instance.new('BindableEvent')
local ModularAdded = Instance.new('BindableEvent')
local LibraryRequestBin = script:FindFirstChild("LibraryRequestBin") or (function() 
		local Bin       = Instance.new("Configuration")
		Bin.Name        = "LibraryRequestBin";
		Bin.Archivable  = false;
		Bin.Parent      = script
		return Bin;
	end)()

local function LoadScript(...)
	-- Will load a script into the game safely.  Can be called multiple times, 
	-- with multiple scripts.
	-- Parameters: ... Provide a script, or a script name. If a script name is 
	-- provided then it will search the Server bin for the script to load. 

	for _, ScriptToLoad in pairs({...}) do
		if type(ScriptToLoad) == "string" then
			ScriptToLoad = ServerBin:FindFirstChild(ScriptToLoad);
		end
		if ScriptToLoad then
			local NewScript = ScriptToLoad:Clone()
			NewScript.Disabled = true;
			NewScript.Parent = script;
			Spawn(function()
				wait(0)
				NewScript.Disabled = false;
			end)
		else
			print("Could not find script '"..tostring(ScriptToLoad).."'")
		end
	end
end

local function CallClient(Code, Player)
	-- Runs code LocalSide of the Player called.  It will return any error
	-- output.

	if Player and Player:FindFirstChild("Mailbox") then
		local StringValue = Instance.new("StringValue")
		StringValue.Name = "Execute";
		StringValue.Value = tostring(Code);

		local ErrorOutput = Instance.new("StringValue", StringValue)
		ErrorOutput.Value = "";
		ErrorOutput.Name = "ErrorOutput";

		StringValue.Parent = Player.Mailbox;

		ErrorOutput.Changed:wait();
		local Output = ErrorOutput.Value;
		StringValue:Destroy()

		return Output;
	else
		return "Unable to execute code, could not identify either the Mailbox or the Player";
	end
end

local function CallServer(Code)
	-- Runs code ServerSide, mainly to be called by the client. Will
	-- return any error output.

	local StringValue = Instance.new("StringValue")
	StringValue.Name = "Execute";
	StringValue.Value = tostring(Code);

	local ErrorOutput = Instance.new("StringValue", StringValue)
	ErrorOutput.Value = "";
	ErrorOutput.Name = "ErrorOutput";

	StringValue.Parent = Mailbox;

	ErrorOutput.Changed:wait();
	local Output = ErrorOutput.Value;
	StringValue:Destroy()

	return Output;
end

local function GetLocalLibrary(LibraryName)
	-- Return's the LocalLibrary script with the name 'LibraryName'

	return LocalScripts[LibraryName]
end

local function CheckPlayer(player)
	-- Makes sure a player has all necessary components.

	return player and player:IsA("Player") and player.Parent == Players
		and player:FindFirstChild("PlayerGui")
		and player:FindFirstChild("Backpack") 
		and player:FindFirstChild("StarterGear")
		and player.PlayerGui:IsA("PlayerGui")
		and player.Backpack:IsA("Backpack") 
		and player.StarterGear:IsA("StarterGear")
end

local function CheckCharacter(player)
	-- Make sure that a character has all necessary components

	local character = player.Character;
	return character
		and character:FindFirstChild("Humanoid") 
		and character:FindFirstChild("Torso")
		and character:FindFirstChild("Head")
		and character.Humanoid:IsA("Humanoid")
		and character.Head:IsA("BasePart")
		and character.Torso:IsA("BasePart")
end

local function IsBlacklisted(Player, BlackList)
	-- Return's if a player is blacklisted from the game or not.

	for Id in string.gmatch(BlackList, "%d+") do
		if string.match(MarketplaceService:GetProductInfo(Id)["Description"], Player.Name..";") then
			return true;
		end
	end
	for Name in string.gmatch(BlackList, "[%a%d]+") do
		if Player.Name:lower() == Name:lower() then
			return true;
		end
	end
	return false;
end

local function GenerateInitialSplashScreen(Player)
	-- Will generate the initial SplashScreen for the player.  

	local Configuration = {
		BackgroundColor3       = Color3.new(237/256, 236/256, 233/256);       -- Color of background of loading screen.
		AccentColor3           = Color3.new(8/256, 130/256, 83/256);          -- Not used. 
		LogoSize               = 200;
		LogoTexture            = "http://www.roblox.com/asset/?id=129733987";
		LogoSpacingUp          = 70; -- Pixels up from loading frame.
		ParticalOrbitDistance  = 50;                                         -- How far out the particals orbit
	}

	local ScreenGui = Instance.new("ScreenGui", Player.PlayerGui)
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
end

local function SetupPlayer(Player)
	-- Setups up a player giving it the initial local-side framework, the 
	-- Mailbox, and the Splashscreen...  Will handle BlackListed players 
	-- Appropriately. 

	if IsBlacklisted(Player, Settings.BlackList) then
		Player:Destroy()
	else
		Spawn(function() -- Run in a seperate thread so we don't ever stop. 
			--print("[NevermoreEngine] - Setting up Player '"..Player.Name.."'")

			if NevermoreEngine.PlayerJoined then
				NevermoreEngine.PlayerJoined(Player)
			end

			local Mailbox = Instance.new("Configuration", Player)
			Mailbox.Name = "Mailbox";
			Mailbox.Archivable = false;

			local function SetupCharacter()
				--print("[NevermoreEngine] - Cloning support scripts to Player")

				while Player and (Player.Parent == Players) and (not CheckPlayer(Player)) do 
					wait(0) 
					print("[NevermoreEngine] - Waiting for "..Player.Name.." to verify...")
				end

				if Player and (Player.Parent == Players) then
					-- Enable Custom Character Loading....
					if not Settings.CustomCharacters then
						-- While the Player and Character or Player has failed to load do...
						while (CheckPlayer(Player) and (not CheckCharacter(Player))) do
							wait(0)
							print("[NevermoreEngine] - Waiting for "..Player.Name.."'s character")
						end
						if CheckPlayer(Player) then
							Player.Character.Humanoid.Died:connect(function()
								wait(Settings.CharacterRespawnTime)
								Player:LoadCharacter(true)
							end)
						end
					end

					if not Player.PlayerGui:FindFirstChild(NevermoreEngineClient.Name.."Distributed") then
						local SupportScript = NevermoreEngineClient:Clone()
						SupportScript.Name = SupportScript.Name.."Distributed";
						SupportScript.Archivable = false

						local RequestBin = Instance.new("ObjectValue", SupportScript)
						RequestBin.Name = "QuentyRequestBin"
						RequestBin.Value = LibraryRequestBin;
						RequestBin.Archivable = false

						SupportScript.Parent = Player.PlayerGui
						SupportScript.Disabled = false

						if ClientBin:FindFirstChild("ClientMain") then
							local ClientMain = ClientBin.ClientMain:Clone()
							ClientMain.Parent = Player.PlayerGui;
							ClientMain.Disabled = false;
						end
						--print("[NevermoreEngine] - Done Cloning Scripts")
					else
						print("[NevermoreEngine] - Script already exists in PlayerGui")
					end
				else
					print("[NevermoreEngine] - ".. tostring(Player) .. " has been removed from the game...")
				end
			end

			-- Remove character/finish loading for custom characters...
			if Settings.CustomCharacters then
				if not Player.Character then
					Player:LoadCharacter()
					while not Player.Character do
						wait(0) 
					end
				end
				Player.Character:Destroy()
			else
				Player:LoadCharacter();
			end

			if Settings.SplashScreen then
				GenerateInitialSplashScreen(Player)
			end
			SetupCharacter()
			

			Player.CharacterAdded:connect(function()
				Spawn(SetupCharacter)
			end)
		end)
	end
end

local function ConnectPlayers()
	-- Connects all the events and adds players into the system. To be called by 
	-- the ServerMain once, and only once.

	-- Setup all the players that joined...
	for _, Player in pairs(game.Players:GetPlayers()) do
		SetupPlayer(Player)
	end

	-- And when they are added...
	Players.PlayerAdded:connect(function(Player)
		SetupPlayer(Player)
	end)

	-- And when they leave...
	Players.PlayerRemoving:connect(function(Player)
		if NevermoreEngine.PlayerLeft then
			NevermoreEngine.PlayerLeft(Player)
		end
	end)
end


local function Import(LibraryDefinition, Environment, Prefix)
	-- Imports a library into a given environment, potentially adding a PreFix 
	-- into any of the values of the library,
	-- incase that's wanted. :)

	if type(LibraryDefinition) ~= "table" then
		error("The LibraryDefinition argument must be a table, got '"..tostring(LibraryDefinition).."'", 2)
	elseif type(Environment) ~= "table" then
		error("The Environment argument must be a table, got '"..tostring(Environment).."'", 2)
	else
		Prefix = Prefix or "";

		for Name, Value in pairs(LibraryDefinition) do
			if Environment[Prefix..Name] == nil and not NativeImports[Name] then
				Environment[Prefix..Name] = LibraryDefinition[Name]
			elseif not NativeImports[Name] then
				error("Failed to import function '"..(Prefix..Name).."' as it already exists in the environment", 2)
			end
		end
	end
end

NativeImports = {
	import = Import;
	Import = Import;
}

local function AddLibrary(LibraryName, LibraryDefinition)
	-- Modifies a library to include any 'NativeImports' that are to be included for easy of use, but only 
	-- adds them in if the value doesn't exist. 

	-- It also fires the LibraryAdded bindableEvent.

	if type(LibraryName) ~= "string" then
		error("The LibraryName argument must be a string, got '"..tostring(LibraryName).."'", 2)
	elseif type(LibraryDefinition) ~= "table" then
		error("The LibraryDefinition argument must be a table, got '"..tostring(LibraryDefinition).."'", 2)
	else
		for Name, Value in pairs(NativeImports) do
			if not LibraryDefinition[Name] then
				LibraryDefinition[Name] = Import;
			end
		end

		Libraries[LibraryName] = LibraryDefinition
		--print("[NevermoreEngine] - Library '"..LibraryName.."' added into library dictionary.");
		LibraryAdded:Fire(LibraryName, LibraryDefinition)

		return LibraryDefinition;
	end
end

local function RegisterLibrary(LibraryName, LibraryDefinition)
	-- Registers a new library into the system (The actual library, not the script). 

	-- Checker --
	assert(getfenv(0).script.Name == LibraryName, getfenv(0).script:GetFullName().." does not match the LibraryName being registered");
	-- EndChecker --

	--print("[NevermoreEngine] - Registering Library '"..LibraryName.."'")

	if type(LibraryName) ~= "string" then
		error("The LibraryName argument must be a string, got '"..tostring(LibraryName).."'", 2)
	elseif type(LibraryDefinition) ~= "table" then
		error("The LibraryDefinition argument must be a table, got '"..tostring(LibraryDefinition).."'", 2)
	elseif not Libraries[LibraryName] then
		AddLibrary(LibraryName, LibraryDefinition)
	else
		error("A Library with the name of '"..LibraryName.."' already exists. ")
	end
end

local function WaitForLibrary(LibraryName, PrintHeader)
	-- Waits for a library to load...

	if Libraries[LibraryName] then
		return Libraries[LibraryName];
	end

	PrintHeader = PrintHeader or ""

	local Yielder = Instance.new('BindableEvent')
	local Connection
	local FailedAddition 

	Connection = LibraryAdded.Event:connect(function(LibraryNameAdded, LibraryDefinition)
		if LibraryNameAdded == LibraryName then
			--print(PrintHeader.."Library "..LibraryName.." added and fired event connection.")
			Yielder:Fire()
		end
	end)

	if Settings.DoYieldTimeout then
		delay(Settings.YieldTimeout, function()
			if Connection and Yielder then
				FailedAddition = true;
				Yielder:Fire()
			end
		end)
	end

	Yielder.Event:wait()
	Connection:disconnect();
	Connection = nil;
	Yielder:Destroy()
	Yielder = nil;

	if FailedAddition then
		FailedLibraries[LibraryName] = true;
		error(PrintHeader.."Library load request '"..LibraryName.."' did not load after "..Settings.YieldTimeout.." seconds of wait time. ", 2);
	end

	--print(PrintHeader.."Returning library to main LoadLibrary...")
	return Libraries[LibraryName]
end



local function LoadLibrary(LibraryName)
	-- Returns a library for the script to use, or activates a script if it the library hasn't been activated, or errors. 

	local Library
	local RequestId     = GlobalRequestId + 1;
	GlobalRequestId     = RequestId;
	local RequestHeader = "[ Request@"..RequestId.." - "..LibraryName.."] - "


	if type(LibraryName) ~= "string" then
		error(RequestHeader.."The LibraryName argument must be a string, got '"..tostring(LibraryName).."'", 2)
	elseif Libraries[LibraryName] then
		--print(RequestHeader.."Returning library (Preexisting) "..LibraryName)
		return Libraries[LibraryName]
	elseif ServerScripts[LibraryName] and not RanScripts[LibraryName] then
		--print(RequestHeader.."Loading library script "..LibraryName)

		if Settings.SoloTestMode and ServerScripts[LibraryName]:IsA("LocalScript") and Players:FindFirstChild("Player1") then
			--print(RequestHeader.."[NevermoreEngine] - Solo mode loading script '"..LibraryName.."' into Player's SupportSystem")
			local PlayerGui = Players.Player1:FindFirstChild("PlayerGui")
			if PlayerGui then
				while not PlayerGui:FindFirstChild(NevermoreEngineClient.Name.."Distributed") do
					wait(0)
					--print(RequestHeader.."[NevermoreEngine] - Waiting for "..NevermoreEngineClient.Name..Distributed.." to load")
				end
				local Clone = ServerScripts[LibraryName]:Clone()
				Clone.Parent = PlayerGui[NevermoreEngineClient.Name.."Distributed"]
				Spawn(function()
					wait()
					Clone.Disabled = false
				end)
				ServerScripts[LibraryName].Disabled = false; -- Won't run, but we want it to not be cloned again. 
			else
				error(RequestHeader.."Could not identify a Player with a valid PlayerGui in Players...")
			end
		elseif Settings.SoloTestMode and ServerScripts[LibraryName]:IsA("LocalScript") then
			error(RequestHeader.."No valid player in place, even though SoloTestMode is enabled. ")
		else
			--print(RequestHeader.."[NevermoreEngine] - Standard loading script '"..LibraryName.."' normally ")
			RanScripts[LibraryName] = true;
			Spawn(function()
				wait()
				ServerScripts[LibraryName].Disabled = false;
			end)
			--LoadScript(ServerScripts[LibraryName])
		end
	elseif ServerScripts[LibraryName] and not FailedLibraries[LibraryName] then
		--print(RequestHeader.."Waiting for library to load, already been enabled.")
	elseif FailedLibraries[LibraryName] then
		error(RequestHeader.."Library '"..LibraryName.."' failed to load properly, but was activated.")
		return nil
	else
		error(RequestHeader.."Library '"..LibraryName.."' does not exist as a script")
		return nil
	end

	local Library = WaitForLibrary(LibraryName, RequestHeader)
	assert(type(Library) == "table", RequestHeader.." '"..LibraryName.."' is not a table")
	--print(RequestHeader.." [ Request Fullfilled ] Returning library "..LibraryName) 
	return Library
end


local AddScriptsFromModular
function AddScriptsFromModular(Modular)
	-- Takes a modular script and add all of it's scripts into the system. 

	for _, Script in pairs(Modular:GetChildren()) do
		if Script:IsA("LocalScript") then
			if LocalScripts[Script.Name] then
				error("A LocalScript called '"..Script.Name.."' already exists.")
			else
				LocalScripts[Script.Name] = Script;
			end
		elseif Script:IsA("Script") then
			if ServerScripts[Script.Name] then
				error("A ServerScript called '"..Script.Name.." already exists.")
			else
				ServerScripts[Script.Name] = Script
			end
		end
		AddScriptsFromModular(Script)
	end
end

local function RegisterModular(ModularScript)
	-- Registers a new modular's script.

	--print("Registering Modular "..ModularScript.Name)
	AddScriptsFromModular(ModularScript)
	Modulars[ModularScript] = nil;
	ModularAdded:Fire(ModularScript)
end

local function GetModularsLeft()
	-- Returns how many modulars are left...

	local Count = 0;
	for _, Item in pairs(Modulars) do
		if Item then
			Count = Count + 1;
		end
	end

	--print(Count.." Modulars left")
	return Count
end

local function WaitForAllModulars()
	-- Waits until all modulars load or it times out. 

	if GetModularsLeft() ~= 0 then
		local Yielder = Instance.new('BindableEvent')
		local Connection,
		      Failed;

		Connection = ModularAdded.Event:connect(function(ModularScript)
			if GetModularsLeft() == 0 then
				Yielder:Fire()
			end
		end)

		if Settings.DoYieldTimeout then
			delay(Settings.YieldTimeout, function()
				if Connection then
					Failed = true;
					Yielder:Fire()
				end
			end)
		end

		Yielder.Event:wait()
		Connection:disconnect()
		Connection = nil;
		Yielder:Destroy()

		if Failed then
			error("Modular load failed after "..Settings.YieldTimeout.." seconds, "..GetModularsLeft().." modular(s) left to load")
			return false;
		end
	end

	return true;
end

local function HandleLibraryLocalRequest(Child)
	-- Handles objects added into the LibraryRequestBin.

	if Child:IsA("ObjectValue") then
		local NewLibrary = GetLocalLibrary(Child.Name);
		if NewLibrary then
			print("[NevermoreEngine] - Sent request Backpackk (fulfilled '"..Child.Name.."')")
			Child.Value = NewLibrary;
		else
			print("[NevermoreEngine] - Request failure, requested local library '"..Child.Name.."' unable to find")
		end
	else
		print("[NevermoreEngine] - Unexpected object in LibraryRequestBin, '"..Child.Name.."' a '"..Child.ClassName.."' object")
	end
end

local function SetupLibraryRequestBin()
	for _, Child in pairs(LibraryRequestBin:GetChildren()) do
		HandleLibraryLocalRequest(Child)
	end
	LibraryRequestBin.ChildAdded:connect(function(Child)
		HandleLibraryLocalRequest(Child)
	end)
end

RegisterModular(LibraryBin)

NevermoreEngine = {
	LoadLibrary  = LoadLibrary;
	loadLibrary  = LoadLibrary;
	load_library = LoadLibrary;

	Import = Import;
	import = Import;

	RegisterLibrary  = RegisterLibrary;
	registerLibrary  = RegisterLibrary;
	Register_library = RegisterLibrary;

	SystemName = Settings.SystemName;
	systemName = Settings.systemName;

	LoadScript = LoadScript;
	loadScript = LoadScript;
	loadscript = LoadScript;

	CallClient = CallClient;
	callClient = CallClient;
	call_client = CallClient;

	CallServer = CallServer;
	callServer = CallServer;
	call_server = CallServer;

	-- Hidden call to be used by PlayerManager. PlayerManager works intricately with NevermoreEngine. 
	ConnectPlayers = ConnectPlayers;
}


--[[
for _, Child in pairs(script:GetChildren()) do
	if not Child:IsA("Script") and not Settings.WhitelistChildren[Child.Name] then
		error(Child:GetFullName().." is not a modular script");
	elseif not Settings.WhitelistChildren[Child.Name] then
		Modulars[Child] = true
		Child.Disabled = false;
	end
end--]]

---_G.LibraryModularLoader = LibraryModularLoader
--Modulars[LibraryBin] = true;
--WaitForAllModulars()
--_G.LibraryModularLoader = nil;

Mailbox.ChildAdded:connect(function(Child)
	Spawn(function()
		if Child and Child:IsA("StringValue") then
			local Execute, Error = loadstring(Child.Value)
			if Execute then
				local Output = ypcall(function()
					Execute()
				end)
				if type(Output) == "string" then
					Error = Output
				end
				if Error and Child:FindFirstChild("ErrorOutput") then
					Child.ErrorOutput.Value = tostring(Error) or "Could not loadstring Value";
					print(Child.ErrorOutput.Value)
				elseif Child:FindFirstChild("ErrorOutput") then
					Child.ErrorOutput.Value = "Executed Successfully";
				end
			elseif Child:FindFirstChild("ErrorOutput") then
				Child:FindFirstChild("ErrorOutput").Value = Error or "Could not loadstring Value";
				print(Child.ErrorOutput.Value)
			end
		else
			error("[NevermoreEngine] - Unexpected Child in Mailbox, a "..Child.ClassName.." was parented, expected 'StringValue'")
		end
	end)
end)

if Settings.SoloTestMode then
	print("[NevermoreEngine] - Serverside Solo test mode enabled for NevermoreEngine.");
	for LocalScriptName, LocalScript in pairs(LocalScripts) do
		if not ServerScripts[LocalScriptName] then
			ServerScripts[LocalScriptName] = LocalScript
		end
	end
end

SetupLibraryRequestBin()
_G.NevermoreEngine = NevermoreEngine;
_G.Nevermore = NevermoreEngine;

-- Setup ServerSide code.
if ServerBin:FindFirstChild("ServerMain") then
	local ServerMain = ServerBin.ServerMain:Clone()
	ServerMain.Parent = Workspace;
	wait(0)
	ServerMain.Disabled = false;
end