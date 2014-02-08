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
local Table             = LoadCustomLibrary('Table')
local EventBin          = LoadCustomLibrary('EventBin')

local lib    = {}
local Styles = {} -- Stores 'styles' for the objects. :D
local Images = {} -- Stores asset ID's for the menu system. :D

qSystems:import(getfenv(0)) -- Import qSystems.

Images.BackButtonRegular = "http://www.roblox.com/asset/?id=108244852";
Images.MenuButtonRegular = "http://www.roblox.com/asset/?id=108248522";
Images.BackButtonOver = "http://www.roblox.com/asset/?id=108248716";
Images.MenuButtonOver = "http://www.roblox.com/asset/?id=108248707";

Styles.BorderlessFrame07 = {
	BackgroundColor3       = Color3.new(0, 0, 0);
	BackgroundTransparency = 0.7;
	BorderSizePixel        = 0;
	-- Style                  = "Custom";
}
Styles.TransparentFrame = {
	BackgroundColor3       = Color3.new(0, 0, 0);
	BackgroundTransparency = 1;
	BorderSizePixel        = 0;
	-- Style                  = "Custom";
}
Styles.BorderlessFrame09 = {
	BackgroundColor3       = Color3.new(0, 0, 0);
	BackgroundTransparency = 0.9;
	BorderSizePixel        = 0;
	-- Style                  = "Custom";
}
Styles.Decoration07 = {
	BackgroundColor3       = Color3.new(1, 1, 1);
	BackgroundTransparency = 0.7;
	BorderSizePixel        = 0;
	-- Style                  = "Custom";
}
Styles.Decoration05 = {
	BackgroundColor3       = Color3.new(1, 1, 1);
	BackgroundTransparency = 0.5;
	BorderSizePixel        = 0;
	-- Style                  = "Custom";
}
Styles.Decoration03Dark = {
	BackgroundColor3       = Color3.new(0, 0, 0);
	BackgroundTransparency = 0.3;
	BorderSizePixel        = 0;
	-- Style                  = "Custom";
}

Styles.MenuButton = {
	FontSize        = "Size14";
	TextColor3      = Color3.new(1, 1, 1);
	BorderSizePixel = 0;
}
Styles.MenuButtonOver = {
	FontSize        = "Size18";
	TextColor3      = Color3.new(1, 1, 1);
	BorderSizePixel = 0;
}
Styles.SubMenuButton = {
	FontSize        = "Size10";
	TextColor3      = Color3.new(1, 1, 1);
	BorderSizePixel = 0;
}
Styles.SubMenuButtonOver = {
	FontSize        = "Size11";
	TextColor3      = Color3.new(1, 1, 1);
	BorderSizePixel = 0;
}
Styles.ButtonSubcaption = {
	FontSize               = "Size12";
	TextTransparency       = 0.5;
	Font                   = "Arial";
	TextColor3             = Color3.new(1,1,1);
	BackgroundTransparency = 1;
	BorderSizePixel        = 0;
}
Styles.SubTitle = {
	FontSize               = "Size12";
	TextTransparency       = 0;
	TextStrokeTransparency = 1;
	Font                   = "Legacy";
	BorderSizePixel        = 0;
	TextColor3             = Color3.new(1,1,1);
	BackgroundTransparency = 1;
}
Styles.Divider = {
	BackgroundTransparency = 0.7;
	BorderSizePixel        = 0;
	BackgroundColor3       = Color3.new(1, 1, 1);
}


local MakeMenuButton = class 'MenuButton' (function(Button, Name, OnRender)
	-- Menu buttons are those buttons in the menu, this continas a ton of event connectors and rendering functions to
	-- manipulate them.  It's a storage container basically. 

	Button.Name    = Name;
	Button.OnClick = CreateSignal()
	Button.OnEnter = CreateSignal()
	Button.OnLeave = CreateSignal()
	Button.Events = {};

	-- Button.Gui

	local OnClickEvents = {}
	local OnEnterEvents = {}
	local OnLeaveEvents = {}

	function Button:AddEvent(Event)
		Button.Events[#Button.Events+1] = Event;
	end

	function Button:DisconnectEvents()
		-- Removes all events associated with it.  (Used by internal system)

		for _, Event in pairs(Button.Events) do
			Event:disconnect();
		end

		Button.Events = {}
	end

	local SubcaptionLabel

	function Button:AddSubcaption(Caption)
		-- For stuff like '[ Enter ]', etc.  This will renrender or create each time it's called. 

		SubcaptionLabel = SubcaptionLabel or make 'TextLabel' {
			Archivable = false;
			Position   = UDim2.new(0, 0, 0.5, 0);
			Size       = UDim2.new(1, 0, 0.5, 0);
			Visible    = true;
			ZIndex     = 5;
		}
		Modify(SubcaptionLabel, Styles.ButtonSubcaption);

		SubcaptionLabel.Text = Caption;
		SubcaptionLabel.Parent = Button.Gui or nil;
	end

	function Button:Render(BaseButton)
		-- Basically modifies the button GUI and rehooks events... 

		Modify(BaseButton, Table.CopyAndAppend(Styles.TransparentFrame, {
			Name = Name.."Button";
			Text = Name;
			ZIndex = 4;
			SubcaptionLabel;
		}))

		OnClickEvents[BaseButton] = OnClickEvents[BaseButton] or BaseButton.MouseButton1Click:connect(function(x, y)
			Button.OnClick:fire(x, y);
		end);

		OnEnterEvents[BaseButton] = OnEnterEvents[BaseButton] or BaseButton.MouseEnter:connect(function()
			Button.OnEnter:fire();
		end);

		OnLeaveEvents[BaseButton] = OnLeaveEvents[BaseButton] or BaseButton.MouseLeave:connect(function()
			Button.OnLeave:fire();
		end);
	end; 
end)
lib.MakeMenuButton = MakeMenuButton

local MakeGenericMenuLevel = class 'GenericMenuLevel' (function(GenericMenuLevel, Title)
	-- A menu level without anything in it, just a title and the menu... No buttons. 

	GenericMenuLevel.Events = EventBin.MakeEventBin()
	GenericMenuLevel.MainMenuFrame = nil;

	function GenericMenuLevel.InitialRender()
		--print("initiating new GenericMenuLevel "..tostring(Title))
		-- Called to create the resources...

		local MenuFrame = make "Frame" { -- Rendering code. Quite a bit of it.  
			Archivable = false;
			Size       = UDim2.new(1,0,1,0);
			Name       = "MainMenu";
		}
		Modify(MenuFrame, Styles.BorderlessFrame07)

		local TitleLabel = make 'TextLabel' {
			Name       = "Title";
			Archivable = false;
			Position   = UDim2.new(0, 0, 0, 50);
			Size       = UDim2.new(1, 0, 0, 30);
			Text       = tostring(Title);
			Parent     = MenuFrame;
			ZIndex     = 2;
		}
		Modify(TitleLabel, Styles.SubTitle)

		local TitleDecoration = make 'Frame' {
			Archivable = false;
			Position   = UDim2.new(0, 3, 1, 0);
			Size       = UDim2.new(1, -11, 0, 1);
			ZIndex     = 2;
			Parent     = TitleLabel;
		}
		Modify(TitleDecoration, Styles.Divider)

		local CommandBar = Make 'Frame' {
			Name     = "CommandBar";
			Size     = UDim2.new(1, 0, 0, 40);
			Position = UDim2.new(0, 0, 0, 5);
			ZIndex   = 2;
			Parent   = MenuFrame;
		}
		Modify(CommandBar, Styles.Decoration03Dark);

		local MainMenuButton = Make 'TextButton' {
			Name     = "MainMenu";
			Size     = UDim2.new(0, 100, 0, 30);
			Position = UDim2.new(1, -110, 0, 5);
			Parent   = CommandBar;
			Text     = "";
			ZIndex   = 4;
			Make 'ImageLabel' {
				Name                   = "Icon";
				Size                   = UDim2.new(0, 20, 0, 20);
				Position               = UDim2.new(0, 5, 0, 5);
				BackgroundTransparency = 1;
				ZIndex                 = 4;
				Image                  = Images.MenuButtonRegular;
			};
			Make 'TextLabel' {
				Name                   = "TextLabel";
				Position               = UDim2.new(0, 30, 0, 0);
				Size                   = UDim2.new(1, -30, 1, 0);
				BackgroundTransparency = 1;
				Text                   = "Main Menu";
				ZIndex                 = 4;
				TextColor3             = Color3.new(1, 1, 1);
			}
		}
		Modify(MainMenuButton, Styles.TransparentFrame)

		local BackButton = MainMenuButton:Clone()
		Modify(BackButton, {
			Name = "BackButton";
			Parent =  CommandBar;
			Position = UDim2.new(0, 10, 0, 5); 
		})
		BackButton.Icon.Image = Images.BackButtonRegular;
		BackButton.TextLabel.Text = "Go Back";

		return MenuFrame;
	end

	function GenericMenuLevel.OnEntrance(MenuFrame, MenuSystem)
		-- Probably will just hookup events...  (And so it does)

		print("[MenuSystem] - Disconnecting all events: OnEntrance:")
		
		GenericMenuLevel.Events:clear()

		local CommandBar = WaitForChild(MenuFrame, "CommandBar");
		local BackButton = WaitForChild(CommandBar, "BackButton");
		local MainMenuButton = WaitForChild(CommandBar, "MainMenu")

		GenericMenuLevel.Events:add(BackButton.MouseButton1Click:connect(function()
			--print("[MenuSystem] - Back button clicked");
			if not MenuSystem.Animating then
				MenuSystem:ReduceLevel()
			end
		end))

		GenericMenuLevel.Events:add(BackButton.MouseEnter:connect(function()
			BackButton.Icon.Image = Images.BackButtonOver 
		end))

		GenericMenuLevel.Events:add(BackButton.MouseLeave:connect(function()
			BackButton.Icon.Image = Images.BackButtonRegular 
		end))

		GenericMenuLevel.Events:add(MainMenuButton.MouseEnter:connect(function()
			MainMenuButton.Icon.Image = Images.MenuButtonOver 
		end))

		GenericMenuLevel.Events:add(MainMenuButton.MouseLeave:connect(function()
			MainMenuButton.Icon.Image = Images.MenuButtonRegular
		end))

		GenericMenuLevel.Events:add(MainMenuButton.MouseButton1Click:connect(function()
			--print("[MenuSystem] - MainMenuButton clicked");
			if not MenuSystem.Animating then
				MenuSystem:GoToHome()
			end
		end))
	end

	function GenericMenuLevel.OnLeave(MenuFrame, MenuSystem)
		-- WIll only fire if it's being "left" as in the snse of reducing it's menu level below this ones. That means if it's sliding to the right, it won't fire this,
		-- but sliding to the left will. :)

		print("[MenuSystem] - Disconnecting all events: OnLeave:")
		local CommandBar = WaitForChild(MenuFrame, "CommandBar");
		local BackButton = WaitForChild(CommandBar, "BackButton");
		local MainMenuButton = WaitForChild(CommandBar, "MainMenu")

		BackButton.Icon.Image = Images.BackButtonRegular;
		MainMenuButton.Icon.Image = Images.MenuButtonRegular

		GenericMenuLevel.Events:clear()
	end
end)

lib.MakeMenuLevel = MakeGenericMenuLevel;
lib.makeMenuLevel = MakeGenericMenuLevel;

lib.MakeGenericMenuLevel = MakeGenericMenuLevel;
lib.makeGenericMenuLevel = MakeGenericMenuLevel;


local MakeListMenuLevel = class 'ListMenuLevel' (function(ListMenuLevel, Title)
	ListMenuLevel.MainMenuFrame = nil;

	local MenuLevelBase = MakeGenericMenuLevel(Title)
	local Buttons = {}
	ListMenuLevel.Buttons = Buttons
	local ButtonHover
	local ButtonHoverHeight
	local ButtonHoverPosition
	local OffsetX = 15

	ListMenuLevel.Events = MenuLevelBase.Events
	ListMenuLevel.ButtonHoverAnimationTime = 0.15

	ListMenuLevel.ButtonEnter = CreateSignal();
	ListMenuLevel.ButtonLeave = CreateSignal();
	ListMenuLevel.ButtonClick = CreateSignal();

	local function UpdateMenuButtons(MenuFrame, ButtonHover)
		local NumberOfMenuButtons = 0;
		ButtonHoverHeight = ButtonHover.AbsoluteSize.Y
		ButtonHoverPosition = ButtonHover.Position;


		for _, Button in pairs(Buttons) do
			if not Button.Gui then
				Button.DisconnectEvents();

				Button.Gui = make "TextButton" {
					Parent = MenuFrame;
					Size = ButtonHover.Size + UDim2.new(0, -OffsetX, 0, 0);
					TextXAlignment = "Left";
					Position = ButtonHoverPosition + UDim2.new(0, 0, 0, ButtonHoverHeight * (NumberOfMenuButtons)) + UDim2.new(0, OffsetX, 0, 0); 
					ZIndex = 4;
				}
				Modify(Button.Gui, Styles.SubMenuButton);
				Button:Render(Button.Gui);

				Button:AddEvent(Button.OnEnter:connect(function()
					if Button.Gui then
						Modify(Button.Gui, Styles.SubMenuButtonOver)
						local LocalPos = Button.Gui.Position
						ButtonHover:TweenPosition(UDim2.new(0, 0, LocalPos.Y.Scale, LocalPos.Y.Offset), "Out", "Sine", ListMenuLevel.ButtonHoverAnimationTime, true)
						ListMenuLevel.ButtonEnter:fire(Button)
					end
				end))

				Button:AddEvent(Button.OnLeave:connect(function()
					if Button.Gui then
						Modify(Button.Gui, Styles.SubMenuButton)
						ListMenuLevel.ButtonLeave:fire(Button)
					end
				end))

				Button:AddEvent(Button.OnClick:connect(function()
					ListMenuLevel.ButtonClick:fire(Button)
				end))

				NumberOfMenuButtons = NumberOfMenuButtons + 1;
			end
		end
	end

	function ListMenuLevel:AddMenuButton(MenuName)
		local NewButton = MakeMenuButton(MenuName)
		table.insert(Buttons, NewButton);

		return NewButton;
	end

	function ListMenuLevel:AddRawButton(NewButton) -- This adds stuff to the main menu level, but expects a raw button. 
		table.insert(Buttons, NewButton);
		--print("[MenuSystem] [ListMenuLevel] - Added Raw Button " .. NewButton.Name)
		return NewButton;
	end

	function ListMenuLevel.InitialRender()
		local MenuFrame = MenuLevelBase.InitialRender()

		ButtonHover = make "Frame" {
			Size   = UDim2.new(1, 0, 0, 40);
			Position = UDim2.new(0, 0, 0, 100);
			Name   = "ButtonHover";
			Parent = MenuFrame;
			make "Frame" (Table.CopyAndAppend(Styles.Decoration07, {
				Name     = "Decoration";
				Position = UDim2.new(1, -5, -20, 0);
				Size     = UDim2.new(0, 2, 20, 0);
				ZIndex   = 2;
			}));
			make "Frame" (Table.CopyAndAppend(Styles.Decoration07, {
				Name     = "Decoration";
				Position = UDim2.new(1, -5, 1, 0);
				Size     = UDim2.new(0, 2, 20, 0);
				ZIndex   = 2;
			}));
			make "Frame" (Table.CopyAndAppend(Styles.Decoration07, {
				Name     = "DecorationInner";
				Position = UDim2.new(1, -2, 0, 0);
				Size     = UDim2.new(0, 2, 1, 0);
				ZIndex   = 2;
			}));
		}
		Modify(ButtonHover, Styles.BorderlessFrame09)

		UpdateMenuButtons(MenuFrame, ButtonHover)
		return MenuFrame;
	end

	local function AnimateButtonsIn(SwitchDirection)
		-- Animations the buttons in all nice and smooth. If SwitchDirection is true then they come from the other direction.
		local Side = SwitchDirection and -1 or 1
		if ButtonHover then
			for Index, Button in pairs(Buttons) do
				Button.Gui.Position = ButtonHoverPosition + UDim2.new(Side, 0, 0, ButtonHoverHeight * (Index-1))
			end
			print("[Menu System] - Animate Buttons In (Submenu) @ "..Side)
			Spawn(function()

				for Index, Button in pairs(Buttons) do
					Button.Gui:TweenPosition((ButtonHoverPosition + UDim2.new(0, 0, 0, ButtonHoverHeight * (Index-1)) + UDim2.new(0, OffsetX, 0, 0)), "Out", "Elastic", 1, true)
					wait(0.125)
				end
			end)
		else
			print("[Menu System] - Failed Animate Buttons In (Submenu), ButtonHovor nil")
		end
	end

	local function AnimateButtonsOut()
		if ButtonHover then
			print("[Menu System] - Animate Buttons Out (Submenu)")
			for Index, Button in pairs(Buttons) do
				delay(0.0625 * (#Buttons - Index), function()
					Button.Gui:TweenPosition((ButtonHoverPosition + UDim2.new(-1, 0, 0, ButtonHoverHeight * (Index-1)) + UDim2.new(0, OffsetX, 0, 0)), "In", "Elastic", 0.5, true)
				end)
			end
		else
			print("[Menu System] - Failed Animate Buttons In (Submenu), ButtonHovor nil")
		end
	end

	function ListMenuLevel.Show()
		-- When it first becomes visible to the player... But visual elements only. 
		AnimateButtonsIn()
	end

	function ListMenuLevel.ShowBack() 
		-- When going from a higher level (Like 3) to a lower one (Like 2), so buttons should 
		-- translate in cleanerish by coming in the other direction 

		AnimateButtonsIn(true)
	end

	function ListMenuLevel.OnEntrance(MenuFrame, MenuSystem) -- Fires when the list menu is entered (Visible to the player)
		MenuLevelBase.OnEntrance(MenuFrame, MenuSystem)
	end

	function ListMenuLevel.OnLeave(MenuFrame, MenuSystem) -- When the list menu is left (disappears from player's view)
		MenuLevelBase.OnLeave(MenuFrame, MenuSystem)
	end
end)

lib.MakeListMenuLevel = MakeListMenuLevel
lib.makeListMenuLevel = MakeListMenuLevel;


local MakeMenuSystem = class 'MenuSystem' (function(MenuSystem, ScreenGui, Width)

	local MenuButtons = {}
	local NumberOfMenuButtons = 0;
	local CurrentLevels = {} -- Store all of the "GUI Levels" in here. Each level is 1 frame the width of the menu,
	-- so we can slide back and forth (Left and right) per a frame, with each level a... well, level deeper...

	-- Positioning looks like this:
	--[[

    __ __ __ __ __
   |  |  |  |  |  |
   |L0|L1|L2|L3|L4|
   |  |  |  |  |  |
   |__|__|__|__|__|

   However, users can only see 1 level at the time. L0 is the main menu.  When they go to L1, it slides over, so
   it's now like this
 __ __ __ __ __
|  |  |  |  |  |
|L0|L1|L2|L3|L4|  <-- Translates that way.
|  |  |  |  |  |
|__|__|__|__|__|

	Where only L1 is visible (The rest is hidden by ClipsDescendents. When a user goes back a menu, it deletes all
	the menus in front of that menu, say user is on L4. If they go back to L2, then it'll clear out L3 and L4, AFTER
	translating, mind you.

	This is because the previous menus are KNOWN, going back a level will result in these menus being still loaded, but
	menus PAST that are arbitrary, and could  easily be different. 

--]]

	MenuSystem.AnimationTime = 0.35;
	MenuSystem.ButtonHoverAnimationTime = 0.15; -- The mouse over sliding thing in the main menu. 
	MenuSystem.AnimationTimeBack = 0.2; -- When returning to home. 
	MenuSystem.CurrentLevel = 0; -- Transitions left and right. 0 is default. 
	MenuSystem.MenuLevelChange = CreateSignal(); 
	MenuSystem.Animating = false;

	MenuSystem.ButtonEnter = CreateSignal() -- For easy styling/sound effects. 
	MenuSystem.ButtonLeave = CreateSignal() 
	MenuSystem.ButtonClick = CreateSignal()
	MenuSystem.GoingHome = CreateSignal()
	MenuSystem.LevelDeeper = CreateSignal() -- When it goes deeper into the section...
	MenuSystem.LevelUpper = CreateSignal() -- And when it goes closer to the top (Level 0)


	MenuSystem.Closing = CreateSignal()
	MenuSystem.Showing = CreateSignal()

	MenuSystem.Guis = {}

	local MainMenuContainer = make "Frame" {
		Archivable       = false;
		ClipsDescendants = true;
		Draggable        = false;
		Visible          = false;
		Name             = "MainMenuContainer";
		Parent           = ScreenGui;
		Size             = UDim2.new(0, Width, 1, 3); -- Ofset by 3 because of ROBLOX's weird system where it starts offset a bit from the top of the screen... 
		Position = UDim2.new(0, 0, 0, -3);
	}
	Modify(MainMenuContainer, Styles.TransparentFrame)
	MenuSystem.Guis.MainMenuContainer = MainMenuContainer;


	local MainMenu = make "Frame" {
		Archivable = false;
		Size   = UDim2.new(1,0,1,0);
		Name   = "MainMenu";
		Parent = MainMenuContainer;
	}
	Modify(MainMenu, Styles.BorderlessFrame07)

	local ButtonHover = make "Frame" {
		Size   = UDim2.new(1, 0, 0, 75);
		Position = UDim2.new(0, 0, 0.2, 0);
		Name   = "ButtonHover";
		Parent = MainMenu;
		make "Frame" (Table.CopyAndAppend(Styles.Decoration07, {
			Name     = "Decoration";
			Position = UDim2.new(1, -5, -20, 0);
			Size     = UDim2.new(0, 2, 20, 0);
			ZIndex   = 2;
		}));
		make "Frame" (Table.CopyAndAppend(Styles.Decoration07, {
			Name     = "Decoration";
			Position = UDim2.new(1, -5, 1, 0);
			Size     = UDim2.new(0, 2, 20, 0);
			ZIndex   = 2;
		}));
		make "Frame" (Table.CopyAndAppend(Styles.Decoration07, {
			Name     = "DecorationInner";
			Position = UDim2.new(1, -2, 0, 0);
			Size     = UDim2.new(0, 2, 1, 0);
			ZIndex   = 2;
		}));
	}
	Modify(ButtonHover, Styles.BorderlessFrame09)

	local MenuLevelSetLocked = false; -- When true, thene menu won't animate anywhere. 
	local ButtonHoverHeight = ButtonHover.AbsoluteSize.Y; -- I guess for efficiency? 
	local ButtonHoverPosition = ButtonHover.Position

	local function AnimateToLevel(Level, DoNotAnimate, TransitionTime)
		DoNotAnimate = DoNotAnimate or false;
		TransitionTime = TransitionTime or MenuSystem.AnimationTime;

		local Position = UDim2.new(-Level, 0, 0, 0);

		if DoNotAnimate then
			MainMenu.Position = Position
		else
			MainMenu:TweenPosition(Position, "Out", "Sine", TransitionTime, true)
		end
	end

	local AnimationId = 0;

	local function AnimateButtonsIn(Time)
		Time = Time or 0.5;
		print("[Menu System] - Animate Buttons In")
		-- Fancy animations in..
		for Index, Button in pairs(MenuButtons) do
			Button.Gui.Position = ButtonHoverPosition + UDim2.new(-1, 0, 0, ButtonHoverHeight * (Index-1))
		end
		local WaitTime = (Time/2)/#MenuButtons
		Spawn(function()
			for Index, Button in pairs(MenuButtons) do
				Button.Gui:TweenPosition((ButtonHoverPosition + UDim2.new(0, 0, 0, ButtonHoverHeight * (Index-1))), "Out", "Elastic", Time/2, true)
				wait(WaitTime)
			end
		end)
	end
	local function AnimateButtonsOut(Time)
		print("[Menu System] - Animate Buttons Out")
		-- Fancy animations out..
		Time = Time or 0.5;
		local WaitTime = (Time/2)/#MenuButtons
		for Index, Button in pairs(MenuButtons) do
			--print("[MenuSystem] - Delay @ " .. (0.125 * (#MenuButtons - Index)))
			delay(WaitTime * (#MenuButtons - Index), function()
				Button.Gui:TweenPosition((ButtonHoverPosition + UDim2.new(-1, 0, 0, ButtonHoverHeight * (Index-1))), "In", "Elastic", Time/2, true)
			end)
		end
	end

	local function Show(Time)
		--- Show's the menu, animation it in Time...
		Time = Time or 0.75
		MenuSystem:Render(true)
		MainMenuContainer.Position = UDim2.new(0, -Width, 0, 0)
		MainMenuContainer:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Sine", Time/3, true)
		for Index, Button in pairs(MenuButtons) do
			Button.Gui.Position = ButtonHoverPosition + UDim2.new(-1, 0, 0, ButtonHoverHeight * (Index-1))
		end
		MainMenuContainer.Visible = true
		wait(Time/6) -- So we've used 1/2 after this wait...
		MenuSystem.Showing:fire()
		if MenuSystem.CurrentLevel == 0 then
			AnimateButtonsIn(Time/2)
		end
	end
	MenuSystem.Show = Show

	local function Hide(Time)
		Time = Time or 0.75
		MenuSystem:Render(true)
		if MenuSystem.CurrentLevel == 0 then
			AnimateButtonsOut(Time/2)
		elseif CurrentLevels[MenuSystem.CurrentLevel].Hide then
			CurrentLevels[MenuSystem.CurrentLevel].Hide(Time)
		end
		wait(Time/2)
		MenuSystem.Closing:fire()
		MainMenuContainer:TweenPosition(UDim2.new(0, -Width, 0, 0), "Out", "Sine", Time/2, true)
		
	end
	MenuSystem.Hide = Hide

	local function SetLevel(LevelNumber, DoNotAnimate, TransitionTime)  
		-- Sets the menu level, but really not the way I want to implement it... OH WELL. :D

		if not MenuLevelSetLocked then
			--print("[MenuSystem] - Setting menu level @ "..LevelNumber)
			local OldLevel = MenuSystem.CurrentLevel

			if OldLevel > LevelNumber then
				MenuSystem.LevelUpper:fire(LevelNumber) -- We're going closer to the top (0)
			else
				MenuSystem.LevelDeeper:fire(LevelNumber)
			end 


			TransitionTime = DoNotAnimate and 0 or (TransitionTime or MenuSystem.AnimationTime);
			MenuSystem.CurrentLevel = LevelNumber;

			Spawn(function()
				AnimationId = AnimationId + 1;
				local CurrentAnimationId = AnimationId;

				MenuSystem.Animating = true
				AnimateToLevel(MenuSystem.CurrentLevel, DoNotAnimate);
				--[[if (not DoNotAnimate) and OldLevel == 0 then
					AnimateButtonsOut()
				else--]]

				if (not DoNotAnimate) and LevelNumber == 0 then
					AnimateButtonsIn()
				elseif (not DoNotAnimate) and OldLevel < LevelNumber then -- Animate in the buttons, all fancy... >:D
					if CurrentLevels[LevelNumber].Show then
						CurrentLevels[LevelNumber].Show()
					end
				elseif (not DoNotAnimate) and OldLevel > LevelNumber then
					if CurrentLevels[LevelNumber].ShowBack then
						CurrentLevels[LevelNumber].ShowBack()
					end
				end

				wait(TransitionTime)
				if CurrentAnimationId == AnimationId then
					--print("[MenuSystem] - for i="..OldLevel..", "..(LevelNumber+1)..", -1 do")
					for i=OldLevel, LevelNumber+1, -1 do -- When going backwards, remove them...
						if CurrentLevels[i] then
							--print("Activating onLeave for CurrentLevels["..i.."]")
							local GenericMenuLevel = CurrentLevels[i]
							GenericMenuLevel.OnLeave(GenericMenuLevel.MainMenuFrame, MenuSystem)
							GenericMenuLevel.MainMenuFrame.Parent = nil;
							CurrentLevels[i] = nil;
						else
							print("[MenuSystem] - CurrentLevels["..i.."] = nil?")
						end
					end
					MenuSystem.Animating = false;
					MenuSystem.MenuLevelChange:fire(LevelNumber)
				end
			end)

			return true;
		else
			print("[MenuSystem] - Menu level lock is enabled, can not set level to "..LevelNumber);
			return false;
		end
	end
	MenuSystem.SetLevel = SetLevel

	function MenuSystem:AddMenuLayer(GenericMenuLevel)
		--print("[MenuSystem] - Adding Menu Layer");
		for Index, Value in pairs(CurrentLevels) do
			if Value == GenericMenuLevel then
				error("MenuLevel "..Index.." has already been added to the MenuSystem", 2)
			end
		end

		CurrentLevels[MenuSystem.CurrentLevel + 1] = GenericMenuLevel;
		local MainFrame = GenericMenuLevel.MainMenuFrame or GenericMenuLevel.InitialRender()
		Modify(MainFrame, {
			Name = "MenuLevel"..(MenuSystem.CurrentLevel + 1);
			Parent = MainMenu;
			Position = UDim2.new((MenuSystem.CurrentLevel + 1), 0, 0, 0);
		})
		GenericMenuLevel.MainMenuFrame = MainFrame;
		GenericMenuLevel.OnEntrance(MainFrame, MenuSystem);
		SetLevel(MenuSystem.CurrentLevel + 1)
		return GenericMenuLevel
	end

	function MenuSystem:Render(DoNotAnimate, NewWidth)
		--print("[MenuSystem] - Rendering Menu");

		Width = NewWidth or Width;

		MainMenuContainer.Size = UDim2.new(0, Width, 1, 2);
		SetLevel(MenuSystem.CurrentLevel, DoNotAnimate)

		for _, Button in pairs(MenuButtons) do
			--print("[MenuSystem] - Rendering Button ");
			if not Button.Gui then
				--print("[MenuSystem] - Rendering Button / Making New Button");
				Button.DisconnectEvents(); 

				Button.Gui = make "TextButton" {
					Parent = MainMenu;
					Size = ButtonHover.Size;
					Position = ButtonHoverPosition + UDim2.new(0, 0, 0, ButtonHoverHeight * (NumberOfMenuButtons));
					ZIndex = 3;
				}
				Modify(Button.Gui, Styles.MenuButton);
				Button:Render(Button.Gui);

				Button:AddEvent(Button.OnEnter:connect(function()
					--print "Button entered";
					if Button.Gui then
						Modify(Button.Gui, Styles.MenuButtonOver);
						local LocalPos = Button.Gui.Position
						ButtonHover:TweenPosition(UDim2.new(0, 0, LocalPos.Y.Scale, LocalPos.Y.Offset), "Out", "Sine", MenuSystem.ButtonHoverAnimationTime, true)
						MenuSystem.ButtonEnter:fire(Button)
					end
				end))

				Button:AddEvent(Button.OnLeave:connect(function()
					if Button.Gui then
						Modify(Button.Gui, Styles.MenuButton);
						MenuSystem.ButtonLeave:fire(Button)
					end
				end))

				Button:AddEvent(Button.OnClick:connect(function()
					MenuSystem.ButtonClick:fire(Button);
				end))

				NumberOfMenuButtons = NumberOfMenuButtons + 1;
			end
		end
	end

	function MenuSystem:ReduceLevel(DoNotAnimate)
		if MenuSystem.CurrentLevel <= 0 then
			error("MenuSystem is already at home level, can not 'reduce level'", 2)
		else
			SetLevel(MenuSystem.CurrentLevel - 1, DoNotAnimate)
		end
	end

	function MenuSystem:GoToHome(DoNotAnimate)
		SetLevel(0, DoNotAnimate)  
	end



	function MenuSystem:AddMenuButton(MenuName) -- This adds stuff to the main menu level.  
		local NewButton = MakeMenuButton(MenuName)
		table.insert(MenuButtons, NewButton);

		return NewButton;
	end

	function MenuSystem:AddRawButton(NewButton) -- This adds stuff to the main menu level, but expects a raw button. 
		table.insert(MenuButtons, NewButton);

		return NewButton;
	end

	function MenuSystem:GetButtons()
		return Table.Copy(MenuButtons); -- We want to keep our stuff at least fairly secure and clean. 
	end

	function MenuSystem:GetLevel()
		return MenuSystem.CurrentLevel
	end
end)

lib.MakeMenuSystem = MakeMenuSystem;

NevermoreEngine.RegisterLibrary('MenuSystem', lib);