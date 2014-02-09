while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local qGUI              = LoadCustomLibrary('qGUI')
local qCamera           = LoadCustomLibrary('qCamera')
local SoundPlayer       = LoadCustomLibrary('SoundPlayer')
local EventBin          = LoadCustomLibrary('EventBin')

qSystems:Import(getfenv(0));

local lib = {}

-- This system is used to select a team, with camera effects. 

local function GetSpawnLocation(TeamColor) -- Eww... 
	local ItemFound
	CallOnChildren(Workspace, function(Item)
		if Item:IsA("SpawnLocation") and Item.TeamColor.Name == TeamColor.Name then
			ItemFound = Item
		elseif Item:IsA("SpawnLocation") then
			--print("[MenuSystemTester] - Spawn find fail @ "..Item:GetFullName().." Check @ "..tostring(Item.TeamColor.Name == TeamColor.Name))
		end
	end)
	return ItemFound
end
lib.GetSpawnLocation = GetSpawnLocation

local MakeTeamSelectorOption = Class 'TeamSelector' (function(TeamSelectorOption, Team, TeamIcon, AutoSelectFunction, JoinFilter)
	-- Prerequests: Team is a `Team` and TeamIcon is a valid ROBLOX String URL or nil. JoinFilter and AutoSelectFunction are functions or nil.

	TeamIcon = TeamIcon or "";
	TeamSelectorOption.TeamIcon = TeamIcon
	AutoSelectFunction = AutoSelectFunction or function(Player) 
		return false
	end
	JoinFilter = JoinFilter or function(Player) 
		return true
	end

	TeamSelectorOption.AutoSelectFunction = AutoSelectFunction
	TeamSelectorOption.JoinFilter = JoinFilter
	TeamSelectorOption.Team = Team

	local function GetCameraPositions()
		-- Returns this selector's camera position (Where it's suppose to point at) or nil...

		local CoordinateFrameObject = Team:FindFirstChild("TeamCoordinateFrame") 
		local FocusObject = Team:FindFirstChild("TeamFocus")
		if not (CoordinateFrameObject and FocusObject and CoordinateFrameObject:IsA("CFrameValue") and FocusObject:IsA("CFrameValue")) then
			print("[MenuSystemTester] [TeamSelector] - Could not get camera inf - malformed/nil objects")
			return nil
		else
			return CoordinateFrameObject.Value.p, FocusObject.Value.p
		end
	end
	TeamSelectorOption.GetCameraPositions = GetCameraPositions
end)
lib.MakeTeamSelectorOption = MakeTeamSelectorOption

local MakeTeamSelector =  Class 'TeamSelector' (function(TeamSelector, ScreenGui, Configuration, TeamSelectors)
	-- Allows a player to select a team.

	-- Prerequests: ScreenGui is a ROBLOX `ScreenGui`, Configuration is a table of configurations or nil, and TeamSelectors is an array of TeamSelectors
	local Events = EventBin.MakeEventBin()
	Configuration = Configuration or {}
	Configuration.SelectorSize = Configuration.SelectorSize or 200 -- How big is the selector
	Configuration.TeamNameSize = Configuration.TeamNameSize or 20 -- How tall is the teamSize.
	Configuration.TeamSelectorTweenTime = Configuration.TeamSelectorTweenTime or 0.5
	Configuration.TagLine = Configuration.TagLine or "Join the battle on the side of the "
	Configuration.Title = "Choose your fraction";

	local OverallHeight = Configuration.SelectorSize + Configuration.TeamNameSize + 50 -- 50 is from the outside labels, 20 for the TagLIne and 30 for the title
	local TeamChooserHeight = Configuration.SelectorSize + Configuration.TeamNameSize
	local TeamChooserWidth

	local TeamSelected = CreateSignal()
	TeamSelector.TeamSelected = TeamSelected

	TeamSelector.SelectedTeam = -1 -- Index of selected team
	TeamSelector.CanSelect = true -- Can something get selected? 
	local TeamSelectorCopy = TeamSelectors
	TeamSelectors = {}
	local TeamSelectorCount = 0

	for Index, Item in pairs(TeamSelectorCopy) do
		if Item.JoinFilter(Players.LocalPlayer) then
			local Template = Make 'ImageButton' {
				Archivable             = false;
				BackgroundTransparency = 1;
				BorderSizePixel        = 0;
				Name                   = "Selector";
				--Parent                 = ScreenGui;
				Position               = UDim2.new(0, Configuration.SelectorSize * (TeamSelectorCount), 0, 0);
				Size                   = UDim2.new(0, Configuration.SelectorSize, 0, TeamChooserHeight);
				Visible                = true; 
				ZIndex                 = 2;
			}
			Item.Gui = Template

			local TitleLabel = Make 'TextLabel' {  -- Such as "Nightfall Clan"
				Archivable             = false;
				BackgroundTransparency = 1;
				BorderSizePixel        = 0;
				Font                   = "Arial";
				FontSize               = "Size14";
				Name                   = "TeamName";
				Parent                 = Template;
				Position               = UDim2.new(0, 0, 1, -Configuration.TeamNameSize);
				Size                   = UDim2.new(1, 0, 0, Configuration.TeamNameSize);
				Text                   = Item.Team.Name:upper();
				TextColor3             = Color3.new(1, 1, 1);
				TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
				TextStrokeTransparency = 0.8;
				TextTransparency       = 0;
				TextXAlignment         = "Center";
				ZIndex                 = 1;
			}

			local Icon = Make 'ImageLabel' {
				Archivable             = false;
				BackgroundTransparency = 1;
				BorderSizePixel        = 0;
				Name                   = "Selector";
				Image                  = Item.TeamIcon;
				Parent                 = Template;
				Position               = UDim2.new(0, 0, 0, 0);
				Size                   = UDim2.new(0, Configuration.SelectorSize, 0, Configuration.SelectorSize);
				Visible                = true; 
				ZIndex                 = 1;
			}

			Events:add(Template.MouseEnter:connect(function()
				if TeamSelector.CanSelect then
					SoundPlayer.PlaySound("Tick", 0.5)
					TeamSelector.SetSelected(Item)
					local CoordinateFrame, Focus = Item.GetCameraPositions()
					if CoordinateFrame and Focus then
						qCamera.TweenCamera(CoordinateFrame, Focus, Configuration.TeamSelectorTweenTime, true)
					end
				end
			end))

			Events:add(Template.MouseButton1Click:connect(function()
				if TeamSelector.CanSelect then
					TeamSelector.SetSelected(Item)
					TeamSelector.SelectTeam(Players.LocalPlayer)
				end
			end))


			local Edging = Make 'Frame' { -- Make Edging for beautification reasons.
				Archivable             = false;
				BackgroundTransparency = 0.8;
				BackgroundColor3       = Color3.new(0, 0, 0);
				BorderSizePixel        = 0;
				Name                   = "Edging";
				Parent                 = Template;
				Position               = UDim2.new(1, -1, 0, 10);
				Size                   = UDim2.new(0, -1, 1, -20);
				Visible                = true;
				ZIndex                 = 1;
				Make 'Frame' {
					Archivable             = false;
					BackgroundTransparency = 0.8;
					BackgroundColor3       = Color3.new(1, 1, 1);
					BorderSizePixel        = 0;
					Name                   = "Edging";
					Position               = UDim2.new(1, 0, 0, 0);
					Size                   = UDim2.new(0, 1, 1, 0);
					Visible                = true; 
					ZIndex                 = 1;
				};
			};

			TeamSelectorCount = TeamSelectorCount + 1
			TeamSelectors[#TeamSelectors+1] = Item
		end
	end

	TeamChooserWidth = TeamSelectorCount * Configuration.SelectorSize

	local Container = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = true;
		Name                   = "qTeamChooserContainer";
		Parent                 = ScreenGui;
		Position               = UDim2.new(0, 0, 0.5, -OverallHeight/2);
		Size                   = UDim2.new(1, 0, 0, OverallHeight);
		Visible                = true; -- We'll change after TextLabel's TextBounds actually cnage. 
		ZIndex                 = 1;
	}

	local TeamChooser = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;--0.7; -- Will tween to 0.7
		BackgroundColor3       = Color3.new(0, 0, 0);
		BorderSizePixel        = 0;
		Name                   = "TeamChooser";
		Parent                 = Container;
		Position               = UDim2.new(0.5, -TeamChooserWidth/2, 0.5, -TeamChooserHeight/2);
		Size                   = UDim2.new(0, TeamChooserWidth, 0, TeamChooserHeight);
		ZIndex                 = 1;
	}

	local TeamChooserContainer = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BorderSizePixel        = 0;
		Name                   = "TeamChooserContainer";
		Parent                 = TeamChooser;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 1, 0);
		ZIndex                 = 1;
		ClipsDescendants       = true;
	}

	for _, Item in pairs(TeamSelectors) do
		Item.Gui.Parent = TeamChooserContainer;
	end

	local TagLine = Make 'TextLabel' { -- Something along the lines of "Join the battle on the side of the "...?
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "Arial";
		FontSize               = "Size14";
		Name                   = "TagLine";
		Parent                 = TeamChooser;
		Position               = UDim2.new(0, 30, 1, 0);
		Text                   = Configuration.TagLine;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
		TextStrokeTransparency = 0.8;
		TextTransparency       = 0;
		TextXAlignment         = "Left";
		ZIndex                 = 1;
	}
	TagLine.Size = UDim2.new(0, TagLine.TextBounds.X, 0, 20);

	local TeamNameLabel = Make 'TextLabel' { -- Something along the lines of "Join the battle on the side of the "...?
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "Arial";
		FontSize               = "Size14";
		Name                   = "TeamNameLabel";
		Parent                 = TeamChooser;
		Position               = UDim2.new(0, TagLine.Position.X.Offset + TagLine.Size.X.Offset, 1, 0);
		Size                   = UDim2.new(1, 0, 0, 20);
		Text                   = "No one";
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
		TextStrokeTransparency = 0.8;
		TextTransparency       = 0;
		TextXAlignment         = "Left";
		ZIndex                 = 1;
	}

	local TitleLabel = Make 'TextLabel' { -- Something along the lines of "Join the battle on the side of the "...?
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "ArialBold";
		FontSize               = "Size24";
		Name                   = "TitleLabel";
		Parent                 = TeamChooser;
		Position               = UDim2.new(0, -25, 0, -30);
		Size                   = UDim2.new(1, 0, 0, 30);
		Text                   = Configuration.Title;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
		TextStrokeTransparency = 1; --0.8;
		TextTransparency       = 1; --0; Tweens in later.
		TextXAlignment         = "Left";
		ZIndex                 = 1;
	}

	local SelectedMarker = Make 'ImageLabel' {
		Image                  = "http://www.roblox.com/asset/?id=110293218";
		BorderSizePixel        = 0;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		Size                   = UDim2.new(0, Configuration.SelectorSize, 0, Configuration.SelectorSize + Configuration.TeamNameSize);
		Name                   = "SelectorMarkor";
		BorderSizePixel        = 0;
		Position               = UDim2.new(0, 0, 0, 0);
		Parent                 = TeamChooserContainer;
	}
	Container.Visible = false

	

	local function InitialUpdate()
		-- Call after all the team's have been added to autoselect a team. 

		local TeamSelectorOption, Index = TeamSelector.AutoSuggest(Players.LocalPlayer)
		if TeamSelectorOption then
			TeamSelector.SelectedTeam = Index
			local CoordinateFrame, Focus = TeamSelectorOption.GetCameraPositions()
			if CoordinateFrame and Focus then
				qCamera.PointCamera(CFrame.new(CoordinateFrame), CFrame.new(Focus))
			end
		end
	end

	local function Show()
		InitialUpdate()
		TeamSelector.Update()
		TeamSelector.CanSelect = false
		qGUI.TweenTransparency(TeamChooser, {BackgroundTransparency = 0.7}, 0.25, true)
		qGUI.TweenTransparency(TitleLabel, {TextTransparency = 0; TextStrokeTransparency = 0.8}, 0.25, true)

		for Index, TeamSelectorOption in pairs(TeamSelectors) do
			TeamSelectorOption.Gui.Position = UDim2.new(0, -Configuration.SelectorSize, 0, 0);
		end
		SelectedMarker.Position = UDim2.new(-1, 0, 0, 0)
		TeamChooser.Position = UDim2.new(0.5, -TeamChooserWidth/2, 0.5, -1);
		TeamChooser:TweenPosition(UDim2.new(0.5, -TeamChooserWidth/2, 0.5, -TeamChooserHeight/2), "Out", "Sine", 0.25, true)
		Container.Visible  = true
		wait(0.25)
		Spawn(function()
			for Index, TeamSelectorOption in pairs(TeamSelectors) do
				TeamSelectorOption.Gui:TweenPosition(UDim2.new(0, (Index-1)*Configuration.SelectorSize, 0, 0), "Out", "Elastic", 1.5, true);
				wait(0.25)
			end
		end)
		wait(#TeamSelectors * 0.25 + 1)
		SelectedMarker.Parent = Container

		TeamSelector.Update()
		TeamSelector.CanSelect = true

		local Mouse = Players.LocalPlayer:GetMouse() -- Basically, if their mouse is over a selection, automatically tween to it. 
		for _, TeamSelectorOption in pairs(TeamSelectors) do
			if qGUI.MouseOver(Mouse, TeamSelectorOption.Gui) then
				TeamSelector.SetSelected(TeamSelectorOption)
			end
		end
	end
	TeamSelector.Show = Show

	local function Hide()
		TeamSelector.CanSelect = false
		SelectedMarker:TweenPosition(UDim2.new(1, 30, 0, 0), "In", "Sine", 0.5, true)
		for Index, TeamSelectorOption in pairs(TeamSelectors) do
			delay(0.25 * (#TeamSelectors - Index), function()
				TeamSelectorOption.Gui:TweenPosition(UDim2.new(1, 0, 0, 0), "Out", "Sine", 0.5, true);
			end)
		end
		wait((#TeamSelectors * 0.25) + 0.4)
		qGUI.TweenTransparency(TeamChooser, {BackgroundTransparency = 1}, 0.25, true)
		qGUI.TweenTransparency(TitleLabel, {TextTransparency = 1; TextStrokeTransparency = 1}, 0.25, true)

		TeamChooser:TweenPosition(UDim2.new(0.5, -TeamChooser.AbsoluteSize.X/2, 1, 50), "Out", "Sine", 0.25, true)
		wait(0.4)
		Container.Visible      = false
		TeamChooser.Visible    = false
		TeamSelector.CanSelect = true
		Events:destroy()
	end
	TeamSelector.Hide = Hide

	local function AutoSuggest(Player)
		-- Autosuggest a team..
		for Index, TeamSelectorOption in pairs(TeamSelectors) do
			if TeamSelectorOption.AutoSelectFunction(Player) then
				return TeamSelectorOption, Index
			end
		end
		return nil, nil
	end
	TeamSelector.AutoSuggest = AutoSuggest

	local function GetSelectedTeam()
		-- Returns the selectedteam option if it exists...

		local SelectedTeam = TeamSelectors[TeamSelector.SelectedTeam]
		return SelectedTeam
	end
	TeamSelector.GetSelectedTeam = GetSelectedTeam

	local function Update()
		-- Updates the GUI's and moves selectedGui

		SelectedMarker.Parent = TeamChooserContainer
		SelectedMarker:TweenPosition(UDim2.new(0, (TeamSelector.SelectedTeam-1) * Configuration.SelectorSize, 0, 0), "InOut", "Sine", 0.1, true)
		local SelectedTeam = GetSelectedTeam()
		--TeamChooser.Size = UDim2.new(0, #TeamSelector.Options * Settings.TeamSelectorWidth, 0, Settings.TeamSelectorHeight)
		--TeamChooserGui.Position = UDim2.new(0.5, -TeamChooserGui.AbsoluteSize.X/2, 0.5, -TeamChooserGui.AbsoluteSize.Y/2)
		if SelectedTeam then
			TeamNameLabel.TextColor3 = SelectedTeam.Team.TeamColor.Color
			TeamNameLabel.Text = SelectedTeam.Team.Name
		else
			TeamNameLabel.TextColor3 = Color3.new(1, 1, 1);
			TeamNameLabel.Text = "[ None Selected ]"
		end
	end
	TeamSelector.Update = Update

	local function SelectTeam(Player)
		-- Sets the Player's team, and then closes the GUI...

		local SelectedTeam = GetSelectedTeam()

		if SelectedTeam then
			Player.TeamColor = SelectedTeam.Team.TeamColor
			Player.Neutral = false
			TeamSelected:fire(SelectedTeam.Team)
		else
			print("[TeamSelector] - Can't select team for player, ")
		end
	end
	TeamSelector.SelectTeam = SelectTeam

	local function SetSelected(TeamSelectorOption)
		TeamSelector.SelectedTeam = getIndexByValue(TeamSelectors, TeamSelectorOption)
		if not TeamSelector.SelectedTeam then
			error("[TeamSelector] - Tried to set selection of TeamSelector to a option that does not exist...")
		end
		Update()
	end
	TeamSelector.SetSelected = SetSelected
end)
lib.MakeTeamSelector = MakeTeamSelector

NevermoreEngine.RegisterLibrary('TeamSelector', lib)