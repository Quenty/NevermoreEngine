local Players            = game:GetService('Players')
local ServerStorage      = game:GetService("ServerStorage")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Libraries          = _G.LocalLibraries or {}
local FailedLibraries    = {}
local RequestedLibraries = {}

local LocalPlayer = Players.LocalPlayer

local Settings = {
	YieldTimeout      = 60; -- Time it'll wait for a library to load before giving up and erroring. Important. 
	DoYieldTimeout    = true; -- If set to false, it won't YieldTimeout. 
	WhitelistChildren = {
		NevermoreEngineClient = true; -- Children to ignore. (Names)
		LibraryRequestBin        = true;
	};
	SoloTestMode      = (game:FindFirstChild("NetworkServer") == nil and game.PlaceId == 0);
	SystemName        = "Nevermore";
	ClientName        = "Client";
	BlackList         = "";
	CustomCharacters  = true;
	SplashScreen      = true;
	CharacterRespawnTime = 5;
}

-- Load and Verify required assets
local Mailbox = LocalPlayer:FindFirstChild("Mailbox")
assert(Mailbox, "[NevermoreEngine] - Could not identify Mailbox, essential component")
local qSystemsBin = ReplicatedStorage:FindFirstChild(Settings.SystemName)
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
local LocalMailbox = LocalPlayer:FindFirstChild("Mailbox")
assert(Mailbox, "[NevermoreEngine] - Could not identify Mailbox, essential component")

-- Setup Library variables...
local NativeImports
_G.LocalLibraries      = Libraries
local QuentyRequestBin = script:FindFirstChild("QuentyRequestBin")
local LibraryAdded     = Instance.new('BindableEvent')

-- Wait for QuentyRequestBin...
while not (QuentyRequestBin and QuentyRequestBin.Value) do 
	print("[NevermoreEngineClient] - NevermoreEngineClient is waiting for 'QuentyRequestBin' / QuentyRequestBin.Value") 
	wait(0)
	QuentyRequestBin = script:FindFirstChild("QuentyRequestBin")
end

-- Load Settings from Bin...
for _, Value in pairs(SettingsBin:GetChildren()) do
	if Value:IsA("Instance") and string.find(Value.ClassName, "Value") then
		Settings[Value.Name] = Value.Value;
		Value.Changed:connect(function()
			Settings[Value.Name] = Value.Value;
		end)
	end
end

local function LoadScript(...)
	-- Will load a script into the game safely.  Can be called multiple times, 
	-- with multiple scripts.
	-- Parameters: ... Provide a script, or a script name. If a script name is 
	-- provided then it will search the Server bin for the script to load. 

	for _, ScriptToLoad in pairs({...}) do
		if type(ScriptToLoad) == "string" then
			ScriptToLoad = ClientBin:FindFirstChild(ScriptToLoad);
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

local function Import(LibraryDefinition, Environment, Prefix)
	-- Imports a library into a given environment, potentially adding a PreFix
	-- into any of the values of the library, incase that's wanted. :)

	if type(LibraryDefinition) ~= "table" then
		error("[NevermoreEngineClient] - The LibraryDefinition argument must be a table, got '"..tostring(LibraryDefinition).."'", 2)
	elseif type(Environment) ~= "table" then
		error("[NevermoreEngineClient] - The Environment argument must be a table, got '"..tostring(Environment).."'", 2)
	else
		Prefix = Prefix or "";

		for Name, Value in pairs(LibraryDefinition) do
			if Environment[Prefix..Name] == nil and not NativeImports[Name] then
				Environment[Prefix..Name] = LibraryDefinition[Name]
			elseif not NativeImports[Name] then
				error("[NevermoreEngineClient] - Failed to import function '"..(Prefix..Name).."' as it already exists in the environment", 2)
			end
		end
	end
end

NativeImports = {
	import = Import;
	Import = Import;
}

local function AddLibrary(LibraryName, LibraryDefinition)
	-- Modifies a library to include any 'NativeImports' that are to be included
	-- for easy of use, but only adds them in if the value doesn't exist. 

	-- It also fires the LibraryAdded bindableEvent.

	if type(LibraryName) ~= "string" then
		error("[NevermoreEngineClient] - The LibraryName argument must be a string, got '"..tostring(LibraryName).."'", 3)
	elseif type(LibraryDefinition) ~= "table" then
		error("[NevermoreEngineClient] - The LibraryDefinition argument must be a table, got '"..tostring(LibraryDefinition).."'", 3)
	else
		for Name, Value in pairs(NativeImports) do
			if not LibraryDefinition[Name] then
				LibraryDefinition[Name] = Import;
			end
		end

		Libraries[LibraryName] = LibraryDefinition
		LibraryAdded:Fire(LibraryName, LibraryDefinition)

		return LibraryDefinition;
	end
end

local function RegisterLibrary(LibraryName, LibraryDefinition)
	-- Registers a new library into the system (The actual library, not the 
	-- script). 

	if type(LibraryName) ~= "string" then
		error("[NevermoreEngineClient] - The LibraryName argument must be a string, got '"..tostring(LibraryName).."'", 2)
	elseif type(LibraryDefinition) ~= "table" then
		error("[NevermoreEngineClient] - The LibraryDefinition argument must be a table, got '"..tostring(LibraryDefinition).."'", 2)
	elseif not Libraries[LibraryName] then
		AddLibrary(LibraryName, LibraryDefinition)
	else
		error("[NevermoreEngineClient] - A Library with the name of '"..LibraryName.."' already exists. ")
	end
end


local function WaitForLibrary(LibraryName, PrintHeader)
	if Libraries[LibraryName] then
		return Libraries[LibraryName];
	end

	PrintHeader = PrintHeader or ""

	local Yielder = Instance.new('BindableEvent')
	local Connection
	local FailedAddition 

	Connection = LibraryAdded.Event:connect(function(LibraryNameAdded, LibraryDefinition)
		if LibraryNameAdded == LibraryName then
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

local function RequestLibrary(LibraryName)
	RequestedLibraries[LibraryName] = true;

	local RequestObject = Instance.new("ObjectValue")
	RequestObject.Name = LibraryName
	RequestObject.Value = nil;
	RequestObject.Parent = QuentyRequestBin.Value

	local Yielder = Instance.new("BindableEvent")

	local LocalScript

	local Connection = RequestObject.Changed:connect(function()
		--print("request object changed")
		if RequestObject.Value and RequestObject.Value:IsA("LocalScript") then
			LocalScript = RequestObject.Value
			Yielder:Fire(RequestObject.Value)
		end
	end)
	if Settings.DoYieldTimeout then
		delay(Settings.YieldTimeout, function()
			if not LocalScript then
				Yielder:Fire()
			end
		end)
	end

	Yielder.Event:wait()
	Connection:disconnect()
	Connection = nil;
	if not LocalScript then
		FailedLibraries[LibraryName] = true;
		error("[NevermoreEngineClient] - LoadRequest failed for local library search.  Could not find library '"..LibraryName.."' in local libraires.")
	end

	--print("[NevermoreEngineClient] - Successful clone of "..LibraryName.." into script")
	local Clone = LocalScript:Clone()
	Clone.Parent = script;
	Clone.Disabled = false;
	RequestObject:Destroy()
end

local function LoadLibrary(LibraryName)
	if Libraries[LibraryName] then
		return Libraries[LibraryName];
	elseif not RequestedLibraries[LibraryName] then
		RequestLibrary(LibraryName)
		return WaitForLibrary(LibraryName)
	elseif not FailedLibraries[LibraryName] then
		return WaitForLibrary(LibraryName)
	end
end

local function SetupSplashScreen(ScreenGui)
	-- Creates a Windows 8 style loading screen, finishing the loading animation
	-- of pregenerated spash screens.

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
	local FoundAsset = Instance.new("BindableEvent")

	local function Disable()
		-- Can be called to disable the SplashScreen. Will have the Alias
		-- ClearSplash in NevermoreEngine

		IsActive = false;
		ScreenGui:Destroy()
	end
	Splash.Disable = Disable

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

local function HandleMailboxRequests(Child)
	-- Handles a single request to run a script client side. 

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
					Child.ErrorOutput.Value = tostring(Error) or "Could not compile loadstring";
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
end

local function SetupMailboxConnections()
	-- Handles Mailbox script requests and whatnot in order that it does not
	-- become desynced with the server.

	for _, Child in pairs(Mailbox:GetChildren()) do
		HandleMailboxRequests(Child)
	end

	Mailbox.ChildAdded:connect(function(Child)
		HandleMailboxRequests(Child)
	end)
end

-- Generate NevermoreEngine and associated code.
if not Settings.SoloTestMode then
	local NevermoreEngine = {
		LoadLibrary  = LoadLibrary;
		loadLibrary  = LoadLibrary;
		load_library = LoadLibrary;

		Import = Import;
		import = Import;

		RegisterLibrary  = RegisterLibrary;
		registerLibrary  = RegisterLibrary;
		Register_library = RegisterLibrary;

		systemName = Settings.SystemName;
		SystemName = Settings.SystemName;

		LoadClientScript = LoadScript;
		loadClientScript = LoadScript;

		CallClient = CallClient;
		callClient = CallClient;
		call_client = CallClient;

		CallServer = CallServer;
		callServer = CallServer;
		call_server = CallServer;

		-- Needs to be called by ClientMain...
		SetupMailboxConnections = SetupMailboxConnections;
		setupMailboxConnections = SetupMailboxConnections;
	}
	local ScreenGui = LocalPlayer.PlayerGui:FindFirstChild("SplashScreen")
	if Settings.SplashScreen and ScreenGui then
		local Splash = SetupSplashScreen(ScreenGui)
		local function ClearSplash()
			Splash.Disable()
			NevermoreEngine.SplashActive = false;
		end
		NevermoreEngine.ClearSplash = ClearSplash;
		NevermoreEngine.clearSpash = ClearSplash;
		NevermoreEngine.SplashActive = true;
	else
		local function ClearSplash()
			NevermoreEngine.SplashActive = false;
		end
		NevermoreEngine.ClearSplash = ClearSplash;
		NevermoreEngine.clearSpash = ClearSplash;
		NevermoreEngine.SplashActive = false;
	end

	_G.NevermoreEngine = NevermoreEngine;
else
	-- NevermoreEngine works a bit differently in solo mode due to the _G 
	-- namespace being shared.  This creates a big pain, and this is the work
	-- around.

	print("[NevermoreEngineClient] - Solo mode of NevermoreEngineClient enabled")

	while not _G.NevermoreEngine do wait(0) end

	_G.NevermoreEngine.LoadClientScript = LoadScript;
	_G.NevermoreEngine.loadClientScript = LoadScript;
	_G.NevermoreEngine.SetupMailboxConnections = SetupMailboxConnections;
	_G.NevermoreEngine.setupMailboxConnections = SetupMailboxConnections
	
	local ScreenGui = LocalPlayer.PlayerGui:FindFirstChild("SplashScreen")
	if Settings.SplashScreen and ScreenGui then
		local Splash = SetupSplashScreen(ScreenGui)
		local function ClearSplash()
			Splash.Disable()
			_G.NevermoreEngine.SplashActive = false;
		end
		_G.NevermoreEngine.ClearSplash = ClearSplash;
		_G.NevermoreEngine.clearSpash = ClearSplash;
		_G.NevermoreEngine.SplashActive = true;
	else
		local function ClearSplash()
			_G.NevermoreEngine.SplashActive = false;
		end
		_G.NevermoreEngine.ClearSplash = ClearSplash
		_G.NevermoreEngine.clearSpash = ClearSplash
		_G.NevermoreEngine.SplashActive = false;
	end
end

