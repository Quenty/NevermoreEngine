local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local Table                   = LoadCustomLibrary("Table")
local qString                 = LoadCustomLibrary("qString")
local qGUI                    = LoadCustomLibrary("qGUI")
local ScrollBar               = LoadCustomLibrary("ScrollBar")
local EventGroup              = LoadCustomLibrary("EventGroup")
local OverriddenConfiguration = LoadCustomLibrary("OverriddenConfiguration")

-- BoxInventoryRender.lua
-- @author Quenty
-- This library handles rendering the BoxInventory in 2D for interaction. It also handles, or course, player interaction
-- with it. It's basically split between datastructures and rendering structures. 

--[[ -- Change Log
---- NOTE INDIVIDUAL CHANGE LOGS ARE NOW ALSO MAINTAINED PER A CLASS. GLOBAL CHANGES LISTED HERE (Changes related to whole system)
Feburary 16th, 2014
- Fixed label issue with Open inventory button

February 15th, 2014
- Added "show" icon with a quick info GUI.

February 13th, 2014
- OverriddenConfiguration is now semi-utilized

February 7th, 2014
- Updated to name BoxInventoryRender (previous InventoryRender)
- Updated to use BoxInventory
- Added change log
- Updated to use ClientInventoryInterface (From BoxInventoryManager) for localside interactions

February 3rd, 2014
- Updated to new Nevermore System
- Updated to use new class system.

--]]

qSystems:Import(getfenv(0))

local lib = {}

----------------------
-- INTERNAL UTILITY --
----------------------

local function MakeTitleFrame(Parent, Title, Subtitle, ZIndex, Height, XOffset)
	--- Generates the top 'header frame' at the top.
	--[[ Looks something like this:
	   __________________________
	  |                          |
	  | TITLE HERE               |
	  | TITLE HERE Subtitle      |
	  |__________________________|
	--]]

	-- @param Parent the parent of the TitleFrame, which must be rendered to get the right rendering.
	-- @param Title the title of the frame
	-- @param [Subtitle] the subtitle to display. Will auto offset from title.
	-- @param [ZIndex] the ZIndex of the title frame. 
	-- @param [Height] the height of the title frame to be. 
	-- @param [XOffset] the offset from the left (X Axis)
	-- @pre The GUI must be a descendent of a PlayerGui in order for the Subtitle to be rendered correctly.
	-- @post Subtitle is only parented to the TitleFrame is it Subtitle ~= "" and Subtitle is given.
	-- @return TitleFrame -- the title frame that was generated. Used by MakeBox2DRender... Helper function.
	
	Height = Height or 50;
	XOffset = XOffset or 10;

	local TitleFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 0.3;
		BorderSizePixel        = 0;
		ClipsDescendants       = true; -- Make sure if the Title goes past the size, we can still work....
		Name                   = "TitleFrame";
		Parent                 = Parent;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 0, Height);
		Visible                = true;
		ZIndex                 = ZIndex;
	}

	local Title = Make 'TextLabel' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "Arial";
		FontSize               = "Size24";
		Name                   = "Title";
		Parent                 = TitleFrame;
		Position               = UDim2.new(0, XOffset, 0, 0);
		Size                   = UDim2.new(1, -XOffset, 1, -10);
		Text                   = Title;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeTransparency = 1;
		TextXAlignment         = "Left";
		TextYAlignment         = "Bottom";
		Visible                = true;
		ZIndex                 = ZIndex;
	}

	local TitleSpace = Title.TextBounds.X + 5;

	if Subtitle and Subtitle ~= "" then
		local Subtite = Make 'TextLabel' {
			Archivable             = false;
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Font                   = "Arial";
			FontSize               = "Size14";
			Name                   = "Title";
			Parent                 = TitleFrame;
			Position               = UDim2.new(0, XOffset + TitleSpace, 0, 0);
			Size                   = UDim2.new(1, -TitleSpace - XOffset, 1, -12);
			Text                   = Subtitle;
			TextColor3             = Color3.new(1, 1, 1);
			TextStrokeTransparency = 1;
			TextXAlignment         = "Left";
			TextYAlignment         = "Bottom";
			Visible                = true;
			ZIndex                 = ZIndex;
		}
	end

	return TitleFrame;
end

local function RenderSizeIcon(IconSize, GridSize, Color, ZIndex, SetSolidColor)
	--- Render's a SizeIcon that is broken up like a grid.
	-- @param IconSize size of the icon in pixels (Single number)
	-- @param GridSize the number of seperations to make
	-- @param Color the color of the hightlighted icon.
	-- @param SetSolidColor If true, will set the whole grid to be the color of "Color"
	
	local RenderFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "SizeIcon";
		Size                   = UDim2.new(0, IconSize, 0, IconSize);
		Visible                = true;
		ZIndex                 = ZIndex;
	}

	Color = Color or Color3.new(0.5, 0.5, 0.5);

	local RegularColor = Color3.new(0.8, 0.8, 0.8)
	local SpacingSize = 2
	local FrameSize = math.floor((IconSize - (SpacingSize * (GridSize - 1)))/GridSize) -- Almost like LISP.
	local Offset = (IconSize - (((FrameSize + SpacingSize) * GridSize) - SpacingSize))/2
	--print("[RenderSizeIcon] - FrameSize : "..((((FrameSize + SpacingSize) * GridSize) - SpacingSize)))
	--print("[RenderSizeIcon] - Offset = "..Offset)

	-- Yeah, look at all these loops. It's beautiful!
	for XPosition = 0, (GridSize - 1) do
		for YPosition = 0, (GridSize - 1) do
			local BoxPartFrame = Make 'Frame' {
				Archivable       = false;
				BackgroundColor3 = SetSolidColor and Color or RegularColor;
				BorderSizePixel  = 0;
				Name             = "BoxPart-" .. XPosition .. "-" .. YPosition;
				Parent           = RenderFrame;
				Size             = UDim2.new(0, FrameSize, 0, FrameSize);
				Visible          = true;
				ZIndex           = ZIndex;
				Position         = UDim2.new(0, Offset + ((FrameSize * XPosition) + ((XPosition) * SpacingSize)), 0, Offset + ((FrameSize * YPosition) + (YPosition * SpacingSize)));
			}
		end
	end

	-- Set that last color
	RenderFrame["BoxPart-0-"..(GridSize-1)].BackgroundColor3 = Color
	return RenderFrame
end

--[[
Change Log

February 16th, 2014
- Added GC Destroy function.

February ??th, 2014
- Made Configuration use OverriddenConfiguration 

--]]
local function MakeCollapseButton(State, Configuration)
	--- Makes a minimize/maximize window icon.
	-- @param State If true, shows the maximize button, otherwise shows the minimze button.
	-- @param ZIndex The ZIndex of the button.
	
	State = State or false; -- Presume if no state is given that the window is shown.

	Configuration = OverriddenConfiguration.new(Configuration, {
		DefaultTransparency    = 0.3;
		Color                  = Color3.new(1, 1, 1);
		ZIndex                 = 1;
		OnOverTransparency     = 0;
		TransparencyChangeTime = 0.1;
		DoAnimateOnOver        = true;
	})
	local Button = {}
	
	local CollapseButton = Make 'ImageButton' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BackgroundColor3       = Configuration.Color;
		Image                  = "";
		Size                   = UDim2.new(0, 30, 0, 25);
		ZIndex                 = Configuration.ZIndex + 1;
		BorderSizePixel        = 0;
		Make 'Frame' {
			Name                   = "Minimize";
			ZIndex                 = Configuration.ZIndex;
			Archivable             = false;
			BorderSizePixel        = 0;
			BackgroundColor3       = Configuration.Color;
			Position               = UDim2.new(0.1, 0, 0.6, 0);
			Style                  = "Custom";
			Visible                = false;
			BackgroundTransparency = Configuration.DefaultTransparency;
			Size                   = UDim2.new(0.8, 0, 0.2, 0);
		};
		Make 'Frame' {
			Name                   = "Maximize";
			ZIndex                 = ZIndex;
			Archivable             = false;
			BorderSizePixel        = 0;
			BackgroundTransparency = 1;
			Position               = UDim2.new(0, 0, 0, 0);
			Style                  = "Custom";
			Visible                = false;
			Size                   = UDim2.new(1, 0, 1, 0);
			Make 'Frame' {
				ZIndex                 = Configuration.ZIndex;
				Archivable             = false;
				BorderSizePixel        = 0;
				BackgroundTransparency = Configuration.DefaultTransparency;
				BackgroundColor3       = Configuration.Color;
				Position               = UDim2.new(0.1, 0, 0.2, 0);
				Size                   = UDim2.new(0.8, 0, 0.25, 0);
			};
			Make 'Frame' {
				ZIndex                 = Configuration.ZIndex;
				Archivable             = false;
				BorderSizePixel        = 0;
				BackgroundTransparency = Configuration.DefaultTransparency;
				BackgroundColor3       = Configuration.Color;
				Position               = UDim2.new(0.1, 0, 0.75, 0);
				Size                   = UDim2.new(0.8, 0, 0.1, 0);
			};
			Make 'Frame' {
				ZIndex                 = Configuration.ZIndex;
				Archivable             = false;
				BorderSizePixel        = 0;
				BackgroundTransparency = Configuration.DefaultTransparency;
				BackgroundColor3       = Configuration.Color;
				Position               = UDim2.new(0.8, 0, 0.45, 0);
				Size                   = UDim2.new(0.1, 0, 0.3, 0);
			};
			Make 'Frame' {
				ZIndex                 = Configuration.ZIndex;
				Archivable             = false;
				BorderSizePixel        = 0;
				BackgroundTransparency = Configuration.DefaultTransparency;
				BackgroundColor3       = Configuration.Color;
				Position               = UDim2.new(0.1, 0, 0.45, 0);
				Size                   = UDim2.new(0.1, 0, 0.3, 0);
			};
		};
	}
	Button.Gui = CollapseButton
	
	function Button.SetState(DoShowMaximize)
		-- Updates the state and updatess accordingly.

		State = DoShowMaximize;
		if DoShowMaximize then
			CollapseButton.Minimize.Visible = false;
			CollapseButton.Maximize.Visible = true;
		else
			CollapseButton.Minimize.Visible = true;
			CollapseButton.Maximize.Visible = false;
		end
	end
	
	function Button.GetState()
		-- @return The current displayed state of the button.
		return State;
	end
	
	Button.SetState(State);
	
	if Configuration.DoAnimateOnOver then
		-- Setup animation events.

		CollapseButton.MouseEnter:connect(function()
			for _, Item in pairs(CollapseButton.Maximize:GetChildren()) do
				qGUI.TweenTransparency(Item, {BackgroundTransparency = Configuration.OnOverTransparency}, Configuration.TransparencyChangeTime, true)
			end
			qGUI.TweenTransparency(CollapseButton.Minimize, {BackgroundTransparency = Configuration.OnOverTransparency}, Configuration.TransparencyChangeTime, true)
		end)
		CollapseButton.MouseLeave:connect(function()
			for _, Item in pairs(CollapseButton.Maximize:GetChildren()) do
				qGUI.TweenTransparency(Item, {BackgroundTransparency = Configuration.DefaultTransparency}, Configuration.TransparencyChangeTime, true)
			end
			qGUI.TweenTransparency(CollapseButton.Minimize, {BackgroundTransparency = Configuration.DefaultTransparency}, Configuration.TransparencyChangeTime, true)
		end)
	end

	function Button:Destroy()
		--- Destroy's the button

		-- Stop animations if they are running.
		for _, Item in pairs(CollapseButton.Maximize:GetChildren()) do
			qGUI.StopTransparencyTween(Item)
		end
		qGUI.StopTransparencyTween(CollapseButton.Minimize)

		-- Clean up GUIs
		CollapseButton:Destroy()
		Configuration = nil
		State         = nil

		-- Whole class declaration cleaned up. 
		for Index, Item in pairs(Button) do
			Button[Index] = nil
		end
	end
	
	return Button;
end

local MakePercentFilledImage = Class(function(PercentFilledImage, ImageLabel, FullIcon, Axis, Inverse)
	--- Makes a 'percent' filled object that displays an image based on how much it's filled up.
	-- @param ImageLabel the image label used when filling it. Should contain the "Empty" icon.
	-- @param FullIcon the icon when it's full. Asset URL.
	-- @param Axis the axis of which to operate. 
	-- @param Inverse should Default is start hiding from left to right, and up to down, 
	--        depending on axix. So at 75% full, the 25% not displayed would be on the right, or at the top or left.
	--        This param, if true, will inverse that. 

	-- Used with hearts, et. cetera. Really only used here so far. May be moved to a seperate system later.

	Inverse = Inverse or false;
	Inverse = Axis or 'Y'

	local CurrentPercent = 1; -- readonly
	PercentFilledImage.Gui = ImageLabel;

	local RenderFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = true;
		Name                   = "DisplayHidePercent";
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 1, 0);
		Visible                = true;
		ZIndex                 = ImageLabel.ZIndex;
	}

	local FullIcon = Make 'ImageLabel' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = true;
		Image                  = FullImage;
		Name                   = "FullImage";
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 1, 0);
		Visible                = true;
		ZIndex                 = ImageLabel.ZIndex;
	}

	local function Update()
		-- Used to update rendering. Automatically called on Change. 
		-- @post updating is fixed. 

		if Axis == 'Y' then
			RenderFrame.Size = UDim2.new(CurrentPercent, 0, 1, 0)
			if Inverse then
				FullIcon.Position = UDim2.new(0, 0, 0, 0);
			else
				FullIcon.Size = UDim2.new(1/CurrentPercent, 0, 1, 0)
				FullIcon.Position = UDim2.new(1 - (1/CurrentPercent), 0, 1, 0) 
			end
		else
			RenderFrame.Size = UDim2.new(1, 0, CurrentPercent, 0)
			if Inverse then
				FullIcon.Size = UDim2.new(1, 0, 1/CurrentPercent, 0)
				FullIcon.Position = UDim2.new(1, 0, 1 - (1/CurrentPercent), 0) 
			else
				FullIcon.Position = UDim2.new(0, 0, 0, 0);
			end
		end
	end
	PercentFilledImage.Update = Update;
	PercentFilledImage.update = Update;

	local function SetPercent(Percent)
		--- Set's the percent and updates teh GUI. 
		-- @param Percent a number from 0 to 1. 1 is completely full, 0 is hidden/empty.
		-- @post percent is done, and GUI is updated accordingly. 

		CurrentPercent = Percent
		Update()
	end
	PercentFilledImage.SetPercent = SetPercent
	PercentFilledImage.setPercent = SetPercent

	local function GetCurrentPercent()
		--- Return'st he current percent

		return CurrentPercent
	end
	PercentFilledImage.GetCurrentPercent = GetCurrentPercent
	PercentFilledImage.getCurrentPercent =GetCurrentPercent

	local function Destroy()
		--- Destroy's and garbage collects it.
		-- @post completely GC

		for Index, Value in pairs(PercentFilledImage) do
			PercentFilledImage[Index] = nil;
		end
	end
	RenderFrame:Destroy()
	PercentFilledImage.Destroy = Destroy

	Update()
end)
lib.MakePercentFilledImage = MakePercentFilledImage
lib.makePercentFilledImage = MakePercentFilledImage

-- Used by OptionSystem
local function GetCenterY(ScreenGui, RenderHeightY)
	--- Get's the Y.Offset factor of a screenGUI, and frame (withthe RenderHeightY given), 
	--- Used internally by the options module
	-- @return Number value that the UDim2Y should be set to

	local Height = ScreenGui.AbsoluteSize.Y;
	return (Height - RenderHeightY)/2
end

-- Used by BoxInventoryRenderCard
local function MakeIconedFrame(IconFrame, Text, ZIndex, XOffset)
	-- Makes a frame with the icon on the left and the text on the right.
	-- @param IconFrame A ROBLOX GUI element, it uses it's Size.Y.Offset to determine it's own height.
	-- @param Text the text to generate
	-- @param [ZIndex] The index of the frame
	-- @param [XOffset] The XOffset between the text and the icon. So the text isn't directly against the frame.

	--- The IconFrame will be offset by XOffset
	-- The Text will have the X whitespace as XOffset

	local XOffset = XOffset or 10
	ZIndex = ZIndex or IconFrame.ZIndex;

	local MainFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "BoxInventoryRenderCard";
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 0, IconFrame.Size.Y.Offset);
		Visible                = true;
		ZIndex                 = ZIndex;
	}

	IconFrame.Parent   = MainFrame;
	IconFrame.Position = UDim2.new(0, XOffset, 0, 0)

	local TextLabel = Make 'TextLabel' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "Arial";
		FontSize               = "Size14";
		Name                   = "TextLabel";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, IconFrame.Size.X.Offset + XOffset*2, 0, 0);
		Size                   = UDim2.new(1, -(IconFrame.Size.X.Offset + (XOffset*3)), 1, 0);
		Text                   = Text;
		TextColor3             = Color3.new(64/255, 64/255, 64/255);
		TextStrokeTransparency = 1;
		TextWrapped            = true;
		TextXAlignment         = "Left";
		TextYAlignment         = "Center";
		Visible                = true;
		ZIndex                 = ZIndex;
	}

	return MainFrame
end


------------------------
-- MAIN CLASS SYSTEMS --
------------------------
--[[
Change Log
- Added SelectionChanged event.

--]]
local MakeBoxSelection = Class(function(BoxSelection, Box2DInterface)
	-- Datastructure to handle the selection of items...
	-- @param Box2DInterface The Box2DInterface associated with the selection. The Box2DInterface will
	--                       be automatically created.

	-- Note that the selection service is based upon the render interface, not the items themselves.

	local Selected = {}
	local SelectedListCache -- Cache selection list.

	BoxSelection.SelectionAdded        = CreateSignalInternal() -- When a single new item is selected. Will fire many times relative to
	                                           -- SelectionGroupAdded's firing rate.
	BoxSelection.SelectionGroupAdded   = CreateSignalInternal() -- When a group is added. Cut down on calcuations..
	BoxSelection.SelectionRemoved      = CreateSignalInternal() -- Like above, but when an item is unselected. 
	BoxSelection.SelectionGroupRemoved = CreateSignalInternal() -- Like above, but when an item is unselected. 
	
	BoxSelection.SelectionChanged      = CreateSignalInternal() -- This one is fired when the counts inside of the selection change.
	-- Also fired when group events fires.

	-- Note that firing is done via outside items of the class too....

	local function Select(self, ...)
		-- Select's an object, if it can be selected.
		-- @pre Item is a Box2DRenderItem

		-- Note, this isn't selecting items, but rather, selecting visible interfaces. This means unselect must
		-- reference Item.Interfaces.Box2DInventory.BoxInventoryRender

		SelectedListCache = nil; -- Clear Cache, selection has changed.
		local ToSelect = {...}
		local SelectedList = {}
		for _, Box2DRenderItem in pairs(ToSelect) do
			assert(Box2DRenderItem.IsBox2DRenderItem, "Box2DRenderItem.IsBox2DRenderItem == "..tostring(Box2DRenderItem.IsBox2DRenderItem)..", cannot select none Box2DRenderItem")
			
			if not Box2DRenderItem.Selected then
				Box2DRenderItem.Selected = true;

				SelectedList[#SelectedList+1] = Box2DRenderItem;
				table.insert(Selected, Box2DRenderItem);

				Box2DRenderItem.ShowSelection()
				BoxSelection.SelectionAdded:fire(Item)
				--print("[BoxSelection] - Selected Item")
			else
				print("[BoxSelection][Select] - Item already selected, cannot reselect")
			end
		end
		if #SelectedList >= 1 then
			BoxSelection.SelectionGroupAdded:fire(SelectedList)
			BoxSelection.SelectionChanged:fire()
		end
	end
	BoxSelection.Select = Select;
	BoxSelection.Select = Select;

	local function IsSelected(Box2DRenderItem)
		return Box2DRenderItem.Selected
	end
	BoxSelection.IsSelected = IsSelected;
	BoxSelection.isSelected = IsSelected;--]]

	local function Unselect(self, ...)
		-- Unselects items
		-- @pre Item has property "Render" which is a Box2DRenderItem

		-- Note, this isn't selecting items, but rather, selecting visible interfaces. This means unselect must
		-- reference Item.Interfaces.Box2DInventory.BoxInventoryRender

		SelectedListCache = nil; -- Clear Cache, selection has changed.
		local ToUnselect = {...}
		local UnselectedItems = {}
		for _, Box2DRenderItem in pairs(ToUnselect) do
			assert(Box2DRenderItem.IsBox2DRenderItem, "Box2DRenderItem.IsBox2DRenderItem == "..tostring(Box2DRenderItem.IsBox2DRenderItem)..", cannot select none Box2DRenderItem")
			
			if Box2DRenderItem.Selected then
				Box2DRenderItem.Selected = false;
				BoxSelection.SelectionRemoved:fire(Box2DRenderItem)

				UnselectedItems[#UnselectedItems+1] = Box2DRenderItem; -- Add for the SelectionGroupRemoved event.

				-- Safely remove, index backwards.
				for Index = #Selected, 1, -1 do
					if Selected[Index] == Box2DRenderItem then
						table.remove(Selected, Index)
					end
				end

				Box2DRenderItem.HideSelection()
			else
				print("[BoxSelection][Unselect] - Item not selected in the first place, can't unselect")
			end
		end
		if #UnselectedItems >= 1 then
			BoxSelection.SelectionGroupRemoved:fire(UnselectedItems)
			BoxSelection.SelectionChanged:fire()
		end
	end
	BoxSelection.Unselect = Unselect
	BoxSelection.unselect = Unselect

	local function GetSelection()
		-- Return's the actual items selected. Kind of expensive?
		if not SelectedListCache then
			local SelectedList = {}

			for _, Box2DRenderItem in pairs(Selected) do
				Table.Append(SelectedList, Box2DRenderItem.GetItems())
			end

			SelectedListCache = SelectedList;
			return SelectedList;
		else
			return SelectedListCache
		end
	end
	BoxSelection.GetSelection = GetSelection
	BoxSelection.getSelection = GetSelection

	local function GetSelectionClasses()
		return Selected;
	end
	BoxSelection.GetSelectionClasses = GetSelectionClasses
	BoxSelection.getSelectionClasses = GetSelectionClasses

	local function UnselectAll(self)
		-- Unselects all the items...

		BoxSelection:Unselect(unpack(Selected))
	end
	BoxSelection.UnselectAll = UnselectAll;
	BoxSelection.unselectAll = UnselectAll
end)

--[[ Change Log

February 13th, 2014
- Added Configuration argument

--]]
local MakeBox2DRenderItem = Class(function(Box2DRenderItem, Item, BoxInventoryRender, ItemColor, Configuration)
	--  Will probably be removed/added a lot.. Only one should exist per an item. Used internally. 

	-- Local variables
	ItemColor = ItemColor or Color3.new(199/255, 244/255, 100/255) -- Let's use this pallet -- http://www.colourlovers.com/palette/1930/cheer_up_emo_kid

	-- Global variables.

	local Configuration = OverriddenConfiguration.new(Configuration, {
		DefaultTransparency           = 1; -- Normal transparency...
		SelectedTransparency          = 0.4; -- Transparency when the item is selected. 
		MouseOverTransparencyChange   = 0.8; -- Transparency when the mouse is over it. Inversed.
		TransparencyChangeTime        = 0.1; -- How long it takes to change the transparency. 
		ZIndex                        = BoxInventoryRender.Box2DInterface.Configuration.ZIndex; -- Takes over 3 spaces. 
		NameLabelPixelOffset          = 10; -- How far from the left it's offset.
		NameLabelPixelOffsetMouseDown = 15;
		CountLabelPixelOffset         = 5;
		MouseDownChangeTime           = 0.2; -- For mouseDown animations.
		Height                        = 40;
		CheckmarkIconSize             = 20; -- In pixels
		GridSizeIconSize              = 30;
		CheckmarkIcon                 = "http://www.roblox.com/asset/?id=136822096"; --"http://www.roblox.com/asset/?id=136821278";
	})
	Configuration.CurrentTransparency = Configuration.DefaultTransparency

	-- Start rendering. 
	local Gui = Make 'ImageButton' { -- MainGui
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "ItemButton"..Item.ClassName;
		Size                   = UDim2.new(1, 0, 0, Configuration.Height);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 2;
		Archivable             = false;
	}
	Box2DRenderItem.Gui = Gui;

	local Container = Make 'Frame' { -- Container GUI
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "Container";
		Parent                 = Gui;
		Size                   = UDim2.new(1, 0, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 1;
	}

	local MouseOverCover = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = Configuration.MouseOverTransparencyChange;
		BorderSizePixel        = 0;
		Name                   = "Cover";
		Parent                 = Gui;
		Size                   = UDim2.new(1, 0, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 1;
	}

	local CheckmarkIcon = Make 'ImageLabel' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "CheckmarkIcon";
		Parent                 = Container;
		Size                   = UDim2.new(0, Configuration.CheckmarkIconSize, 0, Configuration.CheckmarkIconSize);
		Visible                = false;
		Image                  = Configuration.CheckmarkIcon;
		ZIndex                 = Configuration.ZIndex + 2;
	}

	local NameLabel = Make 'TextLabel' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "Arial";
		FontSize               = "Size14";
		Name                   = "NameLabel";
		Parent                 = Container;
		Position               = UDim2.new(0, Configuration.NameLabelPixelOffset, 0, 0);
		Size                   = UDim2.new(1, -Configuration.NameLabelPixelOffset, 0, 40);
		Text                   = Item.ClassName;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeTransparency = 1;
		TextTransparency       = 1;
		TextXAlignment         = "Left";
		TextYAlignment         = "Center";
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 1;
	}

	local CountLabel = Make 'TextLabel' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "Arial";
		FontSize               = "Size14";
		Name                   = "CountLabel";
		Parent                 = Container;
		--Position               = UDim2.new(0, NameLabel.TextBounds.X + Configuration.CountLabelPixelOffset + Configuration.NameLabelPixelOffset, 0, 0);
		--Size                   = UDim2.new(1, -(NameLabel.TextBounds.X + Configuration.CountLabelPixelOffset + Configuration.NameLabelPixelOffset), 0, 40);
		Text                   = "// 1";
		TextColor3             = ItemColor;
		TextStrokeTransparency = 1;
		TextTransparency       = 1;
		TextXAlignment         = "Left";
		TextYAlignment         = "Center";
		Visible                = false;
		ZIndex                 = Configuration.ZIndex + 1;
	}

	--assert(Item.Interfaces.BoxInventory.CrateData.GridSize ~= nil, "Item.Interfaces.BoxInventory.GridSize is nil")
	local SizeIcon                    = RenderSizeIcon(Configuration.GridSizeIconSize, (BoxInventoryRender.Inventory.LargestGridSize + 1) - Item.Interfaces.BoxInventory.CrateData.GridSize, ItemColor, Configuration.ZIndex + 1)
	SizeIcon.Parent                   = Container
	SizeIcon.Position                 = UDim2.new(1, -(Configuration.GridSizeIconSize + ((Configuration.Height - Configuration.GridSizeIconSize)/2)), 0, 5);
	Box2DRenderItem.YRenderHeight     = Configuration.Height;
	
	local MouseOver = false;
	local CurrentItems = {} -- Store items in the inventory render thing.


	-- READ ONLY VALUES --
	Box2DRenderItem.IsBox2DRenderItem = true; -- For selection service debug
	--Box2DRenderItem.BoxInventory      = BoxInventoryRender.BoxInventory -- The active inventory that this is associated with.
	Box2DRenderItem.RenderedClassName = Item.ClassName -- Class name of the item being rendered/represented.
	Box2DRenderItem.Selected = false;

	local MouseDown = false;

	local function Update()
		--- Updates rendering, YRenderHeight;

		Box2DRenderItem.YRenderHeight = Configuration.Height;
		--[[if MouseOver then
			if Container.BackgroundTransparency ~= Configuration.CurrentTransparency + Configuration.MouseOverTransparencyChange then
				qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.CurrentTransparency + Configuration.MouseOverTransparencyChange}, Configuration.TransparencyChangeTime, true)
			end
		else
			if Container.BackgroundTransparency ~= Configuration.CurrentTransparency then
				qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.CurrentTransparency}, Configuration.TransparencyChangeTime, true)
			end
		end--]]
		if not MouseDown then -- Otherwise MouseDown will handle it.
			MouseOverCover.Visible = MouseOver
		end

		if Selected then
			qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.CurrentTransparency - Configuration.SelectedTransparency}, Configuration.TransparencyChangeTime, true)
		else
			qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.CurrentTransparency}, Configuration.TransparencyChangeTime, true)
		end
	end
	Box2DRenderItem.Update = Update;
	Box2DRenderItem.update = Update

	local function ShowSelection()
		--- Renders as if it was selected. 

		print("[BoxSelection] - Showing selection")
		--Configuration.CurrentTransparency = Configuration.SelectedTransparency
		--Selected = true; -- Handled by BoxSelection
		CheckmarkIcon.Visible = true;
		Update()

	end
	Box2DRenderItem.ShowSelection = ShowSelection;
	Box2DRenderItem.showSelection = ShowSelection;

	local function HideSelection()
		--- Renders as if it was not selected. 

		--Configuration.CurrentTransparency = Configuration.DefaultTransparency
		--Selected = false; -- Handled by BoxSelection
		CheckmarkIcon.Visible = false;
		Update()
	end
	Box2DRenderItem.HideSelection = HideSelection;
	Box2DRenderItem.hideSelection = HideSelection;

	local function AnimateShow(DoSetPosition, TimePlay)
		-- Makes it show up coolio... 
		-- @param DoSetPosition if you want the animation to set the position to be at -1.

		TimePlay = TimePlay or 0.25
		if DoSetPosition then
			Container.Position = UDim2.new(-1, 0, 0, 0);
		end
		qGUI.TweenTransparency(NameLabel, {TextTransparency = 0}, TimePlay, true)
		qGUI.TweenTransparency(CountLabel, {TextTransparency = 0}, TimePlay, true)
		--Container.BackgroundTransparency = 1;
		--Update() -- Make fancy transparency animation... :D
		Container:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quart", TimePlay, true)
	end
	Box2DRenderItem.AnimateShow = AnimateShow
	Box2DRenderItem.animateShow = AnimateShow

	local function AnimateHide(TimePlay)
		-- HIdes the GUI, animates it.

		TimePlay = TimePlay or 0.25
		Configuration.CurrentTransparency = 1;
		Container:TweenPosition(UDim2.new(-1, 0, 0, 0), "In", "Quart", TimePlay, true)
		qGUI.TweenTransparency(NameLabel, {TextTransparency = 1}, TimePlay, true)
		qGUI.TweenTransparency(CountLabel, {TextTransparency = 1}, TimePlay, true)
	end
	Box2DRenderItem.AnimateHide = AnimateHide;
	Box2DRenderItem.animateHide = AnimateHide;

	local function GetItemCountPosition()
		-- Return's the position that the itemCount is suppose to be at. Since this varies a lot... well, here we are

		if MouseDown then
			return UDim2.new(0, NameLabel.TextBounds.X + Configuration.CountLabelPixelOffset + Configuration.NameLabelPixelOffset, 0, 0);
		else
			return UDim2.new(0, NameLabel.TextBounds.X + Configuration.NameLabelPixelOffsetMouseDown + Configuration.NameLabelPixelOffset, 0, 0);
		end
	end

	local function Select()
		-- Selects the item. Just a simplification.

		BoxInventoryRender.Box2DInterface.BoxSelection:Select(Box2DRenderItem)
	end
	Box2DRenderItem.Select = Select
	Box2DRenderItem.select = Select

	local function Unselect()
		-- Unselects the item. Just a simplification.

		BoxInventoryRender.Box2DInterface.BoxSelection:Unselect(Box2DRenderItem)
	end
	Box2DRenderItem.Unselect = Unselect
	Box2DRenderItem.unselect = Unselect

	local function GetCurrentItemCount()
		-- Return's the Current item count being rendered

		return #CurrentItems
	end
	Box2DRenderItem.GetCurrentItemCount = GetCurrentItemCount
	Box2DRenderItem.getCurrentItemCount = GetCurrentItemCount

	local function UpdateItemCount()
		-- Updates rendering/item count
		-- TODO: Animate better

		local CurrentItemCount = GetCurrentItemCount()

		CountLabel.Text = "// "..CurrentItemCount
		if CurrentItemCount > 1 then
			CountLabel.Visible = true;
		else
			CountLabel.Visible = false;
		end
		CountLabel.Size = UDim2.new(1, -(NameLabel.TextBounds.X + Configuration.CountLabelPixelOffset + Configuration.NameLabelPixelOffset), 0, 40);
		CountLabel.Position = GetItemCountPosition()
	end

	local function AddItemToSlot(Item)
		--- Add's an item into the slot. Called automatically with the first item given.

		CurrentItems[#CurrentItems+1] = Item;
		UpdateItemCount()

		-- Update selection change, so the option modules change. Yes, it's this complicated.
		BoxInventoryRender.Box2DInterface.BoxSelection.SelectionChanged:fire()
	end
	Box2DRenderItem.AddItemToSlot = AddItemToSlot;
	Box2DRenderItem.addItemToSlot = AddItemToSlot

	local function GetItemIndex(Item)
		--- Return's an item's index in the CurrentItem's list
		-- @param Item The item to find the index of
		-- @pre The item is in the list
		-- @return The item's index

		for Index, ItemInList in pairs(CurrentItems) do
			if ItemInList.UID == Item.UID then
				return Index
			end
		end
		return nil;
	end
	Box2DRenderItem.GetItemIndex = GetItemIndex
	Box2DRenderItem.getItemIndex = GetItemIndex

	local function RemoveItemFromSlot(Item, DoNotFireEvent)
		--- Used internally to remove an item from the slot.
		-- @pre The item is in the list
		-- @param Item the item to remove
		-- @param DoNotFireEvent Boolean, if true, won't fire selection change event. Used by GC
		-- @return The item removed
		-- Kind of expensive

		local ItemIndex = GetItemIndex(Item)
		if ItemIndex then
			local Removed = table.remove(CurrentItems, ItemIndex)
			UpdateItemCount()

			-- Update selection change, so the option modules change. Panic. Now.
			if not DoNotFireEvent then
				BoxInventoryRender.Box2DInterface.BoxSelection.SelectionChanged:fire()
			end

			return Removed
		else
			error("[BoxInventoryRender][RemoveItemFromSlot] - ItemIndex could not be identified, the item is not in the slot.")
			return nil
		end
		
	end
	Box2DRenderItem.RemoveItemFromSlot = RemoveItemFromSlot
	Box2DRenderItem.removeItemFromSlot = RemoveItemFromSlot

	local function GetLastItem()
		-- Return's the last item in the list of items

		return CurrentItems[#CurrentItems]
	end
	Box2DRenderItem.GetLastItem = GetLastItem
	Box2DRenderItem.getLastItem = GetLastItem

	local function GetItems()
		-- Return's a table of all the items in the inventory

		return Table.Copy(CurrentItems)
	end
	Box2DRenderItem.GetItems = GetItems
	Box2DRenderItem.getItems = GetItems

	local function GetRawItems()
		-- Returns' the raw currentItems table, which should not be modified.

		return CurrentItems;
	end
	Box2DRenderItem.GetRawItems = GetRawItems
	Box2DRenderItem.getRawItems = GetRawItems

	local function GetItemIndex(Item)
		-- Get's an item's index in the list
		-- @return The item's index, if it's in the list. Otherwise, return's nil.

		for Index, ItemInList in pairs(CurrentItems) do
			if ItemInList == Item then
				return Index;
			end
		end

		return nil;
	end
	Box2DRenderItem.GetItemIndex = GetItemIndex;
	Box2DRenderItem.getItemIndex = GetItemIndex;

	local function MouseDownUpdate()
		-- Updates the renderer when the mouse goes down.
		if not MouseDown then
			MouseDown = true;
			--NameLabel.FontSize = "Size18";
			NameLabel:TweenPosition(UDim2.new(0, Configuration.NameLabelPixelOffsetMouseDown, 0, 0), "Out", "Sine", Configuration.MouseDownChangeTime, true)
			CountLabel:TweenPosition(GetItemCountPosition(), "Out", "Sine", Configuration.MouseDownChangeTime, true);
		end
	end

	local function MouseUpUpdate()
		-- Updates the render when the mouse is up.
		if MouseDown then
			MouseDown = false;
			--NameLabel.FontSize = "Size14";
			NameLabel:TweenPosition(UDim2.new(0, Configuration.NameLabelPixelOffset, 0, 0), "In", "Sine", Configuration.MouseDownChangeTime, true)
			CountLabel:TweenPosition(GetItemCountPosition(), "In", "Sine", Configuration.MouseDownChangeTime, true);
			if not MouseOver then -- Otherwise MouseOver will handle it.
				MouseOverCover.Visible = false;
			end
		end
	end


	local function Destroy()
		--- Destroy's the object for GC. 
		-- @post the object is gone, and can be GCed. Item, if it was selected, will be disselected. 
		-- @pre There are no items in the list
		-- @return If it is successfully destroyed.

		for _, Item in pairs(CurrentItems) do
			RemoveItemFromSlot(Item, true)
		end

		if GetCurrentItemCount() > 0 then
			print("[BoxInventoryRender] - Should not destroy, There are still "..GetCurrentItemCount().." item(s) in this renderthingy")
		end

		if BoxInventoryRender.Box2DInterface.BoxSelection.IsSelected(Item) then
			BoxInventoryRender.Box2DInterface.BoxSelection:Unselect(Item);
		end
		
		CurrentItems  = nil
		Configuration = nil
		MouseDown     = nil
		ItemColor     = nil

		--- WHY. WHY. WHY.
		Update               = nil
		ShowSelection        = nil
		HideSelection        = nil
		AnimateShow          = nil
		AnimateHide          = nil
		GetItemCountPosition = nil
		Select               = nil
		Unselect             = nil
		GetCurrentItemCount  = nil
		UpdateItemCount      = nil
		AddItemToSlot        = nil
		GetItemIndex         = nil
		RemoveItemFromSlot   = nil
		GetLastItem          = nil
		GetItems             = nil
		GetRawItems          = nil
		GetItemIndex         = nil
		MouseDownUpdate      = nil
		MouseUpUpdate        = nil

		BoxInventoryRender.EventStorage["ItemEvent" .. Item.ClassName] = nil
		Gui:Destroy()

		for Index, Value in pairs(Box2DRenderItem) do
			Box2DRenderItem[Index] = nil;
		end
		return true;
	end
	Box2DRenderItem.Destroy = Destroy;
	Box2DRenderItem.destroy = Destroy;

	-- Connect events --
	BoxInventoryRender.EventStorage["ItemEvent" .. Item.ClassName].MouseEnter = Gui.MouseEnter:connect(function()
		MouseOver = true
		Update()
	end)

	BoxInventoryRender.EventStorage["ItemEvent" .. Item.ClassName].MouseLeave = Gui.MouseLeave:connect(function()
		MouseOver = false
		Update()
	end)

	BoxInventoryRender.EventStorage["ItemEvent" .. Item.ClassName].MouseButton1Down = Gui.MouseButton1Down:connect(function()
		MouseDownUpdate()
	end)

	BoxInventoryRender.EventStorage["ItemEvent" .. Item.ClassName].MouseButton1Up = Gui.MouseButton1Up:connect(function()
		MouseUpUpdate()
	end)

	BoxInventoryRender.EventStorage["ItemEvent" .. Item.ClassName].Button1Up = BoxInventoryRender.Box2DInterface.Mouse.Button1Up:connect(function()
		MouseUpUpdate()
	end)

	AddItemToSlot(Item)
	UpdateItemCount()
	--Update()
end)

--[[
Change Log

February 15th, 2014
- Added Show and Hide methods

February 13th, 2014
- Fixed problem with RenderFrame leaving some frames visible.

--]]
local MakeInventoryOptionModule = Class(function(InventoryOptionModule, Name, OptionSystem, ShowCallback)
	--- An option module that can be assigned to specific types of inventories.  Groups options, such as "Jetson" and "Destroy" I guess
	-- Can be collapsed.
	-- @param Name The name of the option group is given. Will be rendered in the options.
	-- @param ShowCallback Functon ShowCallback(InventoryOptionModule) returns true or false depending on if the inventoryoptionmodele should
	--                     be rendered. It will also fail to render if the number of options available to be shown is zero. However, some modules
	--                     such as a shop probably shouldn't be shown at all. 
	--                     
	--                     This should be used to prevent extra calcutions from occuring, such as when no item is selected for a valid inventory.

	-- Configuration --
	local Configuration = OptionSystem.Configuration
	InventoryOptionModule.Configuration = Configuration;
	InventoryOptionModule.Data = {} -- Store specific data.

	--print("OptionSystem: "..tostring(OptionSystem).."; OptionSystem.Box2DInterface = "..tostring(OptionSystem.Box2DInterface))

	--assert(OptionSystem.Box2DInterface ~= nil, "OptionSystem.Box2DInterface == "..tostring(OptionSystem.Box2DInterface))
	-- Render --
	local MainFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "InventoryOptionModule"..Name;
		Parent                 = OptionSystem.Box2DInterface.ScreenGUI;
		Size                   = UDim2.new(0, Configuration.ColumnWidth, 0, Configuration.IndividualHeaderHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
		ClipsDescendants       = true;
	}
	InventoryOptionModule.Gui = MainFrame

	local RenderFrame = Make 'Frame' { -- Contains the options.
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = true;
		Name                   = "RenderFrame";
		Parent                 = MainFrame; -- Can be sketch. But tweening requires a parent. Also, title doesn't work without it.
		Position               = UDim2.new(0, 0, 0, Configuration.IndividualHeaderHeight);
		Size                   = UDim2.new(1, 0, 1, -Configuration.IndividualHeaderHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	}

	-- Render the title frame
	local TitleFrame = MakeTitleFrame(
		MainFrame, 
		Name, 
		nil,
		Configuration.ZIndex, 
		Configuration.IndividualHeaderHeight
	);
	TitleFrame.Parent = MainFrame;
	TitleFrame.Position = UDim2.new(0, 0, 0, 0);

	-- Render the collapse button
	local CollapseButton = MakeCollapseButton(false, {
		ZIndex = Configuration.ZIndex;
	})
	CollapseButton.Gui.Parent = TitleFrame
	CollapseButton.Gui.Position = UDim2.new(1, -(CollapseButton.Gui.Size.X.Offset + 5), 0.5, -CollapseButton.Gui.Size.Y.Offset/2)

	-- Public Variables --
	InventoryOptionModule.OptionSystem         = OptionSystem
	InventoryOptionModule.CollapseStateChanged = CreateSignalInternal()
	InventoryOptionModule.YRenderHeight        = Configuration.IndividualHeaderHeight;
	
	InventoryOptionModule.XRenderWidth         = Configuration.ColumnWidth;
	InventoryOptionModule.Name                 = Name;
	InventoryOptionModule.ShowCallback         = ShowCallback -- If used incorrectly to modify selection, can create infinite loop.

	-- Private variables --
	local IsCollapsed = false;
	local OptionList = {} -- Contains all the "options." that exist. Each can be customized, but contain a "general framework" 
	-- of expected variables, listed below

	-- Private Methods --
	--[[
		Option 
			Gui -- Will be positioned
			RenderHeightY -- How high of a size it will take up. 
			Shown = true/false -- Is it visible? 
			Update -- Updates rendering and settings
			OptionSystem -- The option system it's linked too
	--]]




	-- Public Methods --
	local function AddOption(Option)
		-- Adds an option to the list...
		-- @param Option The option to add.

		table.insert(OptionList, Option);
		Option.Gui.Parent = RenderFrame;
		Option.OptionSystem = OptionSystem -- Make sure it can access the OptionSystem
	end
	InventoryOptionModule.AddOption = AddOption;
	InventoryOptionModule.addOption = AddOption

	local function Show(DoNotAnimate)
		-- Shows the inventory with a nice animation. Uses Configuration.ShowAnimateTime.
		-- This method can be overriden by Hide() or Show().
		-- @param DoNotAnimate boolean, it true, will not animate.

		local NewSize = UDim2.new(0, Configuration.ColumnWidth, 0, InventoryOptionModule.RenderHeightY)
		if DoNotAnimate then
			MainFrame.Size = NewSize
		else
			MainFrame:TweenSize(NewSize, "Out", "Sine", Configuration.ShowAnimateTime, true)
		end
	end
	InventoryOptionModule.Show = Show
	InventoryOptionModule.show = Show

	local function Hide(DoNotAnimate)
		-- Hides the inventory with a nice animation. Uses Configuration.ShowAnimateTime.
		-- This method can be overriden by Hide() or Show().
		-- @param DoNotAnimate boolean, it true, will not animate.

		local NewSize = UDim2.new(0, Configuration.ColumnWidth, 0, 0)
		if DoNotAnimate then
			MainFrame.Size = NewSize
		else
			MainFrame:TweenSize(NewSize, "Out", "Sine", Configuration.ShowAnimateTime, true)
		end
	end
	InventoryOptionModule.Hide = Hide
	InventoryOptionModule.hide = Hide

	local function Collapse()
		-- Collapses the option module

		IsCollapsed = true;
		InventoryOptionModule.CollapseStateChanged:fire()
	end
	InventoryOptionModule.Collapse = Collapse
	InventoryOptionModule.collapse = Collapse

	local function Uncollapse()
		-- ncollapes the option module

		IsCollapsed = false;
		InventoryOptionModule.CollapseStateChanged:fire()
	end
	InventoryOptionModule.Uncollapse = Uncollapse
	InventoryOptionModule.uncollapse = Uncollapse

	local function CheckIfShowable()
		--- Return's if the option module can be shown or not. Also updates the modules.
		-- ShowCallback does not have to exist.		
		
		if InventoryOptionModule.ShowCallback then
			if InventoryOptionModule:ShowCallback(OptionSystem.Box2DInterface) then
				local ShowCount = InventoryOptionModule.Update()
				return ShowCount >= 1
			else
				return false;
			end
		else
			local ShowCount = InventoryOptionModule.Update()
			return ShowCount >= 1
		end
	end
	InventoryOptionModule.CheckIfShowable = CheckIfShowable;
	InventoryOptionModule.checkIfShowable = CheckIfShowable;

	local function Update()
		--- Updates rendering, may redraw.
		-- @return Visible Number of visible?

		CollapseButton.SetState(IsCollapsed)

		local YHeight = 0;
		local ShowCount = 0;

		for _, Option in pairs(OptionList) do
			Option:Update(OptionSystem.Box2DInterface) -- Better not yield.

			-- Make sure the option is shown
			if Option.Shown then
				if not IsCollapsed then -- We reposition it should be shown.
					Option.Gui.Position = UDim2.new(0, 0, 0, YHeight)
					YHeight = YHeight + Option.RenderHeightY
				end
				ShowCount = ShowCount + 1;
			end
		end

		InventoryOptionModule.RenderHeightY = YHeight + Configuration.IndividualHeaderHeight;
		-- MainFrame.Size = UDim2.new(0, Configuration.ColumnWidth, 0, InventoryOptionModule.RenderHeightY)
		MainFrame:TweenSize(UDim2.new(0, Configuration.ColumnWidth, 0, InventoryOptionModule.RenderHeightY), "Out", "Sine", Configuration.ShowAnimateTime, true)
	
		RenderFrame:TweenSize(UDim2.new(1, 0, 0, YHeight), "Out", "Sine", Configuration.TweenAnimationTime, true)
		return ShowCount;
	end
	InventoryOptionModule.Update = Update
	InventoryOptionModule.update = Update

	-- Connect events --
	CollapseButton.Gui.MouseButton1Click:connect(function()
		if IsCollapsed then
			Uncollapse()
		else
			Collapse()
		end
	end)
end)
lib.MakeInventoryOptionModule = MakeInventoryOptionModule
lib.makeInventoryOptionModule = MakeInventoryOptionModule


--[[
Change log

February 15th, 2014
- Added DoNotAnimate option to Update()

February 13th, 2014
- Set it so modules now render at the top, not centered.

--]]
local MakeOptionSystem = Class(function(OptionSystem, Box2DInterface)
	--- This handles options and stuff. This is basically how the player will interact with the inventory, so it
	--  deserves much documentation.

	-- The inventory is first RENDERED. Items in it based upon class name can be SELECTED. 
	-- Then the system automatically finds every single action that can be executed on this.
	-- This is what the OptionSystem is. 

	-- Options are catagorized into modules/catagories. Each module can be occluded or included per inventory based upon
	-- The "ShowCallback" argument. Each option can also be occluded or included based upon thier own "Shown" property (This property
	-- is to be changed during Update() to prevent over-calculation.).

	-- Each option has a Gui that will be positioned. This GUI will handle rendering, et cetera, and all that. This is suppose to be
	-- flexible, et cetera. 

	-- Gui should be 40 high. 

	--[[
		Option 
			Gui -- Will be positioned
			RenderHeightY -- How high of a size it will take up. 
			Shown = true/false -- Is it visible? 
			Update -- Updates rendering and settings
			OptionSystem -- The option system it's linked too
	--]]

	local OptionsSystemModules = {}

	-- Global Variables --
	OptionSystem.Box2DInterface = Box2DInterface
	assert(OptionSystem.Box2DInterface ~= nil, "OptionSystem.Box2DInterface == "..tostring(OptionSystem.Box2DInterface))

	OptionSystem.Configuration = {
		IndividualHeaderHeight = 40;
		ColumnWidth            = 250;
		ZIndex                 = 2;
		PaddingY               = 20; -- Padding on the top and the bottom for the topions.
		SpacingSize            = 30; -- Padding between each option;
		ColumnPaddingX         = 50; -- Padding between each column
		TweenAnimationTime     = 0.2; -- Universal animation time;
		ShowAnimateTime        = 0.2; -- Time to show a module.
	}
	local Configuration = OptionSystem.Configuration
	local BoxSelection = Box2DInterface.BoxSelection

	local RenderFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "OptionSystemRenderFrame";
		Parent                 = OptionSystem.Box2DInterface.ScreenGUI;
		Size                   = UDim2.new(0, Configuration.ColumnWidth, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	}
	OptionSystem.Gui = RenderFrame


	-- Functions --
	local function AddModule(Module, DoNotAnimate)
		--- Adds a module into the system

		OptionsSystemModules[Module.Name] = Module
		Module.Gui.Parent = RenderFrame

		-- Connect events.
		Module.CollapseStateChanged:connect(function() -- Could be ugly GC problem with event connection.
			OptionSystem.Update()
		end)

		OptionSystem.Update(DoNotAnimate) -- Update whenever a new module is added.
	end
	OptionSystem.AddModule = AddModule
	OptionSystem.addModule = AddModule

	local function Update(DoNotAnimate)
		-- Updates the whol thing, relaigns columns 
		-- @param DoNotAnimate Boolean, dictates whether or not it animates

		local MaxYHeight = Box2DInterface.ScreenGui.AbsoluteSize.Y
		MaxYHeight = MaxYHeight - (Configuration.PaddingY*2)

		local ColumnCount = 1;
		local CurrentRenderHeightY = Configuration.PaddingY*2;
		local CurrentOptionModulesInColumn = {}

		-- Utility functions.
		local function CheckifBranchToNewColumnAndExecute()
			-- Checks if a new column needs to be made, recenters the modulers
			-- If you have a really big modular, this kind of messes up, as far as I can think. I think it'll float over an extra one
			-- So... let's just not let that happen. Boo iphone users. 

			if ((CurrentRenderHeightY) > MaxYHeight) then
				-- Recenter and switch to a new column

				local HeightY = OptionSystem.Configuration.PaddingY -- GetCenterY(Box2DInterface.ScreenGui, CurrentRenderHeightY)
				for Index, OptionModule in pairs(CurrentOptionModulesInColumn) do
					if Index < #CurrentOptionModulesInColumn then -- We don't want the last one, it wraps around
						OptionModule.Gui.Position = UDim2.new(0, (ColumnCount - 1) * (Configuration.ColumnWidth + Configuration.ColumnPaddingX), 0, HeightY)
						HeightY = HeightY + OptionModule.RenderHeightY + Configuration.SpacingSize
					end
				end

				CurrentRenderHeightY = Configuration.PaddingY*2; -- Reset..
				ColumnCount = ColumnCount + 1;
				CurrentOptionModulesInColumn = {CurrentOptionModulesInColumn[#CurrentOptionModulesInColumn]} -- Include the last one
			end
		end

		for _, OptionModule in pairs(OptionsSystemModules) do
			-- Update the module...
			OptionModule.Update(Box2DInterface.BoxSelection)

			if OptionModule.CheckIfShowable() then
				OptionModule.Show(DoNotAnimate)

				-- Track modules in the column.
				table.insert(CurrentOptionModulesInColumn, OptionModule)
				CurrentRenderHeightY = CurrentRenderHeightY + OptionModule.RenderHeightY + Configuration.SpacingSize
				CheckifBranchToNewColumnAndExecute()
			else
				OptionModule.Hide(DoNotAnimate)
			end
		end

		if #CurrentOptionModulesInColumn >= 1 then
			-- Finish rendering up the rest of them, but only if there's something left to render. #CurrentOptionModulesInColumn is generally > 0, except when 0 options exist.

			local HeightY = OptionSystem.Configuration.PaddingY -- GetCenterY(Box2DInterface.ScreenGui, CurrentRenderHeightY)

			for Index, OptionModule in pairs(CurrentOptionModulesInColumn) do
				local NewPosition = UDim2.new(0, (ColumnCount - 1) * (Configuration.ColumnWidth + Configuration.ColumnPaddingX), 0, HeightY)
				--OptionModule.Gui.Position = NewPosition
				if DoNotAnimate then
					OptionModule.Gui:TweenPosition(NewPosition, "Out", "Sine", Configuration.TweenAnimationTime, true);
				else
					OptionModule.Gui.Position = NewPosition
				end

				HeightY = HeightY + OptionModule.RenderHeightY + Configuration.SpacingSize
			end
		end
		RenderFrame.Size = UDim2.new(0, ColumnCount * (Configuration.ColumnWidth + Configuration.ColumnPaddingX) - Configuration.ColumnPaddingX, 1, 0);
	end
	OptionSystem.Update = Update
	OptionSystem.update = Update

	-- Connect events. Better is use groups so a ton of items selected at once doesn't lag.
	BoxSelection.SelectionChanged:connect(function() -- Another ugly GC problem?
		Update()
	end)
end)

--[[
Change Log

February 15th, 2014
- Added GCing stuff to the system.

--]]
local MakeBoxInventoryRenderCard = Class(function(BoxInventoryRenderCard, BoxInventoryRender, ZIndex)
	--- A card displaying information about the box inventory
	-- Renders a title, 

	-- Todo: Add actual statistics.

	local BoxInventory = BoxInventoryRender.Inventory
	local Box2DInterface = BoxInventoryRender.Box2DInterface
	local Configuration = Box2DInterface.Configuration

	ZIndex = ZIndex or Configuration.ZIndex

	local MainFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = false;
		Name                   = "BoxInventoryRenderCard";
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 0, 0);
		Visible                = true;
		ZIndex                 = ZIndex;
	}
	BoxInventoryRenderCard.Gui = MainFrame

	local TitleFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(242/255, 242/255, 242/255);
		BackgroundTransparency = 0;
		BorderSizePixel        = 0;
		ClipsDescendants       = true; -- Make sure if the Title goes past the size, we can still work....
		Name                   = "TitleFrame";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 0, Configuration.IndividualHeaderHeight);
		Visible                = true;
		ZIndex                 = ZIndex + 1;
	}

	local TitleLabel = Make 'TextLabel' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "Arial";
		FontSize               = "Size18";
		Name                   = "Title";
		Parent                 = TitleFrame;
		Position               = UDim2.new(0, 10, 0, 0);
		Size                   = UDim2.new(1, -10, 1, 0);
		Text                   = BoxInventory.Name .." Inventory";
		TextColor3             = Color3.new(0, 0, 0);
		TextStrokeTransparency = 1;
		TextXAlignment         = "Left";
		TextYAlignment         = "Center";
		Visible                = true;
		ZIndex                 = ZIndex + 1;
	}

	local Stats = {}

	local function Update()
		--- To be called everytime the BoxInventoryRender updates / changes

		for Index, Stat in pairs(Stats) do
			Stat.Update()
		end
	end
	BoxInventoryRenderCard.Update = Update
	BoxInventoryRenderCard.update = Update

	local function Destroy()
		-- Should GC the card

		Update         = nil

		ZIndex         = nil
		BoxInventory   = nil
		Box2DInterface = nil
		Configuration  = nil

		for Index, Stat in pairs(Stats) do
			Stats[Index] = nil
		end

		MainFrame:Destroy()
		TitleFrame:Destroy()
		TitleLabel:Destroy()

		--- Clean out whole class declaration
		for Index, Value in pairs(BoxInventoryRenderCard) do
			BoxInventoryRenderCard[Index] = nil
		end
	end
	BoxInventoryRenderCard.Destroy = Destroy
	BoxInventoryRenderCard.destroy = Destroy


	-- DEFINE STATS
	local InventoryVolumeInfo = {} do
		-- This tracks the inventory size, and how much is left.

		local SizeIcon                = RenderSizeIcon(30, 3, Color3.new(255/255, 107/255, 107/255),  ZIndex, true)
		local SizeIconOver            = RenderSizeIcon(30, 3, Color3.new(217/255, 217/255, 217/255),  ZIndex+1, true)
		SizeIconOver.Parent           = SizeIcon
		SizeIconOver.ClipsDescendants = true
		
		local MainFrame         = MakeIconedFrame(SizeIcon, "* ERROR *", ZIndex)
		InventoryVolumeInfo.Gui = MainFrame
		local TextLabel         = MainFrame.TextLabel

		local function Update()
			-- Updates the information. called by BoxInventoryRenderCard.Update
			-- Will also be called automatically on render.

			local InventoryVolume = BoxInventory.GetInventoryVolume()
			local TakenVolume = BoxInventory.GetTakenVolume()
			local PercentUsed = TakenVolume / InventoryVolume

			SizeIconOver.Size = UDim2.new(1, 0, 1-PercentUsed, 0) -- Resize so color only shows through is the % used.
			TextLabel.Text    = Round(PercentUsed * 100, 0.1) .. "% used [" .. TakenVolume .. " blocks out of " .. InventoryVolume .. "]"
		end
		InventoryVolumeInfo.Update = Update
	end
	Stats[#Stats+1] = InventoryVolumeInfo
	InventoryVolumeInfo = nil

	local InventoryItemCount = {} do
		local CountIcon = Make 'TextLabel' {
			Archivable             = false;
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Font                   = "Arial";
			Name                   = "CountIcon";
			Size                   = UDim2.new(0, 30, 0, 30);
			Text                   = "0";
			TextColor3             = Color3.new(78/255, 205/255, 196/255);
			TextScaled             = true;
			TextXAlignment         = "Center";
			TextYAlignment         = "Center";
			ZIndex                 = ZIndex;
		}

		local MainFrame = MakeIconedFrame(CountIcon, "* ERROR *", ZIndex)
		InventoryItemCount.Gui = MainFrame
		local TextLabel = MainFrame.TextLabel

		local function Update()
			local Count = BoxInventoryRender.GetTotalItemCount()

			CountIcon.Text = tostring(Count)
			TextLabel.Text = "There are " .. Count .. " items stored"
		end
		InventoryItemCount.Update = Update
	end
	Stats[#Stats+1] = InventoryItemCount
	InventoryItemCount = nil

	-- PROCESS STATS
	local YHeight = Configuration.IndividualHeaderHeight + 10
	for Index, Stat in pairs(Stats) do
		Stat.Gui.Parent   = MainFrame
		Stat.Gui.Position = UDim2.new(0, 0, 0, YHeight)
		YHeight           = YHeight + Stat.Gui.Size.Y.Offset + 10;
		-- Stat.Update() -- Already called.
	end
	MainFrame.Size = UDim2.new(1, 0, 0, YHeight)
	YHeight = nil

	Update()
end)

--[[
Change Log
February 16th, 2014
- Added GC stuff on events
- Added Destroy method fix
- Fixed GC stuffz.

February 15th, 2014
- Added GetTotalItemCount
- Fixed resizing the frame
- Added info card on mouse over

--]]
local MakeBoxInventoryRender = Class(function(BoxInventoryRender, Box2DInterface, BoxInventory)
	-- Render's itself in a frame, can be collapsed, et cetera. Represents a SINGLE inventory. 

	-- Represents a single inventory, which can be manipulated, et cetera. 
	-- @param Box2DRenderItem The Box2DRenderItem that the BoxInventoryRender will be represented in
	-- @param BoxInventory The inventory of which content's are being displayed

	BoxInventoryRender.Interfaces = {} -- For other things to store information in
	local Configuration = Box2DInterface.Configuration;

	-- Render GUIs, this holds everything in it.
	local RenderFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = false;
		Name                   = "InventoryRenderFrame";
		Parent                 = Box2DInterface.ContentContainer; -- Can be sketch. But tweening requires a parent. Also, title doesn't work without it.
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 0, Configuration.IndividualHeaderHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	}
	BoxInventoryRender.Gui       = RenderFrame
	BoxInventoryRender.Inventory = BoxInventory

	-- Holds all the specific items in it.
	local ContentFrame = Make 'Frame' {
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = true;
		Name                   = "ContentFrame";
		Parent                 = RenderFrame;
		Position               = UDim2.new(0, 0, 0, Configuration.IndividualHeaderHeight);
		Size                   = UDim2.new(0, Configuration.ColumnWidth, 0, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	}
	BoxInventoryRender.ContentFrame = ContentFrame

	-- Contains 2 states...
	local CollapseButton = MakeCollapseButton(false, {
		ZIndex = Configuration.ZIndex;
	}) -- Set the state to false, that is the whole thing is shown.
	-- Event's for button setup later. 
	
	local TitleFrame = MakeTitleFrame(
		RenderFrame, 
		BoxInventory.Name, 
		nil,--"// subtitle",
		Configuration.ZIndex, 
		Configuration.IndividualHeaderHeight
	);
	TitleFrame.BackgroundTransparency = 0.7;
	TitleFrame.Parent                 = RenderFrame;
	TitleFrame.Position               = UDim2.new(0, 0, 0, 0); 	

	CollapseButton.Gui.Parent = TitleFrame
	CollapseButton.Gui.Position = UDim2.new(1, -(CollapseButton.Gui.Size.X.Offset + 5), 0.5, -CollapseButton.Gui.Size.Y.Offset/2)
	--CollapseButton.Gui.BackgroundColor3 = Color3.new(0, 0, 0)

	-- Public variables
	BoxInventoryRender.Box2DInterface       = Box2DInterface; -- Read only
	BoxInventoryRender.BoxInventory         = BoxInventory	-- Read only
	BoxInventoryRender.CollapseStateChanged = CreateSignalInternal()

	local EventStorage                      = EventGroup.MakeEventGroup() -- Store Box2DRenderItem
	BoxInventoryRender.EventStorage         = EventStorage

	-- Private variables
	local RenderHeightY      = Configuration.IndividualHeaderHeight; -- Read only
	local IsCollapsed        = false
	local HasContentToRender = false
	
	local TotalItemCount     = 0 -- Items held in the inventory. Track it!
	
	local VisibleItems       = {} -- This holds all the Box2DRender items
	local ActiveCards        = {} -- Hold all active "info cards" that are attached to the inventory. A weak table, so it *should?* GC?
	setmetatable(ActiveCards, {__mode  ="v"})

	-- Private Methods
	local function FindRenderInterface(ClassName)
		--- Used internally to find out if an item exists in the inventory already
		-- @param ClassName the Classname of the itemclass to find. 
		-- @return The item found, and if an item was found (bool)

		-- This is used because instead of making a new button for each item, it instead groups items by number.

		for Index, RenderInterface in pairs(VisibleItems) do
			if RenderInterface.ClassName == ClassName then
				return RenderInterface, Index, true
			end
		end
		return nil, nil, false
	end

	local function UpdateCards()
		--- Updates all InfoCards. Internally called on item add or remove.

		for _, ActiveCard in pairs(ActiveCards) do
			ActiveCard.Update()
		end
	end

	local function SortInventory(Mode)
		-- Sort's visible items. Default is "alphabetical", which is currenlty the only option.
		-- Mode is the mode to sort by...

		table.sort(VisibleItems, function(ItemA, ItemB)
			return ItemA.ClassName < ItemB.ClassName -- Sort by alphabet!
		end)
	end

	local function AddItems(Items)
		-- Used internally to add new items to the render. 
		-- @param Items A table full of ItemSystem items.

		-- Loop through each item and add it.
		for _, Item in pairs(Items) do
			if Item.Interfaces.BoxInventoryRender then
				error("[BoxInventoryRender] - This item already has a BoxInventoryRender interface, is already added into system.!")
			end

			local Interface = FindRenderInterface(Item.ClassName)
			if not Interface then
				Interface = {}
					
				Interface.Render = MakeBox2DRenderItem(Item, BoxInventoryRender, nil)
				Interface.ClassName = Item.ClassName

				EventStorage[Item.ClassName].MouseButton1Click = Interface.Render.Gui.MouseButton1Click:connect(function()
					-- Select! Yay!

					-- print("[BoxInventoryRender] - Item button clicked")
					if Interface.Render.Selected then
						Box2DInterface.BoxSelection:Unselect(Interface.Render);
					else
						Box2DInterface.BoxSelection:Select(Interface.Render);
					end
				end)

				Interface.Render.Gui.Parent = ContentFrame;
				Interface.Render.AnimateShow()

				-- Add interfaces, insert it into the list, and sort the inventory!
				Item.Interfaces["BoxInventoryRender"] = Interface
				table.insert(VisibleItems, Interface)
				SortInventory()
			else
				Item.Interfaces["BoxInventoryRender"] = Interface
				Interface.Render.AddItemToSlot(Item)
			end

			TotalItemCount = TotalItemCount + 1
		end
		BoxInventoryRender.Update()
		UpdateCards()
	end

	local function RemoveItems(Items)
		-- Used internally to remove  items from the render.  Gets called whenever BoxInventory.ItemRemoved fires...

		-- @param Items A table full of ItemSystem items, with the BoxInventoryRender

		for _, Item in pairs(Items) do
			local RenderInterface, Index, DidFindInterface = FindRenderInterface(Item.ClassName) -- Get the render represetngint the item

			if DidFindInterface then
				RenderInterface.Render.RemoveItemFromSlot(Item) -- Update RenderInterface
				Item.Interfaces.BoxInventoryRender = nil; -- Cleanup RenderInterface

				if RenderInterface.Render.GetCurrentItemCount() <= 0 then
					Box2DInterface.BoxSelection:Unselect(RenderInterface.Render)
					RenderInterface.Render:Destroy() -- Destroys the render interface, which is removed from the item
					-- by setting Item.Interfaces.BoxInventoryRender to nil below.
					EventStorage[Item.ClassName] = nil
					table.remove(VisibleItems, Index) -- Clean out from VisibleItems...
				end

				TotalItemCount = TotalItemCount - 1
			else
				error("[BoxInventoryRender] - Item '" .. Item.ClassName .."' does not exist in the InventoryRender system, cannot remove.")
			end
		end

		Box2DInterface.Update()
		UpdateCards()
	end

	-- Public Methods --

	local function GetInfoCard(ZIndex)
		--- Return's a BoxInventory info card!

		local NewCard = MakeBoxInventoryRenderCard(BoxInventoryRender, ZIndex)
		ActiveCards[#ActiveCards+1] = NewCard -- MORE HORRID GC THINGS

		return NewCard
	end
	BoxInventoryRender.GetInfoCard = GetInfoCard
	BoxInventoryRender.getInfoCard = GetInfoCard

	local function UpdateProperties()
		--- Updates BoxInventoryRender.RenderHeightY to the correct value. Also updates
		--  HasContentToRender and IsCollapsed
		-- Called by Update()

		local YHeight = 0;

		if not IsCollapsed then
			for _, Interface in pairs(VisibleItems) do
				Interface.Render.Update() -- Maybe disable if it's too inefficient?
				Interface.Render.Gui.Position = UDim2.new(0, 0, 0, YHeight) -- Position relative to the bottom. Animaiton
				YHeight = YHeight + Interface.Render.YRenderHeight;
			end
		end
		RenderHeightY = YHeight + Box2DInterface.Configuration.IndividualHeaderHeight
		RenderFrame.Size = UDim2.new(1, 0, 0, RenderHeightY)
	end
	BoxInventoryRender.UpdateProperties = UpdateProperties
	BoxInventoryRender.updateProperties = UpdateProperties

	local function ResizeContentFrame(DoNotAnimate)
		-- Resizes the content frame based upon collapsed or not

		UpdateProperties()
		local Size = UDim2.new(1, 0, 0, RenderHeightY - Box2DInterface.Configuration.IndividualHeaderHeight)
		if DoNotAnimate then
			ContentFrame.Size = Size;
		else
			ContentFrame:TweenSize(Size, "Out", "Sine", Configuration.CollapseAnimateTime, true);
		end
	end

	local function Collapse()
		-- Collapses the inventory, and fires the event (Which then updates it)

		for _, Item in pairs(VisibleItems) do-- Unselect visible items... Make sure that we don't have any hidden selections.
			Box2DInterface.BoxSelection:Unselect(VisibleItems.Render)
		end 

		IsCollapsed = true;
		BoxInventoryRender.CollapseStateChanged:fire(IsCollapsed); -- Should fire Update()
		--ResizeContentFrame() -- Handled by event being fired
	end
	BoxInventoryRender.Collapse = Collapse
	BoxInventoryRender.collapse = Collapse

	local function Uncollapse()
		-- Decollapses the inventory 

		IsCollapsed = false;
		BoxInventoryRender.CollapseStateChanged:fire(IsCollapsed); -- Should fire Update()
		--ResizeContentFrame() -- Handled by event being fired
	end
	BoxInventoryRender.Uncollapse = Uncollapse
	BoxInventoryRender.uncollapse = Uncollapse

	local function Update()
		-- Redraw's and updates the render.

		--UpdateProperties() -- Handled by ResizeContentFrame()
		ResizeContentFrame()
		CollapseButton.SetState(IsCollapsed)
	end
	BoxInventoryRender.Update = Update
	BoxInventoryRender.update = Update

	-- GET methods 

	local function GetHasContentToRender()
		--- Return's if this class has any content to render.

		return HasContentToRender
	end
	BoxInventoryRender.GetHasContentToRender = GetHasContentToRender
	BoxInventoryRender.getHasContentToRender = GetHasContentToRender

	local function GetIsCollapsed()
		-- Return if this inventory is collapsed or not. 
		return IsCollapsed
	end
	BoxInventoryRender.GetIsCollapsed = GetIsCollapsed
	BoxInventoryRender.getIsCollapsed = GetIsCollapsed

	local function GetRenderHeightY()
		-- Return the RenderHeightY value of the inventory. 

		return RenderHeightY
	end
	BoxInventoryRender.GetRenderHeightY = GetRenderHeightY
	BoxInventoryRender.getRenderHeightY = GetRenderHeightY

	local function GetTotalItemCount()
		--- Return's how many items the inventory is holding.

		return TotalItemCount
	end
	BoxInventoryRender.GetTotalItemCount = GetTotalItemCount
	BoxInventoryRender.getTotalItemCount = GetTotalItemCount

	local InfoCard = {} do 
		-- This setups up an info card that will work on MouseEnter
		-- So inefficient. Oh well.

		InfoCardClass                            = GetInfoCard(Configuration.ZIndex + 3)
		InfoCardClass.Gui.Parent                 = Box2DInterface.Gui;
		InfoCardClass.Gui.BackgroundTransparency = 0

		InfoCard.InfoCardClass = InfoCardClass

		local CornerWedgeThingy = Make 'ImageLabel' {
			Archivable             = false;
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Image                  = "http://www.roblox.com/asset/?id=146421657";
			Name                   = "Tip";
			Parent                 = InfoCardClass.Gui;
			Position               = UDim2.new(0, -20, 0, 0);
			Size                   = UDim2.new(0, 20, 0, 20);
			ZIndex                 = Configuration.ZIndex + 3;
		}

		local function UpdatePosition()
			InfoCardClass.Gui.Position = UDim2.new(0, Configuration.Width + 10, 0, TitleFrame.AbsolutePosition.Y + 10);
		end
		InfoCard.UpdatePosition = UpdatePosition
		InfoCard.updatePosition = UpdatePosition

		local function Show()
			-- Shows the InfoCard

			UpdatePosition()
			InfoCardClass.Gui.Visible = true
		end
		InfoCard.Show = Show
		InfoCard.show = Show

		local function Hide()
			-- Hides the InfoCard

			InfoCardClass.Gui.Visible = false
		end
		InfoCard.Hide = Hide
		InfoCard.hide = Hide

		UpdatePosition()
		Hide()

		local function Destroy()
			CornerWedgeThingy:Destroy()
			InfoCard = nil
		end
		InfoCard.Destroy = Destroy
	end

	local function Destroy()
		-- Destroy's the box inventory render. 
		-- If Cards are still enabled in a system, they will be destroyed, but not GCed. Problem!

		for Index, Box2DRenderItem in pairs(VisibleItems) do
			VisibleItems[Index] = nil
			Box2DInterface.BoxSelection:Unselect(Box2DRenderItem.Render)
			Box2DRenderItem.Render.Destroy()
		end

		for Index, ActiveCard in pairs(ActiveCards) do
			ActiveCard.Destroy()
			ActiveCards[Index] = nil
		end

		BoxInventoryRender.Interfaces = nil

		ActiveCards = nil
		VisibleItems = nil

		InfoCard:Destroy()
		CollapseButton:Destroy()
		CollapseButton = nil

		-- Clean up events
		EventStorage("Clear")
		BoxInventoryRender.CollapseStateChanged:destroy()
		BoxInventoryRender.CollapseStateChanged = nil

		-- Clean up internal stuff.
		EventStorage       = nil
		Configuration      = nil
		
		RenderHeightY      = nil
		IsCollapsed        = nil
		HasContentToRender = nil
		VisibleItems       = nil
		ActiveCards        = nil
		
		BoxInventory       = nil
		Box2DInterface     = nil

		-- Clean up GUIs
		RenderFrame:Destroy()
		RenderFrame = nil

		-- Clean up class declaration
		for Index, Item in pairs(BoxInventoryRender) do
			BoxInventoryRender[Index] = nil;
		end
	end
	BoxInventoryRender.Destroy = Destroy
	BoxInventoryRender.destroy = Destroy

	-- Add initial items on creation. --

	AddItems(BoxInventory.GetListOfItems())

	-- Connect events.
	EventStorage.ItemAdded = BoxInventory.ItemAdded:connect(function(Item)
		AddItems({Item}) -- Also will call UpdateCards()
	end)

	EventStorage.ItemRemoved = BoxInventory.ItemRemoved:connect(function(Item)
		RemoveItems({Item}) -- Also will call UpdateCards()
	end)

	EventStorage.StorageSlotAdded = BoxInventory.StorageSlotAdded:connect(function()
		UpdateCards()
	end)

	EventStorage.CollapseButtonMouseEnter = CollapseButton.Gui.MouseEnter:connect(function()
		qGUI.TweenTransparency(CollapseButton.Gui, {BackgroundTransparency = 0.7;}, 0.1, true)
	end)

	EventStorage.CollapseButtonMouseLeave = CollapseButton.Gui.MouseLeave:connect(function()
		qGUI.TweenTransparency(CollapseButton.Gui, {BackgroundTransparency = 1;}, 0.1, true)
	end)

	EventStorage.CollapseButtonMouseButton1Click = CollapseButton.Gui.MouseButton1Click:connect(function()
		if not CollapseButton.GetState() then
			Collapse()
		else
			Uncollapse()
		end
	end)

	--- Setup TitleFrame stuff.
	EventStorage.TitleFrameMouseEnter = TitleFrame.MouseEnter:connect(function()
		InfoCard.Show()
	end)

	EventStorage.TitleFrameMouseLeave = TitleFrame.MouseLeave:connect(function()
		InfoCard.Hide()
	end)

	EventStorage.ScrollFinished = Box2DInterface.Scroller.ScrollFinished:connect(function()
		InfoCard.UpdatePosition()
	end)

	EventStorage.Box2DInterfaceClosed = Box2DInterface.Closed:connect(function()
		InfoCard.Hide() -- We need to hide on close because ROBLOX's MouseLeave event doesn't fire right.
	end)

	InfoCard.Hide()
	ResizeContentFrame(true)
end)

local MakeVerticalCardHolder = Class(function(VerticalCardHolder, Width, ZIndex)
	--- Holds "Cards", short pockets of information. 
	-- @param ZIndex The ZINdex to set
	-- @param Width The width of the card holder.

	-- This one holds cards vertically. 
	-- Has a member .Gui, must be parented
	-- Scrollbars come later, I suppose.

	local MainFrame = Make 'Frame' {
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 0;
		BorderSizePixel 	   = 0;
		Name                   = "VerticalCardHolder";
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(0, Width, 0, 0);
		Visible                = true;
		ZIndex                 = ZIndex;
		Archivable             = false;
	}
	VerticalCardHolder.Gui = MainFrame

	local Pointer = Make 'ImageLabel' {
		Image                  = "http://www.roblox.com/asset/?id=146409029";
		Parent                 = MainFrame;
		Size                   = UDim2.new(0, 30, 0, 20);
		BackgroundTransparency = 1;
		Position               = UDim2.new(0, 0, 0, -20);
		BorderSizePixel        = 0;
		Archivable             = false;
		ZIndex                 = ZIndex;
	}

	local Cards = {}

	local function RepositionCards()
		-- Repositions all the cards and resizes the container.

		local YHeight = 0
		for _, Card in pairs(Cards) do
			Card.Gui.Position = UDim2.new(0, 0, 0, YHeight)
			YHeight = YHeight + Card.Gui.Size.Y.Offset
		end

		MainFrame.Size = UDim2.new(0, Width, 0, YHeight)
	end

	local function SetPosition(NewPosition)
		--- Set's the position of the VerticalCardHolder. Should be used because it will make the pointer point at it
		--  correctly.
		-- @param NewPosition The new position to set
		-- @post The postion is set.

		MainFrame.Position = NewPosition + UDim2.new(0, 0, 0, 20)
	end
	VerticalCardHolder.SetPosition = SetPosition
	VerticalCardHolder.setPosition = SetPosition

	local function AddCard(NewCard)
		-- Adds a new card to the system and updates it. 
		-- @param NewCard A table that should have a single thing, ".Gui")

		NewCard.Gui.Parent = MainFrame
		Cards[#Cards+1] = NewCard
		RepositionCards()
	end
	VerticalCardHolder.AddCard = AddCard
	VerticalCardHolder.addCard = AddCard

	local function RemoveCard(CardToRemove)
		--- Removes a card from the render.
		RepositionCards()

		local DidRemove = false
		for Index, Card in pairs(Cards) do
			if Card == CardToRemove then
				DidRemove = true
				Card.Gui.Parent = nil
				table.remove(Cards, Index)
				break;
			end
		end

		if not DidRemove then
			error("[VerticalCardHolder] - Removal failed. Could not find card sent.")
		end
	end
	VerticalCardHolder.RemoveCard = RemoveCard
	VerticalCardHolder.removeCard = RemoveCard

	local function Show()
		MainFrame.Visible = true
	end
	VerticalCardHolder.Show = Show
	VerticalCardHolder.show = Show

	local function Hide()
		MainFrame.Visible = false
	end
	VerticalCardHolder.Hide = Hide
	VerticalCardHolder.hide = Hide

	-- We want to get the size right.
	RepositionCards()
	Hide()
end)


--[[
Box2DInterface is the TOP LEVEL interface.

Change Log
February 15th, 2014
- Made Scroller available to the world (Will be used by the Infobox in InventoryRender's)

February 13th, 2014
- Added "Gui" field pointing to MainFrame
- Made configuration use OverriddenConfiguration

--]]
local MakeBox2DInterface = Class(function(Box2DInterface, Mouse, ScreenGui, Configuration)
	--- Models and controls the Box2D rendering overall. Supports multiple inventories. 

	-- Configuration and settings
	Configuration = OverriddenConfiguration.new(Configuration, {
		Subtitle               = "// trade enterprise";
		Title                  = "Stock";
		Width                  = 250;
		
		-- Rendering options
		ScrollbarWidth         = 7;
		ZIndex                 = 1; -- Index may go 2+ this, so range [1-8]
		IndividualHeaderHeight = 40; -- Per each inventory. 
		FooterHeight           = 80;
		CollapseAnimateTime    = 0.1; -- When collapsing inventory rendering. 
		OptionPanePaddingX     = 20; -- Padding between the inventory and the options
		CloseIconRegular       = "http://www.roblox.com/asset/?id=139944727";
		CloseIconOver          = "http://www.roblox.com/asset/?id=139944744";
		CloseButtonSize        = 30; -- Since it's a square, the length of one side.
		-- Also CloseButtonSize will be used for OpenButtonSize.
		
		OpenButtonOffset       = UDim2.new(0, 5, 0, 5); -- Offset from top left portion of screen
		OpenIconRegular        = "http://www.roblox.com/asset/?id=146357554";
		OpenIconOver           = "http://www.roblox.com/asset/?id=146357731";
		
		ToggleAnimationTime    = 0.3; -- When toggling the inventory open or closed
		
		CardWidth              = 300;
		CardZIndex             = 2;

		ShowOpenInventoryLabelTime = 0.5;
	})

	Box2DInterface.Mouse = Mouse;

	-- Rendering --
	local MainFrame = Make 'Frame' {
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 0.9;
		BorderSizePixel 	   = 0;
		Name                   = "Box2DRender";
		Parent                 = ScreenGui;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(0, Configuration.Width, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
		Archivable             = false;
	}
	Box2DInterface.Gui = MainFrame

	local ContentContainer = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = true;
		Name                   = "ContentContainer";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, Configuration.IndividualHeaderHeight);
		Size                   = UDim2.new(1, 0, 1, -Configuration.IndividualHeaderHeight - Configuration.FooterHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	}
	Box2DInterface.ContentContainer = ContentContainer

	local ContentFrame = Make 'Frame' { -- Stuff goes in here. 
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "ContentFrame";
		Parent                 = ContentContainer;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, -Configuration.ScrollbarWidth, 1.5, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
		Archivable             = false;
	}

	local ScrollBarFrame = Make 'Frame' { -- Stuff goes in here. 
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "ScrollBarFrame";
		Parent                 = MainFrame;
		Position               = UDim2.new(1, -Configuration.ScrollbarWidth, 0, 0);
		Size                   = UDim2.new(0, Configuration.ScrollbarWidth, 1, -Configuration.FooterHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
		Archivable             = false;
	}

	local HeaderFrame = MakeTitleFrame(MainFrame, Configuration.Title, Configuration.Subtitle, MainFrame.ZIndex, Configuration.IndividualHeaderHeight)
	HeaderFrame.Size  = UDim2.new(1, -Configuration.ScrollbarWidth, 0, Configuration.IndividualHeaderHeight)

	-- Display thing that shows up on mouse enter over the "Show inventory" thing.
	local FastInfoViewerDisplay      = MakeVerticalCardHolder(Configuration.CardWidth, Configuration.CardZIndex)
	FastInfoViewerDisplay.Gui.Parent = ScreenGui

	local CloseButtonOffset = (Configuration.IndividualHeaderHeight - Configuration.CloseButtonSize)/2
	local CloseButton = Make 'ImageButton' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Image                  = Configuration.CloseIconRegular;
		Name                   = "CloseButton";
		Parent                 = HeaderFrame;
		Position               = UDim2.new(1, -(CloseButtonOffset + Configuration.CloseButtonSize), 0, CloseButtonOffset);
		Size                   = UDim2.new(0, Configuration.CloseButtonSize, 0, Configuration.CloseButtonSize);
	}

	-- SETUP OPEN BUTTON --
	local OpenButton = Make 'ImageButton' { -- Goes in the top left corner, but fills the whole corner.
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Image                  = "";
		Name                   = "OpenInventoryButton";
		Parent                 = ScreenGui;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = Configuration.OpenButtonOffset + UDim2.new(0, Configuration.CloseButtonSize, 0, Configuration.CloseButtonSize);
	}

	local OpenButtonImage = Make 'ImageLabel' { -- Image that goes in the top left corner. 
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Image                  = Configuration.OpenIconRegular;
		Name                   = "ImageLabel";
		Parent                 = OpenButton;
		Position               = Configuration.OpenButtonOffset;
		Size                   = UDim2.new(0, Configuration.CloseButtonSize, 0, Configuration.CloseButtonSize);
	}

	local OpenButtonTextLabel = Make 'TextLabel' { -- Shows up next to the OpenButtonImage
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Position               = UDim2.new(1, 10, 0.5, -Configuration.CloseButtonSize/2);
		Size                   = UDim2.new(0, 200, 0, Configuration.CloseButtonSize);
		Text                   = "Open Inventory [E]";
		TextColor3             = Color3.new(1, 1, 1);
		TextXAlignment         = "Left";
		TextYAlignment         = "Center";
		Font                   = "Arial";
		FontSize               = "Size14";
		TextStrokeTransparency = 1;
		TextTransparency = 1;
		Parent                 = OpenButton;
		-- Visible = true;
	}

	FastInfoViewerDisplay.SetPosition(Configuration.OpenButtonOffset + UDim2.new(0, Configuration.CloseButtonSize/2, 0, Configuration.CloseButtonSize/2));

	-- Properties
	Box2DInterface.Configuration = Configuration -- Should not be modified, technically read only.
	Box2DInterface.BoxSelection  = MakeBoxSelection(Box2DInterface)
	Box2DInterface.ScreenGui     = ScreenGui

	Box2DInterface.Opened = CreateSignal() -- Fires when ShowInterface() is called
	Box2DInterface.Closed = CreateSignal() -- Fires when HideInterface is called
	
	local OptionSystem          = MakeOptionSystem(Box2DInterface)
	OptionSystem.Gui.Parent     = MainFrame
	OptionSystem.Gui.Position   = UDim2.new(0, Configuration.Width + Configuration.OptionPanePaddingX, 0, 0);
	Box2DInterface.OptionSystem = OptionSystem

	--assert(OptionSystem.Box2DInterface ~= nil, "OptionSystem.Box2DInterface == "..tostring(OptionSystem.Box2DInterface))

	-- Signals
	Box2DInterface.InventoryAdded   = CreateSignalInternal();
	Box2DInterface.InventoryRemoved = CreateSignalInternal();
	
	local Scroller                  = ScrollBar.MakeScroller(ContentContainer, ContentFrame, ScreenGui, 'Y')
	local ScrollBar                 = Scroller:AddScrollBar(ScrollBarFrame)
	Box2DInterface.Scroller = Scroller

	-- Local Properties (Private)
	local RenderedInventories = {}
	local OpenInventories  = 0 -- Counter for OpenButtonOver
	local UpdateEvents     = EventGroup.MakeEventGroup()
	local InterfaceVisible = false; 

	local function OpenButtonOver()
		-- Whenever the mouse enters the open button

		OpenButtonImage.Image       = Configuration.OpenIconOver;
		qGUI.TweenTransparency(OpenButtonTextLabel, {TextTransparency = 0}, Configuration.ShowOpenInventoryLabelTime, true)
		-- OpenButtonTextLabel.Visible = true
		if OpenInventories >= 1 then
			FastInfoViewerDisplay.Show()
		end
	end

	local function OpenButtonLeave()
		-- Whenever the mouse leaves the open button
		OpenButtonImage.Image       = Configuration.OpenIconRegular;
		qGUI.TweenTransparency(OpenButtonTextLabel, {TextTransparency = 1}, Configuration.ShowOpenInventoryLabelTime, true)
		-- OpenButtonTextLabel.Visible = false
		FastInfoViewerDisplay.Hide()
	end


	-- Global Methods
	local function ShowInterface(DoNotAnimate)
		-- Show's the interface
		-- @param DoNotAnimate If true, will not animate

		OpenButtonLeave() -- Fix on leave not firing on tweening stuff

		Box2DInterface.Opened:fire()
		InterfaceVisible = true;

		local Position           = UDim2.new(0, 0, 0, 0)
		local OpenButtonPosition = UDim2.new(0, -OpenButton.Size.X.Offset, 0, Configuration.OpenButtonOffset.Y.Offset)

		if DoNotAnimate then
			MainFrame.Position  = Position
			OpenButton.Position = OpenButtonPosition
		else
			OpenButton:TweenPosition(OpenButtonPosition, "Out", "Quart", Configuration.ToggleAnimationTime, true)
			MainFrame:TweenPosition(Position, "Out", "Quart", Configuration.ToggleAnimationTime, true)
		end
	end
	Box2DInterface.ShowInterface = ShowInterface;
	Box2DInterface.showInterface = ShowInterface

	local function HideInterface(DoNotAnimate)

		-- Fix image on close (if mouse is over)
		CloseButton.Image = Configuration.CloseIconRegular;

		Box2DInterface.Closed:fire()
		InterfaceVisible = false;
		local Position           = UDim2.new(0, -Configuration.Width, 0, 0)
		local OpenButtonPosition = UDim2.new(0, 0, 0, 0);
		
		Box2DInterface.BoxSelection:UnselectAll()

		if DoNotAnimate then
			MainFrame.Position  = Position
			OpenButton.Position = OpenButtonPosition
		else
			MainFrame:TweenPosition(Position, "In", "Quart", Configuration.ToggleAnimationTime, true)
			OpenButton:TweenPosition(OpenButtonPosition, "In", "Quart", Configuration.ToggleAnimationTime, true)
		end
	end
	Box2DInterface.HideInterface = HideInterface;
	Box2DInterface.hideInterface = HideInterface;

	local function ToggleInterface(DoNotAnimate)
		if InterfaceVisible then
			HideInterface(DoNotAnimate)
		else
			ShowInterface(DoNotAnimate)
		end
	end
	Box2DInterface.ToggleInterface = ToggleInterface;
	Box2DInterface.toggleInterface = ToggleInterface;

	local function Update(IsCollapseUpdate)
		--- Updates rendering and the children.
		-- @param [IsCollapseUpdate] Boolean, if this update is after a collapse.

		local YHeight = 0;
		for _, Interface in pairs(RenderedInventories) do
			local BoxInventoryRender = Interface;
			BoxInventoryRender.Update();
			local Position = UDim2.new(0, 0, 0, YHeight);

			if IsCollapseUpdate then
				BoxInventoryRender.Gui.Position = Position
			else
				BoxInventoryRender.Gui:TweenPosition(Position, "Out", "Sine", Configuration.CollapseAnimateTime, true);
			end

			YHeight = YHeight + BoxInventoryRender.GetRenderHeightY();
		end
		local Size = UDim2.new(1, -Configuration.ScrollbarWidth, 0, math.max(ContentContainer.AbsoluteSize.Y, YHeight))
		ContentFrame.Size = Size;
	end
	Box2DInterface.Update = Update
	Box2DInterface.update = Update

	local function AddClientInventory(ClientInventory)
		--- Displays ClientInventoryInterface to the world.  The actual inventory will be on the server.
		-- @param ClientInventory The ClientInventory to use. 

		local InventoryUID = ClientInventory.UID or error("No UID!") -- Only reason why this wouldn't work via the immediate BoxINventory if it was stored client side.

		local Interface = ClientInventory.Interfaces.BoxInventoryRender
		if not Interface then
			Interface            = MakeBoxInventoryRender(Box2DInterface, ClientInventory);
			Interface.Gui.Parent = ContentFrame;
		end
		RenderedInventories[InventoryUID] = Interface

		local NewInterface = {} do
				-- Do the card information stuff
			local NewCard = Interface.GetInfoCard(Configuration.CardZIndex)
			FastInfoViewerDisplay.AddCard(NewCard)

			NewInterface.Card = NewCard
		end
		Interface.Interfaces.Box2DInterface = NewInterface

		UpdateEvents[ClientInventory].OnCollapse = Interface.CollapseStateChanged:connect(function()
			Update(true) -- Update the rendering to compensate. 
		end)

		OpenInventories = OpenInventories + 1
		Update()

		return Interface
	end
	Box2DInterface.AddClientInventory = AddClientInventory
	Box2DInterface.addClientInventory = AddClientInventory

	local function RemoveClientInventory(ClientInventory)
		--- Removes the inventory from the interface.
		-- @param Inventory The inventory being removed.

		print("[Box2DInterface] - Removing client inventory")

		local InventoryUID = ClientInventory.UID or error("No UID found!") -- Meh!
		assert(RenderedInventories[InventoryUID] ~= nil, "cannot remove a nil inventory")

		local RemovingInventory = RenderedInventories[InventoryUID]
		FastInfoViewerDisplay.RemoveCard(RemovingInventory.Interfaces.Box2DInterface.Card)
		UpdateEvents[RemovingInventory] = nil

		RemovingInventory.Destroy()
		RenderedInventories[InventoryUID] = nil

		OpenInventories = OpenInventories - 1
		Update()
	end
	Box2DInterface.RemoveClientInventory = RemoveClientInventory
	Box2DInterface.removeClientInventory = RemoveClientInventory

	-- Hook events and add updates -- 
	ContentContainer.Changed:connect(function(Property)
		if Property == "AbsoluteSize" then
			Update()
		end
	end)

	--- Button toggles
	CloseButton.MouseEnter:connect(function()
		CloseButton.Image = Configuration.CloseIconOver;
	end)
	CloseButton.MouseLeave:connect(function()
		CloseButton.Image = Configuration.CloseIconRegular;
	end)
	CloseButton.MouseButton1Click:connect(function()
		ToggleInterface()
	end)

	-- Open button toggles
	OpenButton.MouseEnter:connect(function()
		OpenButtonOver()
	end)
	OpenButton.MouseLeave:connect(function()
		OpenButtonLeave()
	end)
	OpenButton.MouseButton1Click:connect(function()
		ToggleInterface()
	end)

	HideInterface(true)
end)
lib.MakeBox2DInterface = MakeBox2DInterface;
lib.makeBox2DInterface = MakeBox2DInterface

return lib