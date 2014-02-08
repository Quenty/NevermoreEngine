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
local InventorySystems  = LoadCustomLibrary('InventorySystems')
local qString           = LoadCustomLibrary('qString')
local qGUI              = LoadCustomLibrary('qGUI')
local ScrollBar         = LoadCustomLibrary('ScrollBar')
local EventBin          = LoadCustomLibrary('EventBin')

-- This library handles rendering the BoxInventory in 2D for interaction. It also handles, or course, player interaction
-- with it. It's basically split between datastructures and rendering structures. 

qSystems:Import(getfenv(0));

local lib = {}

local MakeBoxSelection = Class 'BoxSelection' (function(BoxSelection, Box2DInterface)
	-- Datastructure to handle the selection of items...

	local Selected = {}
	BoxSelection.SelectionAdded = CreateSignalInternal() -- When a single new item is selected. Will fire many times relative to
	                                           -- SelectionGroupAdded's firing rate.
	BoxSelection.SelectionGroupAdded = CreateSignalInternal() -- When a group is added. Cut down on calcuations..
	BoxSelection.SelectionRemoved = CreateSignalInternal() -- Like above, but when an item is unselected. 
	BoxSelection.SelectionGroupRemoved = CreateSignalInternal() -- Like above, but when an item is unselected. 

	local function AddBoxSelectionInterface(Item)
		-- Add's selection interface.. 

		if not Item.Interfaces.BoxSelection then
			local NewInterface = {};
			NewInterface.Selected = false;
			NewInterface.SelectedChanged = CreateSignal(); -- When the .Selected value changed

			Item.Interfaces.BoxSelection = NewInterface
		end
	end
	BoxSelection.AddBoxSelectionInterface = AddBoxSelectionInterface;
	BoxSelection.addBoxSelectionInterface = AddBoxSelectionInterface

	local function Select(self, ...)
		-- Select's an object, if it can be selected.
		-- @pre Item has the Box2DRender interface.

		local ToSelect = {...}
		local SelectedList = {}
		for _, Item in pairs(ToSelect) do
			AddBoxSelectionInterface(Item)

			if not Item.Interfaces.BoxSelection.Selected then
				Item.Interfaces.BoxSelection.Selected = true;
				BoxSelection.SelectionAdded:fire(Item)
				Item.Interfaces.BoxSelection.SelectedChanged:fire(Item.Interfaces.BoxSelection.Selected)
				SelectedList[#SelectedList+1] = Item;

				Item.Interfaces.Box2DRender.Render.ShowSelection()

				print("[BoxSelection] - Selected Item")
			else
				print("[BoxSelection] - Item already selected")
			end
		end
		if #SelectedList >= 1 then
			BoxSelection.SelectionGroupAdded:fire(SelectedList)
		end
	end
	BoxSelection.Select = Select;
	BoxSelection.Select = Select;

	local function IsSelected(Item)
		if Item.Interfaces.BoxSelection then
			return Item.Interfaces.BoxSelection.Selected
		else
			return false;
		end
	end
	BoxSelection.IsSelected = IsSelected;
	BoxSelection.isSelected = IsSelected;

	local function Unselect(self, ...)
		-- Unselects items
		-- @pre all items in the list have the BoxSelection interface
		--      Item has the Box2DRender interface.

		local ToUnselect = {...}
		local UnselectedItems = {}
		for _, Item in pairs(ToUnselect) do
			if Item.Interfaces.BoxSelection.Selected then
				Item.Interfaces.BoxSelection.Selected = false;
				BoxSelection.SelectionRemoved:fire(Item)
				Item.Interfaces.BoxSelection.SelectedChanged:fire(Item.Interfaces.BoxSelection.Selected)
				UnselectedItems[#UnselectedItems+1] = Item;

				Item.Interfaces.Box2DRender.Render.HideSelection()
			end
		end
		if #UnselectedItems >= 1 then
			BoxSelection.SelectionGroupRemoved:fire(UnselectedItems)
		end
	end
	BoxSelection.Unselect = Unselect
	BoxSelection.unselect = Unselect

	local function UnselectAll(self)
		-- Unselects all the items...

		Unselect(Selected)
	end
	BoxSelection.UnselectAll = UnselectAll;
	BoxSelection.unselectAll = UnselectAll

	local function RemoveBoxSelectionInterface(Item)
		-- Safely removes the interface...

		if Item.Interfaces.BoxSelection then
			if NewInterface.Selected then
				Unselect(Item)
			end
			NewInterface.SelectedChanged:Destroy()
			Item.Interfaces.BoxSelection = nil
		end
	end
	BoxSelection.RemoveBoxSelectionInterface = RemoveBoxSelectionInterface
	BoxSelection.removeBoxSelectionInterface = RemoveBoxSelectionInterface
end)

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
	-- @param Subtitle the subtitle to display. Will auto offset from title.
	-- @param [ZIndex] the ZIndex of the title frame. 
	-- @param [Height] the height of the title frame to be. 
	-- @param [XOffset] the offset from the left (X Axis)
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

	return TitleFrame;
end

local MakePercentFilledImage = Class 'PercentFilledImage' (function(PercentFilledImage, ImageLabel, FullIcon, Axis, Inverse)
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

local MakeBox2DRenderItem = Class 'Box2DRenderItem' (function(Box2DRenderItem, Item, Box2DInterface, ZIndex)
	--  Will probably be removed/added a lot.. Only one should exist per an item. Used internally. 

	-- Definte variables
	local EventContainer = EventBin.MakeEventBin() -- Store all connections, events, et cetera.
	local MouseOver = false;
	Box2DRenderItem.EventContainer = EventContainer;

	local Configuration = {
		DefaultTransparency         = 1; -- Normal transparency...
		SelectedTransparency        = 0.4; -- Transparency when the item is selected. 
		MouseOverTransparencyChange = -0.1; -- Transparency when the mouse is over it. 
		TransparencyChangeTime      = 0.2; -- How long it takes to change the transparency. 
		ZIndex = ZIndex or 5;
	}
	Configuration.CurrentTransparency = Configuration.DefaultTransparency

	-- Start rendering. 
	local Gui = Make 'ImageButton' { -- MainGui
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "ItemButton"..Item.ClassName;
		Size                   = UDim2.new(1, 0, 0, 40);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 2;
		Archivable             = false;
	}
	Box2DRenderItem.Gui = Gui;

	local Container = Make 'Frame' { -- Container GUI
		Archivable             = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "Container";
		Parent                 = Gui;
		Size                   = UDim2.new(1, 0, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 1;
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
		Position               = UDim2.new(0, 10, 0, 0);
		Size                   = UDim2.new(1, -10, 0, 40);
		Text                   = Item.ClassName;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeTransparency = 1;
		TextTransparency       = 1;
		TextXAlignment         = "Left";
		TextYAlignment         = "Center";
		Visible                = true;
		ZIndex                 = Configuration.ZIndex + 1;
	}
	Box2DRenderItem.YRenderHeight = 40;

	local function Update()
		--- Updates rendering, YRenderHeight;

		Box2DRenderItem.YRenderHeight = 40;
		if MouseOver then
			qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.CurrentTransparency + Configuration.MouseOverTransparencyChange}, Configuration.TransparencyChangeTime, true)
		else
			qGUI.TweenTransparency(Container, {BackgroundTransparency = Configuration.CurrentTransparency}, Configuration.TransparencyChangeTime, true)
		end
	end
	Box2DRenderItem.Update = Update;
	Box2DRenderItem.Update = update

	local function ShowSelection()
		--- Renders as if it was selected. 
		print("[BoxSelection] - Showing selection")
		Configuration.CurrentTransparency = Configuration.SelectedTransparency
		Update()
	end
	Box2DRenderItem.ShowSelection = ShowSelection;
	Box2DRenderItem.showSelection = ShowSelection;

	local function HideSelection()
		--- Renders as if it was not selected. 

		Configuration.CurrentTransparency = Configuration.DefaultTransparency
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
		--Container.BackgroundTransparency = 1;
		--Update() -- Make fancy transparency animation... :D
		Container:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quart", TimePlay, true)
	end
	Box2DRenderItem.AnimateShow = AnimateShow
	Box2DRenderItem.animateShow = AnimateShow

	local function AnimateHide(TimePlay)
		TimePlay = TimePlay or 0.25
		Configuration.CurrentTransparency = 1;
		Container:TweenPosition(UDim2.new(-1, 0, 0, 0), "In", "Quart", TimePlay, true)
		qGUI.TweenTransparency(NameLabel, {TextTransparency = 1}, TimePlay, true)
	end
	Box2DRenderItem.Animate = AnimateHide;
	Box2DRenderItem.Animate = animateHide;

	local function Destroy()
		--- Destroy's the object for GC. 
		-- @post the object is gone, and can be GCed. Item, if it was selected, will be disselected. 
		if Box2DInterface.BoxSelection.IsSelected(Item) then
			Box2DInterface.BoxSelection:Unselect(Item);
		end
		EventContainer:destroy()
		Gui:Destroy()
		for Index, Value in pairs(Box2DRenderItem) do
			Box2DRenderItem[Index] = nil;
		end
	end
	Box2DRenderItem.Destroy = Destroy;
	Box2DRenderItem.destroy = Destroy;

	EventContainer:add(Gui.MouseEnter:connect(function()
		MouseOver = true
		Update()
	end))

	EventContainer:add(Gui.MouseLeave:connect(function()
		MouseOver = false
		Update()
	end))

	Update()
end)

local MakeBox2DRender = Class 'Box2DRender' (function(Box2DRender, Mouse, Box2DInterface, ScreenGui, Width, Title, Subtitle)
	--- Handles rendering of the interface...  Seperated into a seperate class to prevent conflicts with data model. 
	-- @param Mouse the active mouse
	-- @param Box2DInterface the interface to interact with
	-- @param ScreenGui the ScreenGui to render in
	-- @param Width the width in pixels of the inventory (Interger)
	-- @param Title the title to display
	-- @param Subtitle the subtitle to display 

	-- TODO: Add drag selection.... 

	local Configuration = {
		ScrollbarWidth = 7;
		ZIndex         = 6; -- Index may go 2+ this, so range [1-8]
		HeaderHeight   = 50;
		FooterHeight   = 80;
	}
	local MainFrame = Make 'Frame' {
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 0.7;
		BorderSizePixel        = 0;
		Name                   = "Box2DRender";
		Parent                 = ScreenGui;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(0, Width, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
		Archivable             = false;
	}
	Box2DRender.Gui = MainFrame;

	local ContentContainer = Make 'Frame' {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		ClipsDescendants       = true;
		Name                   = "ContentContainer";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, Configuration.HeaderHeight);
		Size                   = UDim2.new(1, 0, 1, -Configuration.HeaderHeight - Configuration.FooterHeight);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
	}

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
		Parent                 = ContentContainer;
		Position               = UDim2.new(1, -Configuration.ScrollbarWidth, 0, 0);
		Size                   = UDim2.new(0, Configuration.ScrollbarWidth, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
		Archivable             = false;
	}

	local HeaderFrame = MakeTitleFrame(MainFrame, Title, Subtitle, nil, Configuration.HeaderHeight)

	local Scroller = ScrollBar.MakeScroller(ContentContainer, ContentFrame, ScreenGui, 'Y')
	local ScrollBar = Scroller:AddScrollBar(ScrollBarFrame)

	local function ShowInventory(DoNotAnimate)
		local Position = UDim2.new(0, 0, 0, 0)
		if DoNotAnimate then
			MainFrame.Position = Position;
		else
			MainFrame:TweenPosition(Position, "Out", "Quart", 0.5, true)
		end
	end
	Box2DRender.ShowInventory = ShowInventory;
	Box2DRender.showInventory = ShowInventory

	local function HideInventory(DoNotAnimate)
		local Position = UDim2.new(0, -Width, 0, 0)
		if DoNotAnimate then
			MainFrame.Position = Position;
		else
			MainFrame:TweenPosition(Position, "In", "Quart", 0.5, true)
		end
	end
	Box2DRender.HideInventory = HideInventory;
	Box2DRender.hideInventory = HideInventory;

	local function AddBox2DRenderInterface(Item)
		--- Adds the Box2DRender interface to the ItemObject
		-- @param Item the InventoryObject added.
		-- @post Item has the interface
		-- @return Interface, and if it was added or not. 

		if not Item.Interfaces.Box2DRender then
			local NewInterface = {}
			NewInterface.Render = MakeBox2DRenderItem(Item, Box2DInterface, Configuration.ZIndex);
			NewInterface.Render.Gui.Parent = ContentFrame
			NewInterface.CurrentYRenderHeight = 0; -- height at which it is rendering... 
			NewInterface.NewItem = true;

			NewInterface.Render.EventContainer:add(NewInterface.Render.Gui.MouseButton1Click:connect(function()
				-- Select! Yay!
				print("[InventoryRender] - Item button clicked")
				if Box2DInterface.BoxSelection.IsSelected(Item) then
					Box2DInterface.BoxSelection:Unselect(Item);
				else
					Box2DInterface.BoxSelection:Select(Item);
				end
			end)) -- Hop onto the Render.EventBin versus making a new one. 

			Item.Interfaces.Box2DRender = NewInterface
			return Item.Interfaces.Box2DRender, true;
		end
		return Item.Interfaces.Box2DRender, false;
	end

	local function RemoveBox2DRenderInterface(Item)
		-- Safely removes the rendering interface. 

		if Item.Interfaces.Box2DRender then
			local Interface = Item.Interfaces.Box2DRender;
			Interface.Render:Destroy()
			Item.Interfaces.Box2DRender = nil;
		end
	end

	local function Update()
		-- Updates rendering, positioning of items, et cetera.
		-- @pre all active items have had their interface added. 

		local RenderHeightY = 0;
		local VisibleItems = Box2DInterface:GetVisibleItems()

		-- Reposition items. 
		for _, Item in ipairs(VisibleItems) do
			local NewInterface = Item.Interfaces.Box2DRender
			
			if NewInterface.CurrentYRenderHeight ~= RenderHeightY then
				NewInterface.CurrentYRenderHeight = RenderHeightY;
				if NewInterface.NewItem then
					Item.Interfaces.Box2DRender.Render.Gui.Position = UDim2.new(0, 0, 0, RenderHeightY)
				else
					Item.Interfaces.Box2DRender.Render.Gui:TweenPosition(UDim2.new(0, 0, 0, RenderHeightY), "InOut", "Sine", 0.1, true)
				end
			end
			RenderHeightY = RenderHeightY + NewInterface.Render.YRenderHeight -- Add to height.
		end
	end
	Box2DRender.Update = Update;
	Box2DRender.update = Update;

	local function AddObject(Item)
		-- Renders pretty object adding... Updates everything.
		assert(Item ~= nil, "[InventoryRender] - Item is nil, cannot add it to inventory.", 2)

		local Interface, DidAdd = AddBox2DRenderInterface(Item)
		Item.Interfaces.Box2DRender.Active = true;
		Interface.Render.AnimateShow(DidAdd)
		Update()
	end
	Box2DRender.AddObject = AddObject
	Box2DRender.addObject = AddObject

	local function RemoveObject(Item)
		-- Removes the object...
		if Item.Interfaces.Box2DRender then
			Item.Interfaces.Box2DRender.Active = false;
			Interface.Render.AnimateHide(0.5)
			wait(0.5)
			if not Item.Interfaces.Box2DRender.Active then
				RemoveBox2DRenderInterface(Item)
				print("[Box2DRender] - removed Box2D interface")
			else
				print("[Box2DRender] - did not remove Box2D interface")
			end
		end
	end
	Box2DRender.RemoveObject = RemoveObject
	Box2DRender.removeObject = RemoveObject;
end)


local Box2DInterfaceSortModeValues = { 
	-- These return the 'Value' of an Item so it can be sorted by a numerical value.  Each Item is an inventoryItem
	-- And will have the BoxInventory interface, 

	-- Returns from a scale of 100... 
	ClassNameFirstLetter = function(Item)
		-- Sort's by classname...
		local Name = Item.ClassName:lower()
		Name = Name:gsub("[%p%s]*(.-)[%p%s]", "%1") -- Filter out whitespace. 
		return string.byte(Name) - 96;
	end;
}

local MakeBox2DInterface = Class 'Box2DInterface' (function(Box2DInterface, Mouse, BoxInventory, ScreenGui, Width, Title, Subtitle)
	-- Renders and displays the inventory in 2D for interaction...

	local Configuration = {
		SortModes = {"ClassNameFirstLetter"};
		Width = Width;
	}

	local VisibleItems = {}
	local BoxSelection = MakeBoxSelection(Box2DInterface)
	Box2DInterface.BoxSelection = BoxSelection

	local Box2DRender = MakeBox2DRender(Mouse, Box2DInterface, ScreenGui, Width, Title, Subtitle)
	Box2DInterface.Box2DRender = Box2DRender

	local function GetValue(Modes)
		-- Return's the value of an InventoryItem... See Sort() for more information...
		-- Actually, return's a function. 
		assert(Modes ~= nil, "[Box2DInterface][GetValues] - Modes is nil")
		return function (Item)
			local Value = 0;
			for Index, Mode in pairs(Modes) do
				if Box2DInterfaceSortModeValues[Mode] then
					Value = Value + Box2DInterfaceSortModeValues[Mode](Item) / (100 ^ Index) -- We can scale, because it's from (100, 0)
				else
					error("[Box2DInterface] - Sort mode '".. Mode .."' does not exist in "..Box2DInterfaceSortModeValues)
				end
			end
			return Value
		end
	end

	local function Sort(self, Modes)
		--- Sort's the Box2D interface by different modes. 
		-- @param Modes List of strings of nodes to use, order taken into consideration, with the first ones being used first, and then
		--        the next one used as a tie breaker.
		-- @pre Modes exists in the table and each item has BoxInventory's inteface and Box2DInterface.
		-- @return nothing, as it works on the global VisibleItems list. 

		Modes = Modes or Configuration.SortModes;
		Table.ShellSort(VisibleItems, GetValue(Modes))
	end
	Box2DInterface.Sort = Sort;
	Box2DInterface.sort = Sort;

	local function SimpleAddItem(NewItem)
		--- Add's items into the active list... without sorting it.
		-- @pre newItem is added into BoxInventory

		table.insert(VisibleItems, NewItem);
	end

	local function AddItem(NewItem)
		-- Add's and updates....

		SimpleAddItem(NewItem)
		Box2DInterface:Sort()
		Box2DRender.AddObject(NewItem)
	end
	--Box2DInterface.AddItem = AddItem;
	--Box2DInterface.addItem = AddItem;

	local function RemoveItem(Item)
		--- Removes an item from being rendered.
		-- @pre has interface...
		local Index = 1;
		local Found = false;
		local NumberVisible = #VisibleItems
		while not Found and NumberVisible <= Index do
			if VisibleItems[Index] == Item then
				VisibleItems[Index] = nil;
				Found = true;
			end
		end
		for Index = Index + 1, NumberVisible do
			VisibleItems[Index - 1] = VisibleItems[Index];
		end
		Box2DRender.RemoveObject(NewItem)
		Box2DInterface:Sort()
	end

	local function GetVisibleItems()
		--- Return's visible items...
		-- @return the Visible items

		return VisibleItems;
	end
	Box2DInterface.GetVisibleItems = GetVisibleItems;
	Box2DInterface.getVisibleItems = GetVisibleItems


	-- Add in all the BoxInventory stuff...
	for _, Item in pairs(BoxInventory.GetListOfItems()) do
		SimpleAddItem(Item)
	end

	BoxInventory.ItemAdded:connect(function(Item)
		AddItem(Item)
	end)

	BoxInventory.ItemRemoved:connect(function(Item)
		RemoveItem(Item)
	end)
end)
lib.MakeBox2DInterface = MakeBox2DInterface;
lib.makeBox2DInterface = MakeBox2DInterface

NevermoreEngine.RegisterLibrary('InventoryRender', lib)