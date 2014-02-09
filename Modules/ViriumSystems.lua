while not _G.NevermoreEngine do wait(0) end

local Players            = Game:GetService('Players')
local StarterPack        = Game:GetService('StarterPack')
local StarterGui         = Game:GetService('StarterGui')
local Lighting           = Game:GetService('Lighting')
local Debris             = Game:GetService('Debris')
local Teams              = Game:GetService('Teams')
local BadgeService       = Game:GetService('BadgeService')
local InsertService      = Game:GetService('InsertService')
local MarketplaceService = game:GetService("MarketplaceService")
local Terrain            = Workspace.Terrain

local NevermoreEngine    = _G.NevermoreEngine
local LoadCustomLibrary  = NevermoreEngine.LoadLibrary;

local qSystems           = LoadCustomLibrary('qSystems')
local AnimationSystems   = LoadCustomLibrary('AnimationSystems')
local Table              = LoadCustomLibrary('Table')
local EasyConfiguration  = LoadCustomLibrary('EasyConfiguration')
local qCFrame            = LoadCustomLibrary('qCFrame')
local qMath              = LoadCustomLibrary('qMath')
local qString            = LoadCustomLibrary('qString')
local PlayerManager      = LoadCustomLibrary('PlayerManager')
local ChatManager        = PlayerManager.ChatManager

qSystems:Import(getfenv(0));

local lib = {}
local RandomRoundNames = {
	"Night";
	"Evening";
	"Nightfall";
	"Moon";
	"Darkness";
	"Dusk";
	"Twilight";
	"Sundown";
	"Gloom";
	"Gloaming";
	"Eventide";
	"Dimday";
	"Dark";
	"Nightly";
	"Nocturnal";
	"Darkness";
	"Sunset";
}

local function OpenControlPanel(Part, Player, CanNotClose)
	-- Requests that the control panel be open...
	if Player and CheckCharacter(Player) and Player.Character.Humanoid.Health > 0 then
		local UserSettings = Player:FindFirstChild("UserSettings")
		if UserSettings and UserSettings:FindFirstChild("RequestShowPanel") and UserSettings:FindFirstChild("ControlPanelShowPosition") and UserSettings.ControlPanelShowPosition:IsA("Vector3Value") and UserSettings.RequestShowPanel:IsA("BoolValue") then
			local SetTo = not UserSettings.RequestShowPanel.Value
			if SetTo or (SetTo == false and not CanNotClose) then
				UserSettings.RequestShowPanel.Value = SetTo
				if Part then
					wait(0)
					UserSettings.ControlPanelShowPosition.Value = Part.Position
				end
			end
		end
	end
end
lib.OpenControlPanel = OpenControlPanel
lib.openControlPanel = OpenControlPanel

local function FindFaceFromCoord(size, loc)
	local pa, pb = -size/2, size/2
	local dx = math.min(math.abs(loc.x-pa.x), math.abs(loc.x-pb.x))
	local dy = math.min(math.abs(loc.y-pa.y), math.abs(loc.y-pb.y))
	local dz = math.min(math.abs(loc.z-pa.z), math.abs(loc.z-pb.z))
	--
	if dx < dy and dx < dz then
		if math.abs(loc.x-pa.x) < math.abs(loc.x-pb.x) then
			return Enum.NormalId.Left --'Left'
		else
			return Enum.NormalId.Right --'Right'
		end
	elseif dy < dx and dy < dz then
		if math.abs(loc.y-pa.y) < math.abs(loc.y-pb.y) then
			return Enum.NormalId.Bottom --'Bottom'
		else
			return Enum.NormalId.Top --'Top'
		end
	elseif dz < dx and dz < dy then
		if math.abs(loc.z-pa.z) < math.abs(loc.z-pb.z) then
			return Enum.NormalId.Front --'Front'
		else
			return Enum.NormalId.Back --'Back'
		end	
	end 
end


local function SetupOneWayGateModel(OneWayGatePart)
	local Configuration = {
		FlingBackVelocity = 200;
		DefaultReflectance = OneWayGatePart.Reflectance;
	}

	local SessionId = 0

	OneWayGatePart.Touched:connect(function(TouchedPart)
		local Character, Player = GetCharacter(TouchedPart)

		if Character and Player and CheckCharacter(Player) and not (not Player.Neutral and Player.TeamColor.Name == OneWayGatePart.BrickColor.Name) then
			local HitFace = FindFaceFromCoord(OneWayGatePart.Size, OneWayGatePart.CFrame:toObjectSpace(CFrame.new(Character.Torso.Position)))
			--print("[MenuSystemTester] - Player hit @ " .. tostring(HitFace))
			if HitFace ~= Enum.NormalId.Back then
				local TargetPosition = (OneWayGatePart.CFrame * CFrame.new(0, 0, -5)).p
				Player.Character.Torso.CFrame = OneWayGatePart.CFrame * CFrame.new(0, 0, -5)
				if (TargetPosition - Player.Character.Torso.Position).magnitude >= 1 then
					Player.Character.Humanoid.Health = 0
				end
				Player.Character.Torso.Velocity = OneWayGatePart.CFrame.lookVector * Configuration.FlingBackVelocity
				Spawn(function()
					PlayerManager.PlayerManager:Notify(Player, "Trying to get into other people's spawns is rude and against the game's rules. Please stop.", "Warning")
				end)
				SessionId = SessionId + 1
				local LocalSessionId = SessionId

				Spawn(function()
					OneWayGatePart.Reflectance = 1
					while OneWayGatePart.Reflectance > Configuration.DefaultReflectance and SessionId == LocalSessionId do
						OneWayGatePart.Reflectance = OneWayGatePart.Reflectance - 0.05
						wait(0.03)
					end
					OneWayGatePart.Reflectance = Configuration.DefaultReflectance
				end)
			end
		end
	end)
end
lib.SetupOneWayGateModel = SetupOneWayGateModel
lib.setupOneWayGateModel = SetupOneWayGateModel



local function SetupStatusLights(DefaultValue)
	local StatusValue = Make 'BoolValue' {
		Name = "StatusLightValue";
		Value = DefaultValue ~= nil and DefaultValue or false;
	}

	local StatusLightSystem = {}
	local StatusLights = {}

	local function SwitchLight(Item, Value)
		local Light = Item:FindFirstChild("SwitchLight") or Make 'PointLight' {
			Brightness = 10;
			Range = 2;
			Name = "SwitchLight";
			Color = Item.BrickColor.Color;
			Archivable = false;
			Parent = Item;
		};
		Light.Enabled = Value;
	end

	local function AddStatusLight(GreenLight, RedLight)
		local Item = {
			GreenLight = GreenLight;
			RedLight = RedLight;
		}

		if not StatusValue.Value then
			Item.RedLight.BrickColor = BrickColor.new("Mid grey")
			Item.GreenLight.BrickColor = BrickColor.new("Bright green")
			SwitchLight(Item.RedLight, false)
			SwitchLight(Item.GreenLight, true)
		else
			Item.RedLight.BrickColor = BrickColor.new("Bright red")
			Item.GreenLight.BrickColor = BrickColor.new("Mid grey")
			SwitchLight(Item.RedLight, true)
			SwitchLight(Item.GreenLight, false)
		end
		StatusLights[#StatusLights+1] = Item
	end
	StatusLightSystem.AddStatusLight = AddStatusLight
	StatusLightSystem.addStatusLight = AddStatusLight

	local function UpdateStatusLights()
		if not StatusValue.Value then
			for _, Item in pairs(StatusLights) do
				Item.RedLight.BrickColor = BrickColor.new("Bright red")
				Item.GreenLight.BrickColor = BrickColor.new("Mid grey")
				SwitchLight(Item.RedLight, true)
				SwitchLight(Item.GreenLight, false)
			end
		else
			for _, Item in pairs(StatusLights) do
				Item.RedLight.BrickColor = BrickColor.new("Mid grey")
				Item.GreenLight.BrickColor = BrickColor.new("Bright green")
				SwitchLight(Item.RedLight, false)
				SwitchLight(Item.GreenLight, true)
			end
		end
	end

	StatusLightSystem.UpdateStatusLights = UpdateStatusLights
	StatusLightSystem.updateStatusLights = UpdateStatusLights

	local function SetStatus(NewValue)
		StatusValue.Value = NewValue
		UpdateStatusLights()
	end
	StatusLightSystem.SetStatus = SetStatus
	StatusLightSystem.setStatus = SetStatus


	return StatusLightSystem
end
lib.SetupStatusLights = SetupStatusLights
lib.setupStatusLights = SetupStatusLights


local function SetupSwitches(DefaultValue, AnimateTime)
	local SwitchSystem = {}
	local SwitchGate = AnimationSystems.MakeGate(AnimateTime or 2);
	local SwitchStatusValue = SwitchGate.StatusValue
	SwitchStatusValue.Value = DefaultValue or false;
	local PowerSwitches = {}

	local function AddSwitch(SwitchButton, SwitchCenter)
		-- SwitchButton is the part that moves, SwitchCenter is what it revovles around...
		local Origin = SwitchCenter.CFrame
		local OnPosition = Origin * CFrame.Angles(math.rad(60), 0, 0)
		local OffPosition = Origin * CFrame.Angles(math.rad(-60), 0, 0)
		qCFrame.TransformModel(SwitchButton:GetChildren(), Origin, OnPosition)
		local Door = SwitchGate:AddNewDoor(SwitchButton, OnPosition, OffPosition)

		--PowerSwitches[#PowerSwitches+1] = Door
	end
	SwitchSystem.AddSwitch = AddSwitch
	SwitchSystem.addSwitch = AddSwitch

	local function Reset()
		-- Reset's the system into it's actual position
		SwitchSystem.SetStatus(not SwitchStatusValue.Value)
		SwitchSystem.SetStatus(SwitchStatusValue.Value)
	end
	SwitchSystem.Reset = Reset
	SwitchSystem.reset = Reset

	local function SetStatus(NewValue)
		SwitchStatusValue.Value = NewValue
	end
	SwitchSystem.SetStatus = SetStatus
	SwitchSystem.SetStatus = SetStatus

	return SwitchSystem	
end
lib.SetupSwitches = SetupSwitches
lib.setupSwitches = SetupSwitches

local function SetupStandardGate(GateModel)
	local Gate = {}
	local NewGate = AnimationSystems.MakeGate(1);
	local StatusValue = NewGate.StatusValue
	local MainStatusValue = Make 'BoolValue' {
		Name = "GateStatus";
		Parent = GateModel;
		Value = false;
	}

	local StatusLightSystem = SetupStatusLights(MainStatusValue.Value)
	local SwitchSystem = SetupSwitches(MainStatusValue.Value)

	local function Update(NewValue)
		StatusValue.Value = NewValue
		MainStatusValue.Value = NewValue
		SwitchSystem.SetStatus(NewValue)
		StatusLightSystem.SetStatus(NewValue)
	end
	Gate.Update = Update
	Gate.update = Update

	local function SetStatus(NewValue)
		MainStatusValue.Value = NewValue
	end
	Gate.SetStatus = SetStatus
	Gate.setStatus = SetStatus

	MainStatusValue.Changed:connect(function(NewValue)
		Update(MainStatusValue.Value)
	end)

	for _, Item in pairs(GateModel:GetChildren()) do
		if Item:IsA("BasePart") then
			if Item.Name == "Left" then
				NewGate:AddNewDoor(Item, Item.CFrame, Item.CFrame * CFrame.new(-Item.Size.X+1, 0, 0))
			elseif Item.Name == "Right" then
				NewGate:AddNewDoor(Item, Item.CFrame, Item.CFrame * CFrame.new(-Item.Size.X+1, 0, 0))
			end
		elseif Item:IsA("Model") then
			local GreenLight = Item:FindFirstChild("GreenLight")
			local RedLight = Item:FindFirstChild("RedLight")
			local SwitchButton = Item:FindFirstChild("SwitchButton")

			if GreenLight and RedLight then
				StatusLightSystem.AddStatusLight(GreenLight, RedLight)
			elseif SwitchButton then
				local SwitchCenter = SwitchButton:FindFirstChild("SwitchCenter")
				if SwitchCenter and SwitchCenter:IsA("BasePart") then
					SwitchSystem.AddSwitch(SwitchButton, SwitchCenter)
				end
			end
		end

		if Item:FindFirstChild("ClickDetector") and Item:IsA("BasePart") and Item.ClickDetector:IsA("ClickDetector") then
			Item.ClickDetector.MouseClick:connect(function(Player)
				print("[ViriumSystems] - Click trigger gate... "..GateModel.Name)
				Update(not MainStatusValue.Value)
			end)
		end
	end

	SwitchSystem.Reset()
	--print("[AnimationSystemTester] - Setup gate "..GateModel.Name)
	return Gate
end
lib.SetupStandardGate = SetupStandardGate
lib.setupStandardGate = SetupStandardGate



local function SetupDoor(Item)
	local Door = {}
	local NewGate = AnimationSystems.MakeGate(0.5);
	NewGate.StatusValue.Parent = Item

	local DoorDegreesOpen = Make 'NumberValue' {
		Name = "DegreesOpen";
		Parent = Item;
		Value = 80;
	};
	
	local DoorModel = WaitForChild(Item, "Door")
	local DoorMain = WaitForChild(DoorModel, "Main")
	local Origin = DoorMain.CFrame * CFrame.new(-DoorMain.Size.X/2, 0, 0)
	local Door = NewGate:AddNewDoor(DoorModel, DoorMain.CFrame, Origin * CFrame.Angles(0, math.rad(-DoorDegreesOpen.Value), 0) * CFrame.new(DoorMain.Size.X/2, 0, 0))

	DoorDegreesOpen.Changed:connect(function()
		Door:SetEndCFrame(Origin * CFrame.Angles(0, math.rad(-DoorDegreesOpen.Value), 0) * CFrame.new(DoorMain.Size.X/2, 0, 0))
	end)

	local function SetStatus(Value)
		NewGate.StatusValue.Value = Value
	end
	Door.SetStatus = SetStatus
	Door.setStatus = SetStatus

	return Door
end
lib.SetupDoor = SetupDoor
lib.setupDoor = SetupDoor

local function SetupConsoleSystem(Model)
	--print("[AnimationSystemTester] - Setup Console  @ " .. Model:GetFullName())
	CallOnChildren(Model, function(Part)
		--print("[AnimationSystemTester] - Setup Console Part @ " .. Part:GetFullName())
		if Part and Part:IsA("BasePart")then
			Part.Touched:connect(function(Item)
				local Character, Player = getCharacter(Item)
				OpenControlPanel(Part, Player, true)
			end)
		elseif Part and Part:IsA("ClickDetector") and Part.Parent and Part.Parent:IsA("BasePart") then
			local BasePart = Part.Parent
			Part.MouseClick:connect(function(Player)
				OpenControlPanel(BasePart, Player)
			end)
		end	
	end)
end
lib.SetupConsoleSystem = SetupConsoleSystem
lib.setupConsoleSystem = SetupConsoleSystem

local function SetupPowerCore(PowerCoreModel, CanSwitchFilter)
	local Core = {}
	Core.Name = PowerCoreModel.Name

	local CoreConfiguration = EasyConfiguration.MakeEasyConfiguration(EasyConfiguration.AddSubDataLayer("qPowerCoreConfiguration", PowerCoreModel))
	CoreConfiguration.AddValue("IntValue", {
		Name = "CoreStatus";
		Value = 1; -- 1 = on, 0 is off for now. 
	})
	CoreConfiguration.AddValue("IntValue", {
		Name = "MaxPowerLevel";
		Value = 1200;
	})
	CoreConfiguration.AddValue("NumberValue", {
		Name = "CorePowerLevel";
		Value = CoreConfiguration.MaxPowerLevel; 
	})
	CoreConfiguration.AddValue("NumberValue", {
		Name = "MaxIncreasePerSecond";
		Value = 1; 
	})
	CoreConfiguration.AddValue("BoolValue", {
		Name = "HasPower";
		Value = CoreConfiguration.CorePowerLevel == 0;
	})
	CoreConfiguration.CoreStatus = 1
	CoreConfiguration.CorePowerLevel = CoreConfiguration.MaxPowerLevel
	CoreConfiguration.HasPower = CoreConfiguration.CorePowerLevel >= 0;

	local CoreStatus = CoreConfiguration.GetValue("CoreStatus")
	local StatusLightSystem = SetupStatusLights(CoreStatus == 1)
	local SwitchSystem = SetupSwitches(CoreStatus == 1)

	Core.CoreConfiguration = CoreConfiguration
	local function Step()
		local Increase
		if CoreConfiguration.CoreStatus == 1 then
			Increase = math.abs(CoreConfiguration.MaxIncreasePerSecond)
		else
			Increase = -math.abs(CoreConfiguration.MaxIncreasePerSecond)
		end

		local Value, DidClamp = qMath.ClampNumber(CoreConfiguration.CorePowerLevel + Increase, 0, CoreConfiguration.MaxPowerLevel)
		CoreConfiguration.CorePowerLevel = Value
		if Value <= 0 then
			--print("[AnimationSystemTester] - Clamp false")
			CoreConfiguration.HasPower = false
		else
			CoreConfiguration.HasPower = true
		end
		return not DidClamp
	end
	Core.Step = Step
	Core.step = Step

	local Updating = false

	local function StartUpdate()
		if not Updating then	
			Updating = true
			local Valid = Step()
			while Valid do
				wait(1)
				Valid = Step()
			end
			print("[AnimationSystemTester] - Update finish")
			Updating = false
		else
			print("[AnimationSystemTester] - Already updating power core entity")
		end
	end
	Core.StartUpdate = StartUpdate
	Core.startUpdate = StartUpdate

	local function Reset()
		CoreConfiguration.CoreStatus = 1
		CoreConfiguration.CorePowerLevel = CoreConfiguration.MaxPowerLevel
		Step()
	end
	Core.Reset = Reset
	Core.reset = Reset
	
	CoreStatus.Changed:connect(function()
		if CoreConfiguration.CoreStatus == 1 then
			SwitchSystem.SetStatus(true)
			StatusLightSystem.SetStatus(true)
			StartUpdate()
			--PowerGoal:SetTarget(CoreConfiguration.MaxPowerLevel)
		else
			SwitchSystem.SetStatus(false)
			StatusLightSystem.SetStatus(false)
			StartUpdate()
			--PowerGoal:SetTarget(0)
		end
	end)

	for _, Item in pairs(PowerCoreModel:GetChildren()) do
		if Item:IsA("Model") then
			local GreenLight = Item:FindFirstChild("GreenLight")
			local RedLight = Item:FindFirstChild("RedLight")
			local SwitchButton = Item:FindFirstChild("SwitchButton")

			if GreenLight and RedLight then
				StatusLightSystem.AddStatusLight(GreenLight, RedLight)
			elseif SwitchButton then
				local SwitchCenter = SwitchButton:FindFirstChild("SwitchCenter")
				if SwitchCenter and SwitchCenter:IsA("BasePart") then
					SwitchSystem.AddSwitch(SwitchButton, SwitchCenter)
				end
			end
		elseif Item:FindFirstChild("ClickDetector") and Item:IsA("BasePart") and Item.ClickDetector:IsA("ClickDetector") then
			Item.ClickDetector.MouseClick:connect(function(Player)
				local Authorized = CanSwitchFilter == nil
				local NotAuthoredMessage = "You are not authorized to change this core";
				local NotAuthorizedTitle = "Warning"
				if CanSwitchFilter then
					local IsAuthorized, Message, Title = CanSwitchFilter(Player, Core)
					Authorized = not IsAuthorized
					if Message then
						NotAuthoredMessage = Message
					end
					if Title then
						NotAuthorizedTitle = Title
					end
				end
				if (Authorized) then
					--print("[AnimationSystemTester] - Click trigger power core... "..PowerCoreModel.Name)
					if CoreConfiguration.CoreStatus == 1 then
						CoreConfiguration.CoreStatus = 0
						StatusLightSystem.SetStatus(false)
					else
						CoreConfiguration.CoreStatus = 1
						StatusLightSystem.SetStatus(true)
					end
				else
					PlayerManager.PlayerManager:Notify(Player, NotAuthoredMessage, NotAuthorizedTitle)
					--print("[AnimationSystemTester] - Can not switch switch, filter returned true '" .. NotAuthoredMessage .. "'")
				end
			end)
		end
	end
	SwitchSystem.Reset()

	--print("[AnimationSystemTester] - Setup Power Core "..PowerCoreModel.Name)
	return Core
end
lib.SetupPowerCore = SetupPowerCore
lib.setupPowerCore = SetupPowerCore

local function GenerateRandomRoundId()
	local Num = math.floor((tick() % 100000000))
	local NewId = "";
	math.randomseed(tick());
	for i=1, 3 do
		NewId = NewId .. RandomRoundNames[math.random(1, #RandomRoundNames)] .. "-"
	end
	NewId = NewId..Num
	return NewId
end
lib.GenerateRandomRoundId = GenerateRandomRoundId
lib.generateRandomRoundId = GenerateRandomRoundId


local function CountTeamMembers(TeamColorName)
	local Count = 0
	for _, Player in pairs(Players:GetPlayers()) do
		if not Player.Neutral then
			if Player.TeamColor.Name == TeamColorName then
				Count = Count + 1
			end
		end
	end
	return Count
end
lib.CountTeamMembers = CountTeamMembers
lib.countTeamMembers = CountTeamMembers


local function SetupZoneSystem(ZoneData) 
	-- Setups up an authorization zone system to make official games...
	--[[
		ZoneData = {
			Name = ""
			ZonePart = ZonePart;
			ZoneFilter = function(Character, Player)

			end;
			RequiredUsers = 5;
		}
		
	--]]
	local ZoneSystem = {}
	ZoneSystem.ZoneData = ZoneData
	local OfficialStatusMet = CreateSignal();
	ZoneSystem.OfficialStatusMet = OfficialStatusMet

	local function CheckIfConditionsMet()
		local Authorized = true
		for _, Zone in pairs(ZoneData) do
			if not Zone.CheckZone() then
				Authorized = false
			end
		end
		if Authorized then
			ZoneSystem.OfficialStatusMet:fire()
			return true
		end
		return false;
	end
	ZoneSystem.CheckIfConditionsMet = CheckIfConditionsMet
	ZoneSystem.checkIfConditionsMet = CheckIfConditionsMet

	for _, Zone in pairs(ZoneData) do
		Zone.Name = Zone.Name or "[ Unnamed ]";
		Zone.RequiredUsers = Zone.RequiredUsers or 5;
		--Zone.ActiveCharacters = {}
		Zone.MoreUsersRequired = Zone.RequiredUsers
		Zone.ZoneFilter = Zone.ZoneFilter or function() return false end;
		if not Zone.ZonePart then
			error("[ViriumSystems][ZoneSystem] - Zonepart is required for Zone '"..Zone.Name.."'")
		end

		local BillboardGui = Make 'BillboardGui' {
			Active      = false;
			Adornee     = Zone.ZonePart;
			AlwaysOnTop = false;
			Enabled     = true;
			Name        = 'BillboardGui';
			StudsOffset = Vector3.new(0, 10, 0);
			Parent      = Zone.ZonePart;
			Size        = UDim2.new(10, 0, 10, 0);
		}

		local Counter = Make 'TextLabel' {
			BackgroundTransparency = 1;
			Font                   = "ArialBold";
			FontSize               = "Size36";
			Name                   = "Counter";
			Parent                 = BillboardGui;
			Size                   = UDim2.new(1, 0, 1, 0);
			Text                   = Zone.MoreUsersRequired.."+";
			TextColor3             = Color3.new(1, 1, 1);
			TextScaled             = true;
			TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
			TextStrokeTransparency = 0.8;
			TextTransparency       = 0;
			Visible                = true;
		}

		local PreviousCharacters = {}
		local function CheckZone()
			--print("Checking zone")
			local Count = 0
			--[[for Character, Info in pairs(Zone.ActiveCharacters) do
				if Character and Character.Parent and Info.Player and Info.Player.Character == Character and Character:FindFirstChild("Torso") and Character.Torso:IsA("BasePart") then 
					if qCFrame.PointInsidePart(Zone.ZonePart, Character.Torso.Position) then
						Count = Count + 1
						Info.LastTimeIn = tick()
					elseif Info.LastTimeIn + 1 >= tick()  then -- They've been out long enough, remove them from a check...
						Zone.ActiveCharacters[Character] = nil
					end
				else
					Zone.ActiveCharacters[Character] = nil
				end
			end
			
			--]]
			local ToNotify = {}
			local ToNotifyLeave = {}
			for _, Player in pairs(Players:GetPlayers()) do
				local Character = Player.Character
				if Character and Character.Parent and Character:FindFirstChild("Torso") and Character.Torso:IsA("BasePart") and not Zone.ZoneFilter(Character, Player) then 
					if qCFrame.PointInsidePart(Zone.ZonePart, Character.Torso.Position) then
						print("Player "..Player.Name.." is inside of the zone.")
						if not PreviousCharacters[Character] then
							print("Player "..Player.Name.." has entered the zone")
							ToNotify[#ToNotify+1] = Player
							PreviousCharacters[Character] = true
						end
						Count = Count + 1
					elseif PreviousCharacters[Character] then
						print("Player "..Player.Name.." has left the zone")
						ToNotifyLeave[#ToNotifyLeave+1] = Player
						PreviousCharacters[Character] = nil
					end
				end
			end

			Zone.MoreUsersRequired = math.max(0, Zone.RequiredUsers - Count)
			Counter.Text  = Zone.MoreUsersRequired.."+";

			for _, Player in pairs(ToNotify) do
				PlayerManager.PlayerManager:Notify(Player, "You've entered a server activation system for "..Zone.Name..", "..(Zone.RequiredUsers - Count).." user"..((Zone.RequiredUsers - Count) == 1 and "" or "s").." are required in order to activate your team's side. ", 
					"Raid System")
			end
			for _, Player in pairs(ToNotifyLeave) do
				PlayerManager.PlayerManager:Notify(Player, "You've left a server activation system for "..Zone.Name..", "..(Zone.RequiredUsers - Count).." user"..((Zone.RequiredUsers - Count) == 1 and "" or "s").." are required in order to activate your team's side. ", 
					"Raid System")
			end
			if Zone.OnCheck then
				Zone.OnCheck(Count)
			end

			if Count >= Zone.RequiredUsers then
				return true, Count
			else
				return false, Count
			end
		end
		Zone.CheckZone = CheckZone

		Zone.ZonePart.Touched:connect(function()
			--print("Touch start")
			--CheckZone()
			CheckIfConditionsMet()
		end)

		Zone.ZonePart.TouchEnded:connect(function()
			--print("Touch end")
			--CheckZone()
			CheckIfConditionsMet()
		end)
		--[[
		Zone.ZonePart.Touched:connect(function(Part)
			local Character, Player = GetCharacter(Part)
			if Character and Player and not Zone.ZoneFilter(Character, Player) and not Zone.ActiveCharacters[Character] then
				Zone.ActiveCharacters[Character] = {
					Player = Player;
					LastTimeIn = tick();
				}
				local ZoneValid, Count = CheckZone()
				PlayerManager.PlayerManager:Notify(Player, "You've entered a server activation system, "..(Zone.RequiredUsers - Count).." user"..((Zone.RequiredUsers - Count) == 1 and "" or "s").." are required in order to activate your team's side. ", 
					"Raid System")
				CheckIfConditionsMet()
			end
		end)--]]
	end

	Spawn(function()
		while true do
			--[[for _, Zone in pairs(ZoneData) do
				Zone.CheckZone()
				wait(1)
			end--]]
			CheckIfConditionsMet()
			wait(5)
		end
	end)

	return ZoneSystem;
end
lib.SetupZoneSystem = SetupZoneSystem

local MakeViriumGameSystem = Class 'ViriumGameSystem' (function(GameSystem, GameGates, GameDoors, OneWayGates, SetupCores, ZoneData)
	-- Runs the main game...

	local GameConfiguration = EasyConfiguration.MakeEasyConfiguration(EasyConfiguration.AddSubDataLayer("ViriumGameSettings", PlayerManager.ServerContainer))
	GameConfiguration.AddValue("IntValue", {
		Name = "StandardRoundTime";
		Value = 7200;
	})
	GameConfiguration.AddValue("IntValue", {
		Name = "RoundTimeLeft";
		Value = GameConfiguration.StandardRoundTime;
	})
	GameConfiguration.AddValue("BoolValue", {
		Name = "RaidOfficial";
		Value = false;
	})
	GameConfiguration.AddValue("StringValue", {
		Name = "RoundId";
		Value = "[ERROR]";
	})
	GameConfiguration.AddValue("IntValue", {
		Name = "RoundCount";
		Value = 1;
	})

	local ZoneSystem = SetupZoneSystem(ZoneData) 

	local Gates = {}
	local Doors = {}

	for _, GateModel in pairs(GameGates) do
		Gates[#Gates+1] = SetupStandardGate(GateModel)
	end

	for _, DoorModel in pairs(GameDoors) do
		Doors[#Doors+1] = SetupDoor(DoorModel)
	end

	for _, OneWayGate in pairs(OneWayGates) do
		SetupOneWayGateModel(OneWayGate)
	end

	local function ResetGame()
		print("Resetting game...")
		GameConfiguration.RoundCount = GameConfiguration.RoundCount + 1
		GameConfiguration.RoundTimeLeft = GameConfiguration.StandardRoundTime
		ChatManager:SystemNotification("Restarting game, please wait...")
		for _, Door in pairs(Gates) do
			Door.SetStatus(true)
		end
		for _, Gate in pairs(Gates) do
			Gate.SetStatus(true)
		end
		for _, Core in pairs(SetupCores) do
			Core.Reset()
		end
		for _, Player in pairs(Players:GetPlayers()) do
			Player:LoadCharacter()
		end
	end
	GameSystem.ResetGame = ResetGame
	GameSystem.resetGame = ResetGame

	local function CheckIfCoresStillHavePower()
		for _, Core in pairs(SetupCores) do
			if Core.CoreConfiguration.HasPower then
				return false
			end
		end
		return true
	end
	GameSystem.CheckIfCoresStillHavePower = CheckIfCoresStillHavePower
	GameSystem.checkIfCoresStillHavePower = CheckIfCoresStillHavePower

	local OfficialGameNext = false

	local function StartRound(IsOfficial)
		if IsOfficial then
			OfficialGameNext = false
		end
		GameConfiguration.RaidOfficial = IsOfficial
		local LocalRoundId = GenerateRandomRoundId()
		local LocalRoundCount = GameConfiguration.RoundCount
		GameConfiguration.RoundId = LocalRoundId
		local OfficialStatus = IsOfficial and "Official" or "Unofficial"

		ChatManager:SystemNotification(OfficialStatus.." game round " .. qString.GetRomanNumeral(LocalRoundCount) .. " \"" .. LocalRoundId .. "\" has begun.")

		while GameConfiguration.RoundCount == LocalRoundCount do
			GameConfiguration.RoundTimeLeft = GameConfiguration.RoundTimeLeft - 1
			if CheckIfCoresStillHavePower() then
				ChatManager:SystemNotification("Raiders have won the "..OfficialStatus:lower().." game (Good game :D)  ID: "..LocalRoundCount.."")
				ResetGame()
			elseif GameConfiguration.RoundTimeLeft <= 0 then
				ChatManager:SystemNotification("The game time is up, the round "..qString.GetRomanNumeral(LocalRoundCount).." game is over.")
				ResetGame()
			else
				wait(1)
			end
		end
	end

	ZoneSystem.OfficialStatusMet:connect(function()
		if not GameConfiguration.RaidOfficial then
			ResetGame()
			OfficialGameNext = true
			ChatManager:SystemNotification("Official game round will start soon...")
		end
	end)
	Spawn(function()
		while true do
			StartRound(OfficialGameNext)
		end
	end)
end)
lib.MakeViriumGameSystem = MakeViriumGameSystem
lib.makeViriumGameSystem = MakeViriumGameSystem



local function SetupProductNotificationSystem(ProductId, CheckTime, Title, GSubDescription)
	Title = Title or "Game Notification"
	CheckTime = CheckTime or 30

	Spawn(function()
		local ProductInformation = MarketplaceService:GetProductInfo(ProductId)
		local LastDescription = ""--ProductInformation.Description
		local ServerNotification = PlayerManager.GetServerContainer():WaitForChild("ServerNotification")

		while game do
			ProductInformation = MarketplaceService:GetProductInfo(ProductId)
			local Description = ProductInformation.Description
			if Description ~= LastDescription and Description ~= "" and not qString.CompareCutFirst(Description, "nothing") then
				Description = GSubDescription(Description)
				ServerNotification.Value = Description
				ChatManager:SystemNotification("[NOTIFICATION] - "..Description)
				for _, Player in pairs(Players:GetPlayers()) do
					Spawn(function()
						PlayerManager.PlayerManager:Notify(Player, Description, Title)
					end)
				end
				LastDescription = Description
			end
			wait(CheckTime)
		end
	end)
end
lib.SetupProductNotificationSystem = SetupProductNotificationSystem
lib.setupProductNotificationSystem = SetupProductNotificationSystem

NevermoreEngine.RegisterLibrary('ViriumSystems', lib)