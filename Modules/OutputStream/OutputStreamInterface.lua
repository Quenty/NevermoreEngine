local ReplicatedStorage       = game:GetService("ReplicatedStorage")
local Players                 = game:GetService("Players")

local NevermoreEngine         = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary       = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local ScrollBar               = LoadCustomLibrary('ScrollBar')
local qGUI                    = LoadCustomLibrary('qGUI')
local CircularBuffer          = LoadCustomLibrary("CircularBuffer")
local PseudoChatSettings      = LoadCustomLibrary("PseudoChatSettings")
local OverriddenConfiguration = LoadCustomLibrary("OverriddenConfiguration")
local qTime = LoadCustomLibrary("qTime")

qSystems:Import(getfenv(0));

local lib = {}

--- OutputStreamInterface.lua
--- This library handles displaying render streams, from multiple channels.
-- @author Quenty
-- Last modified Janurary 26th, 2014

--[[--Change Log

-- January 26th, 2014
- Add Change log
- Update to use PseudoChatSettings

-- January 5th, 2014
- Wrote initial script

--]]
local DefaultConfiguration = {
	TitleWidth            = 30;
	ContentHeight         = 108; -- Height of the inteface. 
	ScrollbarWidth        = 7;
	ZIndex                = 8;
	FrameRenderBufferSize = PseudoChatSettings.BufferSize;
	
	TitleLabelOffset = 10;
	MenuZIndex       = 9; -- ZIndex of the menu overlay. We'll try to maintain a [8,9] ZIndex range. 
	MenuAnimateTime  = 0.1;
	MenuDefaultColor = Color3.new(0.5, 0.5, 0.5);
	MenuNameWhenOpen = "Switch Channels?";
}

local MakeOutputStreamMenu = Class(function(RenderStreamMenu, Parent, ScreenGui, Configuration)
	--- Creates a list of open "Channels" which can be dynamically changed and modified. 
	-- @param OutputStreamInterface The interface that this stream menu is associated with. 
	-- Used internally, Configuration is expected to be sent by the script, all contents intact.

	local MainFrame = Make("Frame", {
		Active                 = false;
		Archivable             = false;
		BackgroundColor3       = Color3.new(0.25, 0.25, 0.25);
		BackgroundTransparency = 0;
		BorderSizePixel        = 1;
		Name                   = "MenuFrame";
		Position               = UDim2.new(0.5, 0, 0, 0);
		Size                   = UDim2.new(0.5, 0, 1, 0);
		ZIndex                 = Configuration.MenuZIndex;
		Parent                 = Parent;
	})
	RenderStreamMenu.Gui = MainFrame

	local TitleButton = Make("ImageButton", {
		Archivable       = false;
		BackgroundColor3 = Color3.new(0.25, 0.25, 0.25);
		BorderSizePixel  = 0;
		Name             = "TitleButton";
		Parent           = MainFrame;
		Position         = UDim2.new(0, -Configuration.TitleWidth, 0, 0);
		Size             = UDim2.new(0, Configuration.TitleWidth + 1, 1, 0);
		ZIndex           = Configuration.MenuZIndex;
	})

	local TitleLabel = Make("TextLabel", {
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "TitleLabel";
		Parent                 = TitleButton;
		Rotation               = 90;
		Size                   = UDim2.new(0, TitleButton.AbsoluteSize.Y - Configuration.TitleLabelOffset, 0, Configuration.TitleWidth);
		Text                   = "Main Menu";
		TextColor3             = Color3.new(1, 1, 1);
		TextXAlignment         = "Right";
		ZIndex                 = Configuration.MenuZIndex;
	})
	TitleLabel.Position = UDim2.new(0.5, -(TitleButton.AbsoluteSize.Y) / 2, 0.5, -(Configuration.TitleWidth) / 2);

	local ContentContainer = Make("Frame", {
		Active                 = false;
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "ContentContainer";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, -Configuration.ScrollbarWidth, 1, 0);
		ZIndex                 = Configuration.MenuZIndex;
		Archivable             = false;
	})

	local ContentFrame = Make("ImageButton", {
		Image                  = ""; 
		Active                 = false;
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "ContentFrame";
		Parent                 = ContentContainer;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 1, 0);
		ZIndex                 = Configuration.MenuZIndex;
		Archivable             = false;
	})

	local ScrollBarFrame = Make("Frame", {
		BackgroundTransparency = 1;
		BorderSizePixel        = 0; 
		Name                   = "ScrollBarFrame";
		Parent                 = MainFrame;
		Position               = UDim2.new(1, -Configuration.ScrollbarWidth, 0, 0);
		Size                   = UDim2.new(0, Configuration.ScrollbarWidth, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.MenuZIndex;
		Archivable             = false;
	})

	local Scroller = ScrollBar.MakeScroller(ContentContainer, ContentFrame, ScreenGui, 'Y')
	local ScrollBar = Scroller:AddScrollBar(ScrollBarFrame)
	local IsShown = false
	local CurrentColor = Color3.new(0.25, 0.25, 0.25);
	local CurrentTitle = "[ Nothing Active ]"
	local ActiveChoices = {}

	RenderStreamMenu.MenuCollapseChanged = CreateSignal() -- Sends Signal(IsCollapsed)

	local function UpdateChoices()
		--- Repositions and updates the choices to new locations. 

		local YPosition = PseudoChatSettings.RenderStreamMenu.ChoiceYPadding;
		local ChoiceCount = 0
		for _, Choice in pairs(ActiveChoices) do
			ChoiceCount = ChoiceCount + 1
			Choice.Gui.Position = UDim2.new(0, PseudoChatSettings.RenderStreamMenu.ChoiceSizeXPadding/2,
				0, YPosition);
			YPosition = YPosition + PseudoChatSettings.RenderStreamMenu.ChoiceYPadding + Choice.YHeight
		end
		ContentFrame.Size = UDim2.new(1, 0, 0, math.max(YPosition, ContentContainer.AbsoluteSize.Y))

		if YPosition > ContentContainer.AbsoluteSize.Y then
			ScrollBarFrame.Visible = true
		else
			ScrollBarFrame.Visible = false
		end

		if ChoiceCount > 1 then
			MainFrame.Visible = true
		else
			MainFrame.Visible = false
		end
	end

	local function UpdateTitleBar(BackgroundColor3, Text, DoNotAnimate)
		--- Sets the TitleBar, helper function
		-- @param BackgroundColor3 The new backgroundColor3 to set
		-- @param Text The text to set
		-- @param DoNotAnimate Shoudl it animate or not?

		TitleLabel.Text = Text;

		if DoNotAnimate then
			TitleButton.BackgroundColor3 = BackgroundColor3
		else
			qGUI.TweenColor3(TitleButton, {BackgroundColor3 = BackgroundColor3}, Configuration.MenuAnimateTime, true)
		end
	end

	local MouseEvent
	local Mouse = Players.LocalPlayer:GetMouse()


	local function Uncollapse(DoNotAnimate)
		--- Show's the menu
		-- @param [DoNotAnimate] If indicated, will not animate the menu when showing or hiding. 

		-- If they don't click on the menu, hide it.
		if not MouseEvent then
			MouseEvent = Mouse.Button1Down:connect(function()
				if not qGUI.MouseOver(Mouse, MainFrame) and not qGUI.MouseOver(Mouse, MainFrame) then
					RenderStreamMenu.Collapse()
				end
			end)
		end

		IsShown = true
		local Position = UDim2.new(0.5, 0, 0, 0)
		UpdateTitleBar(Configuration.MenuDefaultColor, Configuration.MenuNameWhenOpen, DoNotAnimate)

		if DoNotAnimate then
			MainFrame.Position = Position
		else
			MainFrame:TweenPosition(Position, "Out", "Sine", Configuration.MenuAnimateTime, true)
		end

		RenderStreamMenu.MenuCollapseChanged:fire(false)
	end
	RenderStreamMenu.Uncollapse = Uncollapse
	RenderStreamMenu.uncollapse = Uncollapse

	local function Collapse(DoNotAnimate)
		--- Hide's the menu
		-- @param [DoNotAnimate] If indicated, will not animate the menu when showing or hiding. 

		if MouseEvent then
			MouseEvent:disconnect()
			MouseEvent = nil
		end

		IsShown = false
		local Position = UDim2.new(1, 0, 0, 0)
		UpdateTitleBar(CurrentColor, CurrentTitle, DoNotAnimate)

		if DoNotAnimate then
			MainFrame.Position = Position
		else
			MainFrame:TweenPosition(Position, "Out", "Sine", Configuration.MenuAnimateTime, true)
		end

		RenderStreamMenu.MenuCollapseChanged:fire(true)
	end
	RenderStreamMenu.Collapse = Collapse
	RenderStreamMenu.Collapse = Collapse

	local CurrentTransparency

	local function SetTransparency(NewTransparency, AnimateTime)
		--- Sets the transparency of the Interface to NewTransparency
		-- @param NewTransparency The transparency to set it to
		-- @param AnimateTime The time to animate. If not provided, will do it instantly. 

		assert(NewTransparency ~= nil, "NewTransparency is nil.")

		if CurrentTransparency ~= NewTransparency then -- Make sure we don't waste processing power. 
			CurrentTransparency = NewTransparency
			if AnimateTime then
				qGUI.TweenTransparency(MainFrame, {BackgroundTransparency = NewTransparency}, AnimateTime, true)
				qGUI.TweenTransparency(TitleButton, {BackgroundTransparency = NewTransparency}, AnimateTime, true)
				qGUI.TweenTransparency(TitleLabel, {TextTransparency = NewTransparency}, AnimateTime, true)
				for _, Item in pairs(ActiveChoices) do
					qGUI.TweenTransparency(Item.Gui, {BackgroundTransparency = NewTransparency}, AnimateTime, true)
					qGUI.TweenTransparency(Item.Gui.ChoiceLabel, {TextTransparency = NewTransparency}, AnimateTime, true)
				end
			else
				qGUI.StopTransparencyTween(MainFrame)
				qGUI.StopTransparencyTween(TitleButton)
				qGUI.StopTransparencyTween(TitleLabel)
				MainFrame.BackgroundTransparency = NewTransparency
				TitleButton.BackgroundTransparency = NewTransparency
				TitleLabel.TextTransparency = NewTransparency
				for _, Item in pairs(ActiveChoices) do
					qGUI.StopTransparencyTween(Item.Gui) 
					qGUI.StopTransparencyTween(Item.Gui.ChoiceLabel)

					Item.Gui.BackgroundTransparency = NewTransparency
					Item.Gui.ChoiceLabel.BackgroundTransparency = NewTransparency
				end
			end
		end
	end
	RenderStreamMenu.SetTransparency = SetTransparency
	RenderStreamMenu.setTransparency = SetTransparency

	local function SetColorAndTitle(Color, Title)
		-- Sets the color and title of the Menu that it will display while "Hidden." "
		-- @param Color A Color3, the color of the menu to set.
		-- @param Title The title to show.

		CurrentColor = Color
		CurrentTitle = Title
		if not IsShown then
			UpdateTitleBar(Color, Title)
		end
	end
	RenderStreamMenu.SetColorAndTitle = SetColorAndTitle
	RenderStreamMenu.setColorAndTitle = SetColorAndTitle


	local function Toggle(DoNotAnimate)
		--- Toggle's the menu's visibility. 
		-- @param [DoNotAnimate] If indicated, will not animate the menu when showing or hiding. 

		if IsShown then
			Collapse(DoNotAnimate)
		else
			Uncollapse(DoNotAnimate)
		end
	end
	RenderStreamMenu.Toggle = Toggle
	RenderStreamMenu.toggle = Toggle

	local function MakeChoice(Text, BackgroundColor3)
		--- Creates a new "Choice" GUI, for further manipulation.
		-- @param [BackgroundColor3] The color3 value of the background
		-- @param Text The text to display on the button.
		-- @return The new choice

		BackgroundColor3 = BackgroundColor3 or Color3.new(0, 0, 0)

		local NewChoice = {}

		NewChoice.BackgroundColor3 = BackgroundColor3
		NewChoice.Text = Text
		
		NewChoice.Gui = Make("TextButton", {
			Archivable             = false;
			BackgroundColor3       = BackgroundColor3;
			BackgroundTransparency = 0.3;
			BorderSizePixel        = 0;
			FontSize               = PseudoChatSettings.ChatFontSize;
			Name                   = "ChoiceButton";
			Parent                 = ContentFrame;
			Size                   = UDim2.new(1, -PseudoChatSettings.RenderStreamMenu.ChoiceSizeXPadding, 0, PseudoChatSettings.RenderStreamMenu.ChoiceSizeY);
			Text                   = "";
			Visible                = true;
			ZIndex                 = Configuration.MenuZIndex;
			Make("TextLabel", {
				BackgroundTransparency = 1;
				BorderSizePixel        = 0;
				Name                   = "ChoiceLabel";
				Position               = UDim2.new(0, 10, 0, 0);
				Size                   = UDim2.new(1, -10, 1, 0);
				Text                   = Text;
				TextColor3             = Color3.new(1, 1, 1);
				TextXAlignment         = "Left";
				ZIndex                 = Configuration.MenuZIndex
			});
		});
		NewChoice.YHeight = PseudoChatSettings.RenderStreamMenu.ChoiceSizeY

		ActiveChoices[#ActiveChoices + 1] = NewChoice

		function NewChoice:Destroy()
			-- For the GC of the choice.

			local Index = GetIndexByValue(ActiveChoices, NewChoice)

			NewChoice.Gui:Destroy()
			NewChoice.Destroy = nil
			NewChoice         = nil

			table.remove(ActiveChoices, Index)
			UpdateChoices()
		end

		UpdateChoices()
		return NewChoice
	end
	RenderStreamMenu.MakeChoice = MakeChoice
	RenderStreamMenu.makeChoice = MakeChoice

	local function GetIsShown()
		return IsShown
	end
	RenderStreamMenu.GetIsShown = GetIsShown
	RenderStreamMenu.getIsShown = GetIsShown

	-- Setup events
	TitleButton.MouseButton1Click:connect(function()
		Toggle()
	end)

	Collapse(true)
	UpdateChoices()
end)

local MakeNotifier = Class(function(Notifier, ContentContainer, IsTop)
	-- Used by the OutputStreamRender, creates a notification bar.
	-- @param ContentContainer The parent of the NotificationBar
	-- @param IsTop Boolean, if true, then it goes at the top, otherwise it goes to the top.

	local Configuration = {
		Height = 25;
		ZIndex = DefaultConfiguration.ZIndex + 1;
	}

	local NotificationBar = Make("ImageButton", {
		Visible                = true;
		BackgroundTransparency = 0;
		Parent                 = ContentContainer;
		Name                   = "Notification";
		BorderSizePixel        = 0;
		BackgroundColor3       = Color3.new(51/255, 102/255, 204/255);
		Size                   = UDim2.new(1, 0, 0, Configuration.Height);
		Position               = UDim2.new(0, 0, 1, 0);
		Archivable             = false;
		ZIndex                 = Configuration.ZIndex;
	})
	Notifier.Gui = NotificationBar

	local TextLabel = Make("TextLabel", {
		Parent                 = NotificationBar;
		TextColor3             = Color3.new(1, 1, 1);
		Size                   = UDim2.new(1, -10, 1, 0);
		Position               = UDim2.new(0, 10, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Visible                = true;
		Archivable             = false;
		ZIndex                 = NotificationBar.ZIndex;
		Text                   = "";
		TextXAlignment         = "Left";
	})

	local IsVisible
	local ShowPosition
	local HidePosition

	if IsTop then
		ShowPosition = UDim2.new(0, 0, 0, 0)
		HidePosition = UDim2.new(0, 0, 0, -Configuration.Height);
	else
		ShowPosition = UDim2.new(0, 0, 1, -Configuration.Height)
		HidePosition = UDim2.new(0, 0, 1, 0);
	end

	local function Show(DoNotAnimate)
		--- Show's the Notification bar. Updates the IsVisible variable to true
		-- @param DoNotAnimate Boolean, if true, then it will not animate when showing, otherwise it will tween

		IsVisible = true

		if DoNotAnimate then
			NotificationBar.Position = ShowPosition
		else	
			NotificationBar:TweenPosition(ShowPosition, "Out", "Sine", 0.2, true)
		end
	end
	Notifier.Show = Show

	local function Hide(DoNotAnimate)
		--- Hide's the Notification bar. Updates the IsVisible variable to false
		-- @param DoNotAnimate Boolean, if true, then it will not animate when hiding, otherwise it will tween

		IsVisible = false

		if DoNotAnimate then
			NotificationBar.Position = HidePosition
		else
			NotificationBar:TweenPosition(HidePosition, "In", "Sine", 0.2, true)
		end
	end
	Notifier.Hide = Hide

	local function SetText(NewText)
		if not IsVisible then
			Show()
		end

		TextLabel.Text = NewText;
	end
	Notifier.SetText = SetText

	Hide(true)
end)

local MakeOutputStreamRender = Class(function(OutputStreamRender, Configuration, ScreenGui)
	--- Render's a single stream, actual "view" model versus DataStreamRender conceptual model. 
	-- @param FrameRenderBufferSize Number The amount of frames to render.
	--                              This get's kind of messy when it comes down to it, because a render can be used by multiple
	--                              classes. A standardized number should be used. 

	local Configuration = OverriddenConfiguration.New(Configuration, DefaultConfiguration)
	local Buffer   = CircularBuffer.New(Configuration.FrameRenderBufferSize)
	OutputStreamRender.Buffer = Buffer
	-- Make the new frame containing the whole thing. Will also hold the scroll bar. 
	local MainFrame = Make("Frame", {
		Active                 = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "OutputStreamRender";
		Size                   = UDim2.new(1, 0, 1, 0);
		ZIndex                 = Configuration.ZIndex;
		Archivable             = false;
	})
	OutputStreamRender.Gui = MainFrame

	local ContentContainer = Make("Frame", {
		Active                 = false;
		BackgroundTransparency  = 1;
		ClipsDescendants       = true;
		Name                   = "ContentContainer";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, -Configuration.ScrollbarWidth, 1, 0);
		ZIndex                 = Configuration.ZIndex;
	})

	local ContentFrameClass = "ImageButton";
	if qGUI.IsPhone(ScreenGui) then
		ContentFrameClass = "Frame";
	end


	local ContentFrame = Make(ContentFrameClass, {
		Active                 = false;
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "ContentFrame";
		Parent                 = ContentContainer;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, 0, 1, 0);
		ZIndex                 = Configuration.ZIndex;
	})
	OutputStreamRender.ContentFrame = ContentFrame

	if ContentFrameClass == "ImageButton" then
		ContentFrame.Image = ""; 
	end

	local ScrollBarFrame = Make("Frame", {
		BackgroundTransparency = 1;
		BorderSizePixel        = 0; 
		Name                   = "ScrollBarFrame";
		Parent                 = MainFrame;
		Position               = UDim2.new(1, -Configuration.ScrollbarWidth, 0, 0);
		Size                   = UDim2.new(0, Configuration.ScrollbarWidth, 1, 0);
		Visible                = true;
		ZIndex                 = Configuration.ZIndex;
		Archivable             = false;
	})

	local NotifierTop           = MakeNotifier(ContentContainer, true)
	local NotifierBottom        = MakeNotifier(ContentContainer, false)
	
	local Scroller              = ScrollBar.MakeScroller(ContentContainer, ContentFrame, ScreenGui, 'Y')
	OutputStreamRender.Scroller = Scroller
	local ScrollBar             = Scroller:AddScrollBar(ScrollBarFrame)
	local ScrollBarAtBottom     = true
	local IsScrolling           = false
	local IsAutoScrolling       = false -- Is the porgram scrolling by itself? 

	--[[local function IsItemGuiVisible(Gui)
		--- Calculates whether or not the player can see the label.
		-- Used internally.

		if MainFrame.Visible then
			local PositionY = Gui.AbsolutePosition.Y
			if ContentContainer.AbsolutePosition.Y >= PositionY and (ContentContainer.AbsolutePosition.Y + ContentContainer.Size.Y.Offset) <= PositionY then
				return true
			else
				PositionY = PositionY + Gui.Size.Y.Offset
				return ContentContainer.AbsolutePosition.Y >= PositionY and (ContentContainer.AbsolutePosition.Y + ContentContainer.Size.Y.Offset) <= PositionY 
			end
		else
			return false
		end
	end--]]

	local function DoShowInterface()
		--- Returns whether or not the interface shoudl be shown.
		-- Not efficient, but readable, which is more important.
		-- @return boolean Should be shown, if true, otherwise, false

		-- print(IsScrolling, IsAutoScrolling, ScrollBarAtBottom)

		if IsScrolling or IsAutoScrolling then
			return true
		elseif not ScrollBarAtBottom then
			return true
		end

		return false
	end
	OutputStreamRender.DoShowInterface = DoShowInterface
	OutputStreamRender.doShowInterface = DoShowInterface

	local function RemoveOldItem(OldItem)
		--- GC's an old item, removing from the qeueue. 
		-- @param OldItem An old item in the equeue, created by RenderNew in the DataStreamRender class.
		
		OldItem.Gui:Destroy()
	end

	local function HideScrollBar(AnimateTime)
		--- Makes the scroll bar invisible

		-- print("Hideing scroll bar")
		-- ScrollBarFrame.Visible = false
		if AnimateTime <= 0 then
			ScrollBarFrame.ScrollBar.Backing.BackgroundTransparency = 1
		else
			qGUI.TweenTransparency(ScrollBarFrame.ScrollBar.Backing, {BackgroundTransparency = 1}, AnimateTime, true)
		end
		
	end
	OutputStreamRender.HideScrollBar = HideScrollBar
	OutputStreamRender.hideScrollBar = HideScrollBar

	local function ShowScrollBar(AnimateTime)
		--- Makes the scroll bar visible.

		-- print("Showing scroll bar")
		-- ScrollBarFrame.Visible = true
		if AnimateTime <= 0 then
			ScrollBarFrame.ScrollBar.Backing.BackgroundTransparency = 0.5
		else
			qGUI.TweenTransparency(ScrollBarFrame.ScrollBar.Backing, {BackgroundTransparency = 0.5}, AnimateTime, true)
		end
	end
	OutputStreamRender.ShowScrollBar = ShowScrollBar
	OutputStreamRender.showScrollBar = ShowScrollBar

	local function GetScrollBarAtBottom()
		--- Check's to see if the scroll bar is at the bottom or not
		-- @return Boolean, true if the scroll bar is at the bottom. 
		-- Used internally.

		return Scroller.KineticModel.Position <= Scroller.KineticModel.Minimum + 2
	end

	local function ScrollToBottom(DoNotAnimate)
		--- Scrolls the scrol bar to the bottom. 
		-- print(DoNotAnimate)
		Scroller:AdjustRange() -- Unfortunately, the event fires slow otherwise. 
		Scroller.ScrollTo(ContentContainer.AbsoluteSize.Y - ContentFrame.AbsoluteSize.Y, DoNotAnimate)
	end
	OutputStreamRender.ScrollToBottom = ScrollToBottom
	OutputStreamRender.ScrollToBottom = ScrollToBottom

	local function UpdateInterface(IsActive)
		if IsActive then
			ShowScrollBar()
		else
			HideScrollBar()
		end
	end
	OutputStreamRender.UpdateInterface = UpdateInterface
	OutputStreamRender.updateInterface = UpdateInterface

	local LastFrameHeight = ContentFrame.Size.Y.Offset

	local function TimeStampToText(TimeStamp)
		-- Converts the time stamp into something more relative...
		-- @param TimeStamp A time stamp

		local RenderTimePass = "[ Error ]"
		if TimeStamp < 20 then
			RenderTimePass = "a few seconds";
		elseif TimeStamp < 60 then
			RenderTimePass = "less than a minute";
		elseif TimeStamp < 120 then
			RenderTimePass = "1 minute"
		elseif TimeStamp < 3600 then
			RenderTimePass = qTime.GetMinute(TimeStamp) .. " minutes"
		elseif TimeStamp < 216000 then
			RenderTimePass = "about 1 hour"
		elseif TimeStamp < 219600 then
			RenderTimePass = "about " .. qTime.GetHour(TimeStamp) .. " hours"
		else
			RenderTimePass = qTime.GetDayOfTheWeek(SmallestTimeStamp) -- If this ever ever happens in a ROBLOX server, I may die. 
		end

		return RenderTimePass
	end

	local function UpdateSeenCount(TopOfWindow, BottomOfWindow)
		---[[
		local ItemsNotSeenBelow = 0;
		local ItemsNotSeenAbove = 0;
		local SmallestTimeStampBelow = tick()
		local SmallestTimeStampAbove = tick()

		local DataBuffer = Buffer:GetData()

		for Index = #DataBuffer, 1, -1 do
			local Item = DataBuffer[Index]
			
			if not Item.Seen then
				local YPosition = Item.Gui.AbsolutePosition.Y

				--NEW MENTAL THOUGHTS: Get distance from visible space.


				local DistanceFromTop = TopOfWindow - (YPosition + Item.Gui.AbsoluteSize.Y)
				local DistanceFromBottom = YPosition - BottomOfWindow

				if DistanceFromTop >= 0 then -- We are above the frame.
					ItemsNotSeenAbove = ItemsNotSeenAbove + 1
				elseif DistanceFromBottom >= 0 then
					ItemsNotSeenBelow = ItemsNotSeenBelow + 1
				else
					Item.Seen = true
				end
			end
		end

		if ItemsNotSeenBelow > 0 then
			NotifierBottom.SetText(ItemsNotSeenBelow .. " unread message" .. ((ItemsNotSeenBelow == 1) and "" or "s") .. " (" .. TimeStampToText(tick() - SmallestTimeStampBelow) .. ")")
		else
			NotifierBottom.Hide()
		end

		if ItemsNotSeenAbove > 0 then
			NotifierTop.SetText(ItemsNotSeenAbove .. " unread message" .. ((ItemsNotSeenAbove == 1) and "" or "s") .. " (" .. TimeStampToText(tick() - SmallestTimeStampAbove) .. ")")
		else
			NotifierTop.Hide()
		end
	end


	local function Update(DoNotAnimate, OldItemChange)
		--- Updates positions and rendering.
		-- @param DoNotAnimate Set to true if you do not want to animate

		local WasAtBottom = ScrollBarAtBottom
		local CurrentHeight = 0

		local DataBuffer = Buffer:GetData()

		for Index = #DataBuffer, 1, -1 do
			local Item = DataBuffer[Index]
			Item.Gui.Position = UDim2.new(0, 0, 0, CurrentHeight)
			CurrentHeight = CurrentHeight + Item.Gui.Size.Y.Offset
		end

		-- for _, Element in ipairs(Buffer:GetData()) do
			-- CurrentHeight = CurrentHeight + Element.Gui.Size.Y.Offset
			-- Element.Gui.Position = UDim2.new(0, 0, 1, -CurrentHeight)
		-- end

		ContentFrame.Size = UDim2.new(1, 0, 0, math.max(CurrentHeight, ContentContainer.AbsoluteSize.Y))
		local ChangeInSize = (LastFrameHeight - ContentFrame.Size.Y.Offset)
		LastFrameHeight = ContentFrame.Size.Y.Offset

		-- Only auto scroll if we are already auto scrolling and the user is not scrolling.
		if not IsScrolling or IsAutoScrolling then
			if WasAtBottom then
				-- Autoscroll down if we're already at the bottom. 
				
				-- IsAutoScrolling = true
				ScrollToBottom(true)
			elseif OldItemChange ~= 0 then
				if Scroller.KineticModel.Position < -OldItemChange then
					-- Stay even, unless we're at the very end. 
					-- print("Item was not at bottom; ChangeInIndex = " .. ChangeInIndex .. " Scroller.KineticModel.Position = " .. Scroller.KineticModel.Position)
					print("Current Position @ " .. Scroller.KineticModel.Position .. "! OldItemChange is " .. OldItemChange)
					-- Scroller.ScrollTo(Scroller.KineticModel.Position + ChangeInIndex, true)
					IsAutoScrolling = true
					Scroller.ScrollTo(Scroller.KineticModel.Position + OldItemChange, true)
				else
					IsAutoScrolling = true
					Scroller.ScrollTo(0, true)
				end
			end
		end

		UpdateSeenCount(ContentContainer.AbsolutePosition.Y, ContentContainer.AbsolutePosition.Y + ContentContainer.AbsoluteSize.Y)
		LastHeight = CurrentHeight
	end

	local function Insert(Index, NewElement, DoNotAnimate)
		local OldItem = Buffer:Insert(Index, NewElement)
		local Change = 0

		-- Garbage collect
		if OldItem then
			Change = OldItem.Gui.Size.Y.Offset
			RemoveOldItem(OldItem)
		end

		NewElement.Seen = false	-- NewElement.Seen = IsItemGuiVisible(NewElement.Gui);

		Update(DoNotAnimate, Change)
	end
	OutputStreamRender.Insert = Insert
	OutputStreamRender.insert = Insert

	--------------------
	-- CONNECT EVENTS --
	--------------------

	-- Scroll events. 
	local StartScrollPosition = 0
	local TopOfWindow = 0
	local BottomOfWindow = 0

	--[[
	0     StartPosition


	-5000 EndPosition
	-----------
	0 EndPosition

	-5000 StartPosition
	---]]
	Scroller.ScrollStarted:connect(function(Position)
		StartScrollPosition = ContentFrame.AbsolutePosition.Y -- Let's say this is -200 out of -400 max range.
		TopOfWindow, BottomOfWindow = ContentContainer.AbsolutePosition.Y, ContentContainer.AbsolutePosition.Y + ContentContainer.AbsoluteSize.Y

		IsScrolling = true -- We scroll to -300 (So we've scrolled up) We need to catch 
	end)

	Scroller.ScrollFinished:connect(function(KineticEndPosition)
		if IsAutoScrolling then -- Make sure it isn't the program that is scrolling. 
			IsAutoScrolling = false
		else
			local ChangeInPosition = ContentFrame.AbsolutePosition.Y - StartScrollPosition
			if ChangeInPosition ~= 0 then
				-- local EndPosition
				-- local StartPosition

				if ChangeInPosition > 0 then
					-- Moved up


					UpdateSeenCount(ContentContainer.AbsolutePosition.Y, BottomOfWindow)

					-- EndPosition = ContentContainer.AbsolutePosition.Y
					-- StartPosition = ContentContainer.AbsolutePosition.Y + ContentContainer.AbsoluteSize.Y + ChangeInPosition
					-- print("Scroll Up: StartPosition = " .. StartPosition .. " :: EndPosition = " .. EndPosition)
				elseif ChangeInPosition < 0 then
					-- Moved down 

					UpdateSeenCount(TopOfWindow, ContentContainer.AbsolutePosition.Y + ContentContainer.AbsoluteSize.Y)

					-- EndPosition = ContentContainer.AbsolutePosition.Y + ContentContainer.AbsoluteSize.Y
					-- StartPosition = ContentContainer.AbsolutePosition.Y + ChangeInPosition
					-- print("Scroll Down: StartPosition = " .. StartPosition .. " :: EndPosition = " .. EndPosition)
				end
			end
		end

		IsScrolling = false
		ScrollBarAtBottom = GetScrollBarAtBottom()
	end)
end)

local MakeOutputStreamInterface = Class(function(OutputStreamInterface, Configuration, ScreenGui)
	-- Creates an interactive interface that allows for multiple incoming channels, et cetera. 

	local Configuration = OverriddenConfiguration.New(Configuration, DefaultConfiguration)
	local Subscribed = {} -- Maintain list of subscribed units. 


	local MainFrame = Make("ImageButton", {
		Active                 = false;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1.0;
		Name                   = "OutputStreamInterface";
		Parent                 = ScreenGui;
		Size                   = qGUI.IsPhone(ScreenGui) and -- Some really horrible calculatinzsdf
		                         UDim2.new(0, 280 + Configuration.TitleWidth + Configuration.ScrollbarWidth, 0, Configuration.ContentHeight + PseudoChatSettings.LineHeight) 
		                         or UDim2.new(0, 500 + Configuration.TitleWidth + Configuration.ScrollbarWidth, 0, Configuration.ContentHeight + PseudoChatSettings.LineHeight);
		ZIndex                 = Configuration.MenuZIndex - 1;
		ClipsDescendants       = true;
		Position = UDim2.new(0, 0, 0, 6);
	})
	OutputStreamInterface.Gui = MainFrame

	local ContentContainer = Make("Frame", {
		Active                 = false;
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "ContentContainer";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, -Configuration.TitleWidth, 1, 0);
		ZIndex                 = Configuration.ZIndex;
	})

	local Menu      = MakeOutputStreamMenu(MainFrame, ScreenGui, Configuration)
	local ActiveSubscriber
	local Mouse     = Players.LocalPlayer:GetMouse()
	local MouseOver = qGUI.MouseOver(Mouse, MainFrame)

	local function DoShowInterface()
		if MouseOver then --qGUI.MouseOver(Mouse, MainFrame) then
			return true
		elseif Menu.GetIsShown() then
			return true
		elseif ActiveSubscriber then
			return ActiveSubscriber.RenderFrame.DoShowInterface()
		else
			return false
		end
	end

	local function UpdateVisibility(DoNotAnimate)
		if DoShowInterface() then
			Menu.SetTransparency(0, DoNotAnimate and nil or Configuration.MenuAnimateTime)
			for _, Item in pairs(Subscribed) do
				Item.RenderFrame.ShowScrollBar(Configuration.MenuAnimateTime)
			end
		else
			Menu.SetTransparency(1, DoNotAnimate and nil or Configuration.MenuAnimateTime)
			for _, Item in pairs(Subscribed) do
				Item.RenderFrame.HideScrollBar(Configuration.MenuAnimateTime)
			end
		end
	end
	OutputStreamInterface.UpdateVisibility = UpdateVisibility

	local ScrollerEvent

	local function SetActiveStream(Subscriber, DoNotAnimate)
		if ActiveSubscriber then
			ActiveSubscriber.Hide()
		end
		ActiveSubscriber = Subscriber
		Subscriber.Show()
		UpdateVisibility(DoNotAnimate)


		if ScrollerEvent then
			ScrollerEvent:disconnect()
			ScrollerEvent = nil
		end

		ScrollerEvent = Subscriber.RenderFrame.Scroller.ScrollFinished:connect(function()
			wait(0)
			UpdateVisibility()
		end)
	end

	local function Subscribe(OutputStreamSyndicator, RenderName, RenderColor)
		-- @param RenderName "String" The name to show on the menu option, if the default StreamName does not look pretty.
		-- @param RenderColor The color3 value to use on the menu choice.

		if Subscribed[OutputStreamSyndicator] then
			error("[OutputStreamInterface] - Already subscribed to '" .. OutputStreamSyndicator.Name .. "'")
		else
			RenderColor = RenderColor or Color3.new(0, 0, 0)
			RenderName = RenderName or OutputStreamSyndicator.Name or tostring(OutputStreamSyndicator)

			local Subscriber = {}
			local RenderFrame = MakeOutputStreamRender(Configuration, ScreenGui)
			local MenuOption = Menu.MakeChoice(RenderName, RenderColor)
			Subscriber.RenderFrame = RenderFrame

			local function HandleNewItem(OutputClass, Data, DoNotAnimate)
				local BufferData = RenderFrame.Buffer:GetData()
				local Index = 1
				local TimeStamp = Data.TimeStamp
				assert(TimeStamp ~= nil, "[OutputStreamInterface] - TimeStamp is " .. tostring(TimeStamp))
				-- TimeStamp organization / mental thoughts
				--[[ Inserting: 3000

					1 : Most Recent : 2000
					2 : Second Reef : 1995
					3 : ........... : 0343

					if [1] and 2000 > 3000 then
						Index = 2
					....
					if [2] and 1995 > 3000 
				--]]

				while BufferData[Index] and BufferData[Index].Data.TimeStamp > TimeStamp do
					print(Index .. " : " .. BufferData[Index].Data.TimeStamp .. " > " .. TimeStamp)
					Index = Index + 1
				end

				if Index < RenderFrame.Buffer.BufferSize then
					local NewItem = {}

					local Gui    = OutputClass.Render(ActiveSubscriber.RenderFrame.ContentFrame, Data, DoNotAnimate or (Index == RenderFrame.Buffer.BufferSize))
					Gui.Parent   = RenderFrame.ContentFrame
					NewItem.Gui  = Gui
					NewItem.Data = Data

					-- print("DoNotAnimate: " .. DoNotAnimate)
					RenderFrame.Insert(Index, NewItem, DoNotAnimate)
				else
					print("[OutputStreamInterface] - Will not insert new item old time stamp @ " .. tostring(TimeStamp))
				end
			end

			function Subscriber.Show()
				RenderFrame.Gui.Visible = true
				Menu.SetColorAndTitle(RenderColor, RenderName)
			end

			function Subscriber.Hide()
				RenderFrame.Gui.Visible = false
			end

			-- Connect Events --

			OutputStreamSyndicator.NewItem:connect(function(OutputStreamClient, OutputClass, Data)
				assert(Data ~= nil, "Data is nil")
				HandleNewItem(OutputClass, Data, ActiveSubscriber ~= Subscriber)
			end)

			MenuOption.Gui.MouseButton1Click:connect(function()
				SetActiveStream(Subscriber)
				Menu.Collapse()
			end)

			-- Setup Subscription, GUI stuff --

			RenderFrame.Gui.Parent = ContentContainer

			Subscribed[OutputStreamSyndicator] = Subscriber
			if not ActiveSubscriber then
				SetActiveStream(Subscriber)
			else
				Subscriber.Hide()
			end

			-- Handle Logs -- 
			local Logs = OutputStreamSyndicator.GetSyndicatedLogs()
			for _, Item in pairs(Logs) do
				HandleNewItem(Item.OutputClass, Item.Data, true)
			end
			Logs = nil -- GC

			return Subscriber
		end
	end
	OutputStreamInterface.Subscribe = Subscribe
	OutputStreamInterface.subscribe = Subscribe

	-- SETUP EVENTS --
	MainFrame.MouseEnter:connect(function()
		MouseOver = true
		UpdateVisibility()
	end)

	MainFrame.MouseLeave:connect(function()
		MouseOver = false
		UpdateVisibility()
	end)

	Menu.MenuCollapseChanged:connect(function(State)
		UpdateVisibility()
	end)

	UpdateVisibility(true)
end)
lib.MakeOutputStreamInterface = MakeOutputStreamInterface
lib.makeOutputStreamInterface = MakeOutputStreamInterface

return lib