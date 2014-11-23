local ReplicatedStorage       = game:GetService("ReplicatedStorage")
local UserInputService        = game:GetService("UserInputService")
local Players                 = game:GetService("Players")

local NevermoreEngine         = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary       = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local qGUI                    = LoadCustomLibrary("qGUI")
local CircularBuffer          = LoadCustomLibrary("CircularBuffer")
local PseudoChatSettings      = LoadCustomLibrary("PseudoChatSettings")
local OverriddenConfiguration = LoadCustomLibrary("OverriddenConfiguration")
local qTime                   = LoadCustomLibrary("qTime")
local qMath                   = LoadCustomLibrary("qMath")
local Maid                    = LoadCustomLibrary("Maid")
local ScrollingFrame          = LoadCustomLibrary("ScrollingFrame")
local qColor3                 = LoadCustomLibrary("qColor3")
local Signal                  = LoadCustomLibrary("Signal")

local Make = qSystems.Make
local Class = qSystems.Class

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
	ScrollbarWidth        = 7;
	ZIndex                = 8;
	FrameRenderBufferSize = PseudoChatSettings.BufferSize;
	
	TitleLabelOffsetY     = 10;
	TitleLabelOffsetX     = 6;
	
	MenuZIndex            = 9; -- ZIndex of the menu overlay. We'll try to maintain a [8,9] ZIndex range. 
	MenuAnimateTime       = 0.1;
	MenuDefaultColor      = Color3.new(0.5, 0.5, 0.5);
	MenuNameWhenOpen      = "Change Channels?";

	RenderStreamMenu = {
		ChoiceSizeY        = 38;
		ChoiceSizeXPadding = 0; -- Padding total on the X axis. 
		ChoiceYPadding     = 0; -- Padding between each choice. 
		DividerPaddingX    = 15;
	};

	-- FactoryConfigurationSettingNameEnumThingHere
	UIBackgroundTransparencyOnMouseOver = 1;
	ScrollBarBackingTransparencyOnMouseOver = 0.3;
}

local MakeOutputStreamMenu = Class(function(RenderStreamMenu, Parent, ScreenGui, Configuration)
	--- Creates a list of open "Channels" which can be dynamically changed and modified. 
	-- @param OutputStreamInterface The interface that this stream menu is associated with. 
	-- Used internally, Configuration is expected to be sent by the script, all contents intact.

	local MouseEvent
	local Mouse         = Players.LocalPlayer:GetMouse()
	local IsCollapsed   = false
	local CurrentColor  = Color3.new(247/255, 247/255, 247/255);
	local CurrentTitle  = "[ Nothing Active ]"
	local ActiveChoices = {}

	local Scroller, MenuScrollBar

	RenderStreamMenu.MenuCollapseChanged = Signal.new() -- Sends Signal(IsCollapsed)

	local MainFrame = Make("Frame", {
		Active                 = false;
		Archivable             = false;
		BackgroundColor3       = Color3.new(250/255, 250/255, 250/255);
		BackgroundTransparency = 0;
		BorderSizePixel        = 0;
		Name                   = "MenuFrame";
		Position               = UDim2.new(0.5, 0, 0, 0);
		Size                   = UDim2.new(0.5, 0, 1, 0);
		ZIndex                 = Configuration.MenuZIndex;
		Parent                 = Parent;
	})
	RenderStreamMenu.Gui = MainFrame

	local TitleButton = Make("ImageButton", {
		Archivable       = false;
		BackgroundColor3 = Color3.new(247/255, 247/255, 247/255);
		BorderSizePixel  = 0;
		Name             = "TitleButton";
		Parent           = MainFrame;
		Position         = UDim2.new(0, -Configuration.TitleWidth, 0, 0);
		Size             = UDim2.new(0, Configuration.TitleWidth, 1, 0);
		ZIndex           = Configuration.MenuZIndex;
		AutoButtonColor  = false;

		Make("Frame", {
			BorderSizePixel  = 0;
			BackgroundColor3 = Color3.new(215/255, 215/255, 215/255);
			Name             = "Divider";
			Position         = UDim2.new(1, -3, 0, 0);
			Size             = UDim2.new(0, 3, 1, 0);
			ZIndex           = Configuration.MenuZIndex;
		})
	})

	local function OnTitleButtonEnter()
		TitleButton.BackgroundColor3 = Color3.new(247/255 - 0.05, 247/255 - 0.05, 247/255 - 0.05)
	end

	local function OnTitleButtonLeave()
		TitleButton.BackgroundColor3 = Color3.new(247/255, 247/255, 247/255)
	end

	TitleButton.MouseEnter:connect(OnTitleButtonEnter)
	TitleButton.MouseLeave:connect(OnTitleButtonLeave)

	local TitleLabel = Make("TextLabel", {
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "TitleLabel";
		Parent                 = TitleButton;
		Rotation               = 90;
		Size                   = UDim2.new(0, TitleButton.AbsoluteSize.Y - Configuration.TitleLabelOffsetY, 0, Configuration.TitleWidth - Configuration.TitleLabelOffsetX);
		Text                   = "Main Menu";
		TextColor3             = Color3.new(1, 1, 1);
		TextXAlignment         = "Right";
		ZIndex                 = Configuration.MenuZIndex;
		TextTransparency       = 0.13;
		FontSize               = "Size14";
		Font                   = "SourceSans";
	})
	TitleLabel.Position = UDim2.new(0.5, -(TitleButton.AbsoluteSize.Y - Configuration.TitleLabelOffsetX) / 2, 0.5, -(TitleButton.AbsoluteSize.X - Configuration.TitleLabelOffsetY) / 2);

	local ContentContainer = Make("Frame", {
		Active                 = false;
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "ContentContainer";
		BorderSizePixel        = 0;
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, -Configuration.ScrollbarWidth, 1, 0);
		ZIndex                 = Configuration.MenuZIndex;
		Archivable             = false;
	})

	local ContentFrame = Make("Frame", {
		Active                 = false;
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "ContentFrame";
		Parent                 = ContentContainer;
		Position               = UDim2.new(0, 1, 0, 0);
		Size                   = UDim2.new(1, -1, 1, 0);
		ZIndex                 = Configuration.MenuZIndex;
		Archivable             = false;
		BorderSizePixel        = 0;

		Make("Frame", {
			BorderSizePixel  = 0;
			BackgroundColor3 = Color3.new(225/255, 225/255, 225/255);
			Name             = "Divider";
			Position         = UDim2.new(0, Configuration.RenderStreamMenu.DividerPaddingX, 0, 0);
			Size             = UDim2.new(1, -Configuration.RenderStreamMenu.DividerPaddingX, 0, 1);
			ZIndex           = Configuration.MenuZIndex;
		})
	})

	local ScrollBarFrame = Make("Frame", {
		Active                 = true;
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

	local Scroller  = ScrollingFrame.new(ContentFrame)
	local ScrollBar = Scroller:AddScrollBar(ScrollBarFrame)

	local function UpdateChoices()
		--- Repositions and updates the choices to new locations. 

		local YPosition = DefaultConfiguration.RenderStreamMenu.ChoiceYPadding + 1;
		local ChoiceCount = 0

		table.sort(ActiveChoices, function(A, B)
			if A == B then
				return A.Index < B.Index
			else
				return A.Priority < B.Priority
			end
		end)

		for Index, Choice in pairs(ActiveChoices) do
			ChoiceCount         = ChoiceCount + 1
			
			local OldTarget = Choice.TargetPosition
			Choice.TargetPosition = UDim2.new(0, Configuration.RenderStreamMenu.ChoiceSizeXPadding/2, 0, YPosition)
			Choice.Index = Index

			if not OldTarget then
				if IsCollapsed then
					Choice.OnCollapse(true)
				else
					Choice.OnUnCollapse(true)
				end
			end

			YPosition             = YPosition + Configuration.RenderStreamMenu.ChoiceYPadding + Choice.YHeight
		end
		ContentFrame.Size = UDim2.new(1, 0, 0, math.max(YPosition, ContentContainer.AbsoluteSize.Y))

		if YPosition > ContentContainer.AbsoluteSize.Y then
			ScrollBarFrame.Visible = true
			ContentContainer.Size  = UDim2.new(1, -Configuration.ScrollbarWidth, 1, 0);
		else
			ScrollBarFrame.Visible = false
			ContentContainer.Size  = UDim2.new(1, 0, 1, 0);
		end

		if ChoiceCount > 1 then
			MainFrame.Visible = true
		else
			MainFrame.Visible = false
		end
	end

	local function UpdateTitleBar(TextColor3, Text, DoNotAnimate)
		--- Sets the TitleBar, helper function
		-- @param TextColor3 The new TextColor3 to set
		-- @param Text The text to set
		-- @param DoNotAnimate Shoudl it animate or not?

		TitleLabel.Text = Text;

		if DoNotAnimate then
			TitleLabel.TextColor3 = TextColor3
		else
			qGUI.TweenColor3(TitleLabel, {TextColor3 = TextColor3}, Configuration.MenuAnimateTime, true)
		end
	end

	local function UnCollapse(DoNotAnimate)
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

		IsCollapsed = true
		local Position = UDim2.new(0.5, 0, 0, 0)
		UpdateTitleBar(Configuration.MenuDefaultColor, Configuration.MenuNameWhenOpen, DoNotAnimate)

		--- Fixes issues with the leave event not firing when tweening stuff.
		for _, Choice in pairs(ActiveChoices) do
			if qGUI.MouseOver(Mouse, Choice.Gui) then
				Choice.OnMouseEnter()
			end

			Choice.OnUnCollapse(DoNotAnimate)
		end

		if DoNotAnimate then
			MainFrame.Position = Position
		else
			MainFrame:TweenPosition(Position, "Out", "Sine", Configuration.MenuAnimateTime, true)
		end

		RenderStreamMenu.MenuCollapseChanged:fire(false)
	end
	RenderStreamMenu.UnCollapse = UnCollapse
	RenderStreamMenu.unCollapse = UnCollapse

	local function Collapse(DoNotAnimate)
		--- Hide's the menu
		-- @param [DoNotAnimate] If indicated, will not animate the menu when showing or hiding. 

		if MouseEvent then
			MouseEvent:disconnect()
			MouseEvent = nil
		end

		IsCollapsed = false
		local Position = UDim2.new(1, 0, 0, 0)
		UpdateTitleBar(CurrentColor, CurrentTitle, DoNotAnimate)

		--- Fixes issues with the leave event not firing when tweening stuff.
		for _, Choice in pairs(ActiveChoices) do
			Choice.OnMouseLeave()
			Choice.OnCollapse(DoNotAnimate)
		end

		if DoNotAnimate then
			MainFrame.Position = Position
		else
			MainFrame:TweenPosition(Position, "Out", "Sine", Configuration.MenuAnimateTime, true)
		end

		RenderStreamMenu.MenuCollapseChanged:fire(true)
	end
	RenderStreamMenu.Collapse = Collapse

	local CurrentTransparency

	local function SetTransparency(NewTransparency, AnimateTime)
		--- Sets the transparency of the Interface to NewTransparency
		-- @param NewTransparency The transparency to set it to
		-- @param AnimateTime The time to animate. If not provided, will do it instantly. 

		assert(NewTransparency ~= nil, "NewTransparency is nil.")

		if CurrentTransparency ~= NewTransparency then -- Make sure we don't waste processing power. 
			-- Tweening stuff....

			CurrentTransparency = NewTransparency
			if AnimateTime and AnimateTime > 0 then -- Do tween
				local NewBackground = {BackgroundTransparency = NewTransparency}
				local NewText       = {TextTransparency = qMath.LerpNumber(0.13, 1, NewTransparency)}

				qGUI.TweenTransparency(MainFrame,           NewBackground, AnimateTime, true)
				qGUI.TweenTransparency(TitleButton,         NewBackground, AnimateTime, true)
				qGUI.TweenTransparency(TitleButton.Divider, NewBackground, AnimateTime, true)
				qGUI.TweenTransparency(TitleLabel,          NewText,       AnimateTime, true)

				for _, Item in pairs(ActiveChoices) do
					qGUI.TweenTransparency(Item.Gui,             NewBackground, AnimateTime, true)
					qGUI.TweenTransparency(Item.Gui.Divider,     NewBackground, AnimateTime, true)
					qGUI.TweenTransparency(Item.Gui.ChoiceLabel, NewText,       AnimateTime, true)
				end
			else
				--- Don't tween!


				local NewTextTransparency = qMath.LerpNumber(0.13, 1, NewTransparency)

				qGUI.StopTransparencyTween(MainFrame)
				qGUI.StopTransparencyTween(TitleButton)
				qGUI.StopTransparencyTween(TitleButton.Divider)
				qGUI.StopTransparencyTween(TitleLabel)

				MainFrame.BackgroundTransparency           = NewTransparency
				TitleButton.BackgroundTransparency         = NewTransparency
				TitleButton.Divider.BackgroundTransparency = NewTransparency
				TitleLabel.TextTransparency                = NewTextTransparency

				for _, Item in pairs(ActiveChoices) do
					qGUI.StopTransparencyTween(Item.Gui)
					qGUI.StopTransparencyTween(Item.Gui.Divider)
					qGUI.StopTransparencyTween(Item.Gui.ChoiceLabel)

					Item.Gui.BackgroundTransparency         = NewTransparency
					Item.Gui.Divider.BackgroundTransparency = NewTransparency
					Item.Gui.ChoiceLabel.TextTransparency   = NewTextTransparency
				end
			end
		end
	end
	RenderStreamMenu.SetTransparency = SetTransparency

	local function Show(AnimateTime)
		--- Ugh, two layers of shown. IsCollapsed is for collapsing.

		SetTransparency(0, AnimateTime)

		if not IsCollapsed then
			local Position = UDim2.new(1, 0, 0, 0)

			if AnimateTime and AnimateTime > 0 then
				MainFrame:TweenPosition(Position, "Out", "Quad", AnimateTime, true)
			else
				MainFrame.Position = Position
			end
		end
	end
	RenderStreamMenu.Show = Show

	local function Hide(AnimateTime)
		--- Ugh, two layers of shown. IsCollapsed is for collapsing.
		-- If AnimateTime is nil, it will not animate.

		SetTransparency(1, AnimateTime)

		local Position = UDim2.new(1, Configuration.TitleWidth, 0, 0)

		if AnimateTime and AnimateTime > 0 then
			MainFrame:TweenPosition(Position, "Out", "Quad", AnimateTime, true)
		else
			MainFrame.Position = Position
		end
	end
	RenderStreamMenu.Hide = Hide


	local function SetColorAndTitle(Color, Title, DoNotAnimate)
		-- Sets the color and title of the Menu that it will display while "Hidden." "
		-- @param Color A Color3, the color of the menu to set.
		-- @param Title The title to show.

		CurrentColor = Color
		CurrentTitle = Title
		if not IsCollapsed then
			UpdateTitleBar(Color, Title, DoNotAnimate)
		end
	end
	RenderStreamMenu.SetColorAndTitle = SetColorAndTitle
	RenderStreamMenu.setColorAndTitle = SetColorAndTitle


	local function Toggle(DoNotAnimate)
		--- Toggle's the menu's visibility. 
		-- @param [DoNotAnimate] If indicated, will not animate the menu when showing or hiding. 

		if IsCollapsed then
			Collapse(DoNotAnimate)
		else
			UnCollapse(DoNotAnimate)
		end
	end
	RenderStreamMenu.Toggle = Toggle
	RenderStreamMenu.toggle = Toggle

	local function MakeChoice(Text, TextColor3, Priority)
		--- Creates a new "Choice" GUI, for further manipulation.
		-- @param [TextColor3] The color3 value of the text
		-- @param Text The text to display on the button.
		-- @return The new choice
		-- @param Priority Sorted by this number. 

		assert(Priority, "No Priority")
		assert(TextColor3, "No TextColor3")

		-- print("Before: " .. tostring(TextColor3))
		-- TextColor3 = qColor3.SetSaturationAndLuminance(TextColor3, 0.7, 0.6) -- Normalize, keep hue.
		-- print("After: " .. tostring(TextColor3))

		local NewChoice = {}
		NewChoice.Priority = Priority

		local ChoiceMaid = Maid.MakeMaid()

		NewChoice.TextColor3 = TextColor3
		NewChoice.Text = Text

		NewChoice.ChoiceSelected = Signal.new()
		
		local ChoiceButton = Make("ImageButton", {
			Archivable             = false;
			BackgroundColor3       = Color3.new(1, 1, 1);
			BackgroundTransparency = 0.3;
			BorderSizePixel        = 0;
			Name                   = "ChoiceButton";
			Parent                 = ContentFrame;
			Size                   = UDim2.new(1, -Configuration.RenderStreamMenu.ChoiceSizeXPadding, 0, Configuration.RenderStreamMenu.ChoiceSizeY);
			Image                  = "";
			Visible                = true;
			ZIndex                 = Configuration.MenuZIndex;
			AutoButtonColor        = false;

			-- Actual text.
			Make("TextLabel", {
				BackgroundTransparency = 1;
				BorderSizePixel        = 0;
				Name                   = "ChoiceLabel";
				Position               = UDim2.new(0, Configuration.RenderStreamMenu.DividerPaddingX, 0, 0);
				Size                   = UDim2.new(1, -Configuration.RenderStreamMenu.DividerPaddingX, 1, 0);
				Text                   = Text;
				TextColor3             = TextColor3;
				TextXAlignment         = "Left";
				ZIndex                 = Configuration.MenuZIndex;
				TextTransparency       = 0.13;
				FontSize               = "Size14";
				Font                   = "SourceSans";
			});

			-- Divider
			Make("Frame", {
				BorderSizePixel  = 0;
				BackgroundColor3 = Color3.new(225/255, 225/255, 225/255);
				Name             = "Divider";
				Position         = UDim2.new(0, Configuration.RenderStreamMenu.DividerPaddingX, 1, -1);
				Size             = UDim2.new(1, -Configuration.RenderStreamMenu.DividerPaddingX, 0, 1);
				ZIndex           = Configuration.MenuZIndex;
			})
		});
		NewChoice.YHeight = Configuration.RenderStreamMenu.ChoiceSizeY
		NewChoice.Gui     = ChoiceButton

		local function OnUnCollapse(DoNotAnimate)
			local NewPosition = NewChoice.TargetPosition

			if DoNotAnimate then
				ChoiceButton.Position = NewPosition
			else
				delay(Configuration.MenuAnimateTime * (NewChoice.Index/#ActiveChoices), function()
					ChoiceButton:TweenPosition(NewPosition, "Out", "Sine", Configuration.MenuAnimateTime, true)
				end)
			end
		end
		NewChoice.OnUnCollapse = OnUnCollapse

		local function OnCollapse(DoNotAnimate)
			local NewPosition = NewChoice.TargetPosition + UDim2.new(1 ,0, 0, 0) --UDim2.new(0, 0, 1, 0)

			if DoNotAnimate then
				ChoiceButton.Position = NewPosition
			else
				delay(Configuration.MenuAnimateTime * (NewChoice.Index/#ActiveChoices), function()
					ChoiceButton:TweenPosition(NewPosition, "Out", "Sine", Configuration.MenuAnimateTime, true)
				end)
			end
		end
		NewChoice.OnCollapse = OnCollapse

		local function OnMouseLeave()
			ChoiceButton.BackgroundColor3 = Color3.new(1, 1, 1)
		end
		NewChoice.OnMouseLeave = OnMouseLeave

		local function OnMouseEnter()
			ChoiceButton.BackgroundColor3 = Color3.new(0.95, 0.95, 0.95)
		end
		NewChoice.OnMouseEnter = OnMouseEnter

		function NewChoice:Destroy()
			-- For the GC of the choice.

			local Index = NewChoice.Index

			ChoiceButton:Destroy()
			NewChoice.Destroy = nil
			NewChoice         = nil

			ChoiceMaid:DoCleaning()

			table.remove(ActiveChoices, Index)
			for Index, ActiveChoice in pairs(ActiveChoices) do
				ActiveChoice.Index = Index
			end

			UpdateChoices()
		end

		ChoiceButton.MouseEnter:connect(OnMouseEnter) -- We'll GC these by using :Destroy()
		ChoiceButton.MouseLeave:connect(OnMouseLeave) -- We'll GC these by using :Destroy()

		--[[ChoiceButton.MouseButton1Down:connect(function(PositionX, PositionY)
			Scroller.StartDrag(PositionX, PositionY)
		end)

		ChoiceMaid.ScrollDone = Scroller.InputFinished:connect(function()
			if (tick() - TimeStart) <= 0.2 then
				print("Probably a click")
				if qGUI.MouseOver(Players.LocalPlayer:GetMouse(), ChoiceButton) then
					NewChoice.ChoiceSelected:fire()
				end
			end
		end)--]]
		
		ChoiceButton.MouseButton1Down:connect(function()
			Scroller:Tap(function(ConsideredClick, ElapsedTime, ScrollDistance)
				if ConsideredClick then
					NewChoice.ChoiceSelected:fire()
				end
			end)
		end)

		ChoiceButton.MouseWheelForward:connect(function()
			Scroller:ScrollUp()
		end)

		ChoiceButton.MouseWheelBackward:connect(function()
			Scroller:ScrollDown()
		end)

		local Index = #ActiveChoices + 1
		NewChoice.Index = Index
		ActiveChoices[Index] = NewChoice
		UpdateChoices()
		return NewChoice
	end
	RenderStreamMenu.MakeChoice = MakeChoice
	RenderStreamMenu.makeChoice = MakeChoice

	local function GetIsCollapsed()
		return IsCollapsed
	end
	RenderStreamMenu.GetIsCollapsed = GetIsCollapsed
	RenderStreamMenu.getIsCollapsed = GetIsCollapsed

	-- Setup events
	TitleButton.MouseButton1Click:connect(function()
		Toggle()
		OnTitleButtonLeave()
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



--- UTILITY ---

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
		RenderTimePass = qTime.GetDayOfTheWeek(TimeStamp) -- If this ever ever happens in a ROBLOX server, I may die. 
	end

	return RenderTimePass
end



--- RENDERING ----

local MakeOutputStreamRender = Class(function(OutputStreamRender, Configuration, ScreenGui, RenderColor)
	--- Render's a single stream, actual "view" model versus DataStreamRender conceptual model. 
	-- @param FrameRenderBufferSize Number The amount of frames to render.
	--                              This get's kind of messy when it comes down to it, because a render can be used by multiple
	--                              classes. A standardized number should be used. 

	local RenderMaid          = Maid.MakeMaid()
	
	local Configuration       = OverriddenConfiguration.new(Configuration, DefaultConfiguration)
	local Buffer              = CircularBuffer.new(Configuration.FrameRenderBufferSize)
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
		BackgroundTransparency = 1;
		ClipsDescendants       = true;
		Name                   = "ContentContainer";
		Parent                 = MainFrame;
		Position               = UDim2.new(0, 0, 0, 0);
		Size                   = UDim2.new(1, -Configuration.ScrollbarWidth, 1, 0);
		ZIndex                 = Configuration.ZIndex;
	})


	local ContentFrame = Make("Frame", {
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

	local ScrollBarFrame = Make("Frame", {
		Active                 = true;
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
	
	local Scroller  = ScrollingFrame.new(ContentFrame)
	local ScrollBar = Scroller:AddScrollBar(ScrollBarFrame)
	OutputStreamRender.Scroller = Scroller

	ScrollBar.BarFrame.Backing.BackgroundColor3 = qColor3.SetSaturationAndLuminance(RenderColor, 0.4, 0.6) -- Normalize colors.

	local function DoShowInterface()
		--- Returns whether or not the interface shoudl be shown.
		-- Not efficient, but readable, which is more important.
		-- @return boolean Should be shown, if true, otherwise, false

		if Scroller:IsScrolling() or Scroller:IsAutoScrolling() then
			return true
		elseif not Scroller:ExpectedAtBottom() then
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

		local NewPosition = UDim2.new(1, 0, 0, 0);

		if AnimateTime <= 0 then
			ScrollBarFrame.ScrollBar.Backing.BackgroundTransparency = 1
			ScrollBarFrame.Position = NewPosition
		else
			qGUI.TweenTransparency(ScrollBarFrame.ScrollBar.Backing, {BackgroundTransparency = 1}, AnimateTime, true)
			ScrollBarFrame:TweenPosition(NewPosition, "Out", "Quad", AnimateTime, true)
		end
		
	end
	OutputStreamRender.HideScrollBar = HideScrollBar
	OutputStreamRender.hideScrollBar = HideScrollBar

	local function ShowScrollBar(AnimateTime)
		--- Makes the scroll bar visible.

		local NewPosition = UDim2.new(1, -Configuration.ScrollbarWidth, 0, 0);

		if AnimateTime <= 0 then
			ScrollBarFrame.ScrollBar.Backing.BackgroundTransparency = Configuration.ScrollBarBackingTransparencyOnMouseOver
			ScrollBarFrame.Position = NewPosition
		else
			qGUI.TweenTransparency(ScrollBarFrame.ScrollBar.Backing, {BackgroundTransparency = Configuration.ScrollBarBackingTransparencyOnMouseOver}, AnimateTime, true)
			ScrollBarFrame:TweenPosition(NewPosition, "In", "Quad", AnimateTime, true)
		end
	end
	OutputStreamRender.ShowScrollBar = ShowScrollBar
	OutputStreamRender.showScrollBar = ShowScrollBar

	local function UpdateInterface(IsActive)
		if IsActive then
			ShowScrollBar()
		else
			HideScrollBar()
		end
	end
	OutputStreamRender.UpdateInterface = UpdateInterface
	OutputStreamRender.updateInterface = UpdateInterface

	local function UpdateSeenCount(TopOfWindow, BottomOfWindow)
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

	local function UpdateSeenCountOffset(OffsetFromTop, OffsetFromBottom)
		-- Just includes the absolute position and size stuff and lets you just send offsets.

		OffsetFromTop = OffsetFromTop or 0
		OffsetFromBottom = OffsetFromBottom or 0

		UpdateSeenCount(ContentContainer.AbsolutePosition.Y + OffsetFromTop, ContentContainer.AbsolutePosition.Y + ContentContainer.AbsoluteSize.Y + OffsetFromBottom)
	end

	local function Update(DoNotAnimate, FeedPositionDeltaY)
		--- Updates positions and rendering.
		-- @param DoNotAnimate Set to true if you do not want to animate
		-- @param FeedPositionDeltaY The change in position that all of the feed experienced when an old item was removed. 

		local WasAtBottom = Scroller:ExpectedAtBottom()
		local CurrentHeight = 0

		local DataBuffer = Buffer:GetData()

		for Index = #DataBuffer, 1, -1 do -- Transverse backwards. 
			local Item        = DataBuffer[Index]
			Item.Gui.Position = UDim2.new(0, 0, 0, CurrentHeight)

			CurrentHeight     = CurrentHeight + Item.Gui.Size.Y.Offset
		end

		ContentFrame.Size = UDim2.new(1, 0, 0, math.max(CurrentHeight, ContentContainer.AbsoluteSize.Y))
		local OffsetUpdateY = 0

		-- Handle scrolling stuff.
		if not Scroller:IsScrolling() then
			if WasAtBottom then -- If we're at the bottom, autoincrement.
				local Time = DoNotAnimate and 0 or 0.05
				Scroller:ScrollToBottom(Time)

				if not DoNotAnimate and DataBuffer[1] then -- Recently added item, consider we're scrolling to the bottom.
					OffsetUpdateY = -(ContentContainer.AbsolutePosition.Y + ContentContainer.AbsoluteSize.Y) + ContentFrame.AbsolutePosition.Y + ContentFrame.AbsoluteSize.Y
				end
			elseif FeedPositionDeltaY ~= 0 then 
				Scroller:ScrollTo(Scroller.Offset - FeedPositionDeltaY, 0)
			end
		end

		UpdateSeenCountOffset(0, OffsetUpdateY)
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

	local CountingScrolls = false
	RenderMaid.ScrollStarted = Scroller.ScrollStart:connect(function(LastOffset)
		local StartTime = tick() -- For debugging.

		if not CountingScrolls then
			CountingScrolls = true

			local function UpdateScrollingDown(Delta)
				UpdateSeenCountOffset(-Delta, 0)
			end

			local function UpdateScrollingUp(Delta)
				UpdateSeenCountOffset(0, -Delta)
			end

			while Scroller.Active and (Scroller:IsScrolling() or Scroller:IsAutoScrolling()) do
				local Offset = Scroller.Offset
				local Delta = Scroller.Offset - LastOffset
				if Delta > 10 then -- Scrolling down. Top of window trails. 

					LastOffset = Scroller.Offset
					UpdateScrollingDown(Delta)
				elseif Delta < -10 then -- Scrolling up. Bottom of window trails.
					LastOffset = Scroller.Offset
					UpdateScrollingUp(Delta)
				end
				wait(0.05)
			end

			--- Finish up.
			local Delta = Scroller.Offset - LastOffset
			if Delta > 0 then
				UpdateScrollingDown(Delta)
			else
				UpdateScrollingUp(Delta)
			end

			CountingScrolls = false
		end
	end)

	RenderMaid.NotificationBottomGuiMouseButton1Click = NotifierBottom.Gui.MouseButton1Click:connect(function()
		local DataBuffer = Buffer:GetData()

		for Index = #DataBuffer, 1, -1 do
			local Item = DataBuffer[Index]
			
			if not Item.Seen then -- Scroll to the first unseen item.
				Scroller:ScrollToChild(Item.Gui, -10)
				break;
			end
		end
	end)

	RenderMaid.NotificationTopGuiMouseButton1Click = NotifierTop.Gui.MouseButton1Click:connect(function()
		local DataBuffer = Buffer:GetData()

		for Index = 1, #DataBuffer do
			local Item = DataBuffer[Index]
			
			if not Item.Seen then -- Scroll to the first unseen item.
				Scroller:ScrollToChild(Item.Gui, -10)
				break
			end
		end
	end)

	function OutputStreamRender:Destroy()
		RenderMaid:DoCleaning()
		Scroller:Destroy()

		local DataBuffer = Buffer:GetData()
		for _, Item in pairs(DataBuffer) do
			Item.Gui:Destroy()
		end
		DataBuffer = nil;

		MainFrame:Destroy() -- Recursively calls Destroy on children, should be set. 

		OutputStreamRender.Destroy = nil
	end
end)

local MakeOutputStreamInterface = Class(function(OutputStreamInterface, Configuration, ScreenGui)
	-- Creates an interactive interface that allows for multiple incoming channels, et cetera. 

	local Configuration = OverriddenConfiguration.New(Configuration, DefaultConfiguration)
	local Subscribed = {} -- Maintain list of subscribed units. 

	local MainFrame do
		local SizeIfPhone = UDim2.new(0, 280 + Configuration.TitleWidth + Configuration.ScrollbarWidth, 0, PseudoChatSettings.LinesShown * PseudoChatSettings.LineHeight) 
		local SizeNormal  = UDim2.new(0, 500 + Configuration.TitleWidth + Configuration.ScrollbarWidth, 0, PseudoChatSettings.LinesShown * PseudoChatSettings.LineHeight);

		MainFrame = Make("Frame", {
			Active                 = false;
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 1.0;
			BorderSizePixel        = 0;
			Name                   = "OutputStreamInterface";
			Parent                 = ScreenGui;
			Size                   = qGUI.IsPhone(ScreenGui) and SizeIfPhone or SizeNormal; -- Some really horrible calculatinzsdf
			ZIndex                 = Configuration.MenuZIndex - 1;
			ClipsDescendants       = true;
			Position               = UDim2.new(0, 4, 0, 4);
		})
		OutputStreamInterface.Gui = MainFrame
	end

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

	local ActiveSubscriber
	local Menu      = MakeOutputStreamMenu(MainFrame, ScreenGui, Configuration)
	local Mouse     = Players.LocalPlayer:GetMouse()
	local MouseOver = qGUI.MouseOver(Mouse, MainFrame)

	local function DoShowInterface()
		if MouseOver then --qGUI.MouseOver(Mouse, MainFrame) then
			return true
		elseif Menu.GetIsCollapsed() then
			return true
		elseif ActiveSubscriber then
			return ActiveSubscriber.RenderFrame.DoShowInterface()
		else
			return false
		end
	end

	local function UpdateVisibility(DoNotAnimate)
		if DoShowInterface() then
			Menu.Show(DoNotAnimate and nil or Configuration.MenuAnimateTime)

			if UserInputService.MouseEnabled then
				if DoNotAnimate then
					MainFrame.BackgroundTransparency = Configuration.UIBackgroundTransparencyOnMouseOver
				else
					qGUI.TweenTransparency(MainFrame, {BackgroundTransparency = Configuration.UIBackgroundTransparencyOnMouseOver}, Configuration.MenuAnimateTime, true)
				end
			end

			for _, Item in pairs(Subscribed) do
				if ActiveSubscriber == Item and not DoNotAnimate then
					Item.RenderFrame.ShowScrollBar(Configuration.MenuAnimateTime)
				else
					Item.RenderFrame.ShowScrollBar(0)
				end
			end
		else
			Menu.Hide(DoNotAnimate and nil or Configuration.MenuAnimateTime)

			if UserInputService.MouseEnabled then
				if DoNotAnimate then
					MainFrame.BackgroundTransparency = 1
				else
					qGUI.TweenTransparency(MainFrame, {BackgroundTransparency = 1}, Configuration.MenuAnimateTime, true)
				end
			end

			for _, Item in pairs(Subscribed) do
				if ActiveSubscriber == Item and not DoNotAnimate then
					Item.RenderFrame.HideScrollBar(Configuration.MenuAnimateTime)
				else
					Item.RenderFrame.HideScrollBar(0)
				end
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


		if ScrollerEvent then
			ScrollerEvent:disconnect()
			ScrollerEvent = nil
		end

		if Subscriber then
			Subscriber.Show(DoNotAnimate)
			UpdateVisibility(DoNotAnimate)
			
			ScrollerEvent = Subscriber.RenderFrame.Scroller.ScrollEnd:connect(function()
				UpdateVisibility()
			end)
		else
			print("Set no active subscriber!")
		end
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

			local SubscriberMaid = Maid.MakeMaid()

			local RenderFrame      = MakeOutputStreamRender(Configuration, ScreenGui, RenderColor)
			local MenuOption       = Menu.MakeChoice(RenderName, RenderColor, 1)
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

					local LastData = BufferData[Index] and BufferData[Index].Data or nil
					-- Sends the parent, the data, DoNotAnimate, and the last data set (Which may be nil.)
					local Gui    = OutputClass.Render(ActiveSubscriber.RenderFrame.ContentFrame, Data, DoNotAnimate or (Index == RenderFrame.Buffer.BufferSize), LastData)
					Gui.Parent   = RenderFrame.ContentFrame
					NewItem.Gui  = Gui
					NewItem.Data = Data

					-- print("DoNotAnimate: " .. DoNotAnimate)
					RenderFrame.Insert(Index, NewItem, DoNotAnimate)
				else
					print("[OutputStreamInterface] - Will not insert new item old time stamp @ " .. tostring(TimeStamp))
				end
			end

			function Subscriber.Show(DoNotAnimate)
				RenderFrame.Gui.Visible = true
				Menu.SetColorAndTitle(RenderColor, RenderName, DoNotAnimate)
			end

			function Subscriber.Hide(DoNotAnimate)
				RenderFrame.Gui.Visible = false
			end

			-- Connect Events --

			SubscriberMaid.NewItem = OutputStreamSyndicator.NewItem:connect(function(OutputStreamClient, OutputClass, Data)
				assert(Data ~= nil, "Data is nil")
				HandleNewItem(OutputClass, Data, ActiveSubscriber ~= Subscriber)
			end)

			SubscriberMaid.MenuOptionButtonClick = MenuOption.ChoiceSelected:connect(function()
				SetActiveStream(Subscriber)
				Menu.Collapse()
			end)

			-- Setup Subscription, GUI stuff --

			RenderFrame.Gui.Parent = ContentContainer

			function Subscriber:Destroy()
				--- GCs itself

				Subscribed[OutputStreamSyndicator] = nil

				-- Set the active subscriber to something not us. 
				for AOutputStreamSyndicator, ASubscriber in pairs(Subscribed) do
					SetActiveStream(ASubscriber)
					break;
				end

				SubscriberMaid:DoCleaning()
				SubscriberMaid = nil

				MenuOption:Destroy()
				MenuOption = nil

				RenderFrame:Destroy()
				RenderFrame = nil

				Subscriber.Destroy = nil
				Subscriber = nil
			end

			Subscribed[OutputStreamSyndicator] = Subscriber
			if not ActiveSubscriber then
				SetActiveStream(Subscriber, true)
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

	local CancelButton = Menu.MakeChoice("Cancel", Color3.new(0.1, 0.1, 0.1), 2)
	CancelButton.ChoiceSelected:connect(function()
		Menu.Collapse()
	end)

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