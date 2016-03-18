local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")

local NevermoreEngine    = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary  = NevermoreEngine.LoadLibrary

local qSystems           = LoadCustomLibrary("qSystems")
local qString            = LoadCustomLibrary("qString")
local PseudoChatSettings = LoadCustomLibrary("PseudoChatSettings")
local qMath              = LoadCustomLibrary("qMath")
local qGUI               = LoadCustomLibrary("qGUI")
local OutputStream       = LoadCustomLibrary("OutputStream")
local os                 = LoadCustomLibrary("os")
local qColor3            = LoadCustomLibrary("qColor3")
local qPlayer            = LoadCustomLibrary("qPlayer")

local RbxUtility         = LoadLibrary("RbxUtility")

local Make               = qSystems.Make
local CallOnChildren     = qSystems.CallOnChildren

local lib = {}

-- @author Quenty
-- This script handles parsing and rendering of specific pseudo chat stuff,
-- to be used with OutputStream
-- Last Modified November 18th, 2014

local GetPlayerNameColorRaw do 
	local PlayerColours = {
		BrickColor.new("Bright red"),
		BrickColor.new("Pastel light blue"); --BrickColor.new("Bright blue"),
		BrickColor.new("Br. yellowish green"), --BrickColor.new("Earth green"), -- Suppose to be earth green, but it looks ugly.
		BrickColor.new("Lavender"), --BrickColor.new("Bright violet"),
		BrickColor.new("Bright orange"),
		BrickColor.new("Bright yellow"),
		BrickColor.new("Light reddish violet"),
		BrickColor.new("Brick yellow"),
	}

	local function GetNameValue(Name)
		-- Returns the Player's color that their name is suppose to be.  
		-- Credit to noliCAIKS for finding this solution. He's epicale. 

		local Length = #Name
		local Value = 0
		for Index = 1, Length do
			local CharacterValue = string.byte(string.sub(Name, Index, Index))
			local ReverseIndex = Length - Index + 1
			if Length % 2 == 1 then
				ReverseIndex = ReverseIndex - 1
			end
			if ReverseIndex % 4 >= 2 then
				CharacterValue = -CharacterValue
			end
			Value = Value + CharacterValue
		end
		return Value % 8
	end

	function GetPlayerNameColorRaw(Name)
		return PlayerColours[GetNameValue(Name) + 1]
	end
end
lib.GetPlayerNameColorRaw = GetPlayerNameColorRaw
lib.getPlayerNameColorRaw = GetPlayerNameColorRaw

local function IsRobloxAdmin(Name)
	--- Finds out if a player is a ROBLOX admin
	-- @param Name The name of the player to check for
	-- @return Boolean if the player is a ROBLOX admin or not.

	Name = Name:lower()
	for _, Admin in pairs(PseudoChatSettings.ROBLOXAdminList) do
		if Admin:lower() == Name then
			return true
		end
	end
	return false
end
lib.IsRobloxAdmin = IsRobloxAdmin
lib.isRobloxAdmin = IsRobloxAdmin

local function GetPlayerChatColor(Name)
	--- Return's a player's chat color
	-- @param Name THe name of the player

	if PseudoChatSettings.SpecialChatColors[Name] then
		return PseudoChatSettings.SpecialChatColors[Name]
	elseif IsRobloxAdmin(Name) then
		return PseudoChatSettings.RobloxAdminChatColor
	else
		return PseudoChatSettings.DefaultChatColor
	end
end
lib.GetPlayerChatColor = GetPlayerChatColor
lib.getPlayerChatColor = GetPlayerChatColor

local function GetPlayerNameColor(Name)
	--- Return's a player's name color.
	-- Priorities predefined, and then their TeamColor, and then finally the hashed name.
	-- @param Name THe name of the player
	-- @return Color3 value of what to color their name.

	local Player = qPlayer.GetPlayerFromName(Name)

	if PseudoChatSettings.SpecialNameColors[Name] then
		return PseudoChatSettings.SpecialNameColors[Name]
	else
		if not Player or Player.Neutral then
			return qColor3.AdjustColorTowardsWhite(GetPlayerNameColorRaw(Name).Color)
		else
			return qColor3.AdjustColorTowardsWhite(Player.TeamColor.Color)
		end
	end
end
lib.GetPlayerNameColor = GetPlayerNameColor
lib.getPlayerNameColor = GetPlayerNameColor

local CachedSpaceStringList = {} -- It's worth it to cache this data. Eventual memory leak, but not for a long long time. 

local function ComputeSpaceString(Label, PlayerLabel)
	--- Given a name, return the spaces required to push a text wrapped thing out of the way. Tricky Sorcus. Tricky. 
	-- @param Label The label to test upon, probably the message label.
	-- @param PlayerLabel The label representing the Player's name.

	local newString = " "
	
	Label.Text = newString

	while Label.TextBounds.X < PlayerLabel.TextBounds.X do
		-- print(Label.TextBounds.X .. " < " .. PlayerLabel.TextBounds.X)
		newString = newString .. " "
		Label.Text = newString;
	end
	newString = newString .. " "
	CachedSpaceStringList[PlayerLabel.Text] = newString
	Label.Text = ""

	return newString
end
lib.ComputeSpaceString = ComputeSpaceString
lib.computeSpaceString = ComputeSpaceString

local function GetSpaceString(Label, PlayerLabel)
	--- Get's the cached version of the space string, or return's a new one. Since we're caching, the size of the text can't change halfway
	--  through.
	-- @param Label The label to test upon, probably the message label.
	-- @param PlayerLabel The label representing the Player's name.

	return CachedSpaceStringList[PlayerLabel.Text] or ComputeSpaceString(Label, PlayerLabel)
end
lib.GetSpaceString = GetSpaceString
lib.getSpaceString = GetSpaceString

local function GenericTextFadeIn(Gui, Time)
	--- Transitions text labels to fade in. Recurses on children. 

	CallOnChildren(Gui, function(Child)
		if Child:IsA("TextLabel") or Child:IsA("TextButton") or Child:IsA("TextBox") then
			local CurrentTextTransparency = Child.TextTransparency
			local CurrentStrokeTransparency = Child.TextStrokeTransparency
			Child.TextTransparency        = 1;
			Child.TextStrokeTransparency  = 1;

			qGUI.TweenTransparency(Child, {
				TextTransparency       = CurrentTextTransparency;
				TextStrokeTransparency = CurrentStrokeTransparency;
			}, Time, true)
		elseif Child:IsA("ImageLabel") or Child:IsA("ImageButton") then
			local CurrentImageTransparency = Child.ImageTransparency
			Child.ImageTransparency = 1;

			qGUI.TweenTransparency(Child, {
				ImageTransparency      = CurrentImageTransparency;
			}, Time, true)
		end
	end)
end

local function GenericTextFadeOut(Gui, Time)
	--- Trasitions text labels to fade out. Recurses on children. 

	CallOnChildren(Gui, function(Child)
		if Child:IsA("TextLabel") or Child:IsA("TextButton") or Child:IsA("TextBox") then
			qGUI.TweenTransparency(Child, {
				TextTransparency       = 1;
				TextStrokeTransparency = 1;
			}, Time, true)
		elseif Child:IsA("ImageLabel") or Child:IsA("ImageButton") then
			qGUI.TweenTransparency(Child, {
				ImageTransparency      = 1;
			}, Time, true)
		end
	end)
end

local ChatParser, ChatRender, ChatOutputClass do -- Chat parsing

	local function ShouldDisplayNameTag(Data, LastData)
		if LastData and LastData.ClassName == Data.ClassName and LastData.PlayerName == Data.PlayerName then
			if not LastData.ClientData.ContinuedMessageLevel or LastData.ClientData.ContinuedMessageLevel < (PseudoChatSettings.LinesShown - 1) then
				if LastData.PlayerColor == Data.PlayerColor then
					return false
				end
			end
		end

		return true
	end

	function ChatRender(Parent, Data, DoNotAnimate, LastData)
		local RenderFrame = Make("Frame", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Parent                 = Parent;
			Size                   = UDim2.new(1, 0, 0, math.ceil(PseudoChatSettings.LinesShown/2) * PseudoChatSettings.LineHeight); -- Y is only 0.5, to limit lines to half the screen. Super hacky. 
			Visible                = true;
			Name                   = Data.ClassName;
			ZIndex                 = Parent.ZIndex;	
		})

		local PlayerDotColor
		local ContinuedMessage = true -- Presume we are continuing a spam rampage
		if ShouldDisplayNameTag(Data, LastData) then
			--- When we have a new message by a new player, indicate with dot. However, after PseudoChatSettings.LinesShown - 1, we won't continue our message chain. 
			-- Yes, this uh, argument thing is cringey. I'm sorry mother!

			PlayerDotColor = Make("ImageLabel", {
				Name                   = "PlayerDot";
				Parent                 = RenderFrame;
				Size                   = UDim2.new(0, 14, 0, 14);
				BackgroundTransparency = 1;
				Position               = UDim2.new(0, 18, 0, 4);
				BorderSizePixel        = 0; 
				Image                  = "rbxasset://textures/ui/chat_teamButton.png";
				ImageTransparency      = 0;
				ImageColor3            = Data.PlayerColor;
				ZIndex                 = Parent.ZIndex;
			});

			ContinuedMessage = false
		else
			-- We know we're operrating only in the ChatRender class...
			LastData.ClientData.ContinuedMessageLevel = LastData.ClientData.ContinuedMessageLevel or 1 
			Data.ClientData.ContinuedMessageLevel     = LastData.ClientData.ContinuedMessageLevel + 1
			-- print("Set @ ", Data.ClientData.ContinuedMessageLevel)
		end


		local PlayerLabel = Make("TextLabel", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = Data.PlayerName .. "Label";
			Parent                 = RenderFrame; -- For text bounds, reassigned later. 
			Position               = UDim2.new(0, 38, 0, 0);
			Size                   = UDim2.new(1, -38, 1, 0);
			Text                   = Data.PlayerName..": ";
			TextColor3             = Data.PlayerColor; --Data.ChatColor;
			TextStrokeColor3       = Color3.new(0, 0, 0);--Color3.new(0, 0, 0);
			TextStrokeTransparency = 0.87; --0.8;
			TextTransparency       = 0;
			TextWrapped            = true;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = Parent.ZIndex;	
			Font                   = "SourceSans";
			FontSize               = "Size18"
		})

		local MessageLabel = Make("TextLabel", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = Data.PlayerName .. "MessageLabel - " .. Data.Message;
			Parent                 = RenderFrame; -- For text bounds, reassigned later. 
			Position               = UDim2.new(0, 38, 0, 0);
			Size                   = UDim2.new(1, -38, 1, 0);
			-- Text                   = PseudoChatSettings.ContentFailed;
			TextColor3             = Data.ChatColor;
			TextStrokeColor3       = Color3.new(0, 0, 0);
			TextStrokeTransparency = 0.8;
			TextTransparency       = 0;
			TextWrapped            = true;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = Parent.ZIndex;
			Font                   = "SourceSans";
			FontSize               = "Size18"
		})

		MessageLabel.Position = UDim2.new(0, PlayerLabel.Position.X.Offset + PlayerLabel.TextBounds.X, 0, 0)
		MessageLabel.Size = UDim2.new(1, -(PlayerLabel.Position.X.Offset + PlayerLabel.TextBounds.X), 1, 0)

		MessageLabel.Text = Data.Message

		if ContinuedMessage then
			PlayerLabel:Destroy()
		end

		local Height = qMath.RoundUp(MessageLabel.TextBounds.Y, PseudoChatSettings.LineHeight)
		RenderFrame.Size = UDim2.new(1, 0, 0, Height)


		if DoNotAnimate then
			
		else
			if PlayerDotColor then
				local OldPosition          = PlayerDotColor.Position
				local OldColor             = PlayerDotColor.ImageColor3
				PlayerDotColor.Position    = UDim2.new(0, -18, 0, 4)
				PlayerDotColor.ImageColor3 = Color3.new(1, 1, 1);

				qGUI.ResponsiveCircleClickEffect(PlayerDotColor, nil, nil, 0.5, true)

				PlayerDotColor:TweenPosition(OldPosition, "Out", "Quad", 0.15, true)
				qGUI.TweenColor3(PlayerDotColor, {ImageColor3 = OldColor}, 0.15, true)
			end

			GenericTextFadeIn(RenderFrame, 0.15)
		end

		return RenderFrame
	end


	ChatParser = OutputStream.MakeOutputParser(function(Data)
		--- Constructs a new "data" field to be sent, as well as fills in Data.

		local Parsed = {}

		Data.Message                            = Data.Message and tostring(Data.Message) or "[ No Message Provided ]"
		Data.PlayerName                         = Data.PlayerName or "NoPlayerName";
		Data.PlayerColor                        = Data.PlayerColor or GetPlayerNameColor(Data.PlayerName)
		Data.ChatColor                          = Data.ChatColor or GetPlayerChatColor(Data.PlayerName)
		Data.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency or 0.8

		Parsed.Message     = Data.Message
		Parsed.PlayerName  = Data.PlayerName
		Parsed.PlayerColor = Data.PlayerColor
		Parsed.ChatColor   = Data.ChatColor

		Parsed.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency

		return Parsed
	end, function(Data)

		-- print(LoadCustomLibrary("Type").getType(Data.PlayerColor))
		return Data
	end)

	ChatOutputClass = OutputStream.MakeOutputClass("ChatOutputClass", 
		ChatParser, 
		ChatRender
	);
end
lib.ChatOutputClass = ChatOutputClass

local OutputParser, OutputRender, OutputOutputClass do -- Output parsing
	function OutputRender(Parent, Data, DoNotAnimate)
		--- Renders a new "Output" from the Data given.
		-- @param Data The data given. 

		local NotificationChatFrame = Make("Frame", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Parent                 = Parent;
			Size                   = UDim2.new(1, 0, 0, 60000); -- If textBounds > 65535 (16 bits), then we go negative. 
			Visible                = true;
			Name                   = Data.ClassName;
		})

		local MessageLabel = Make("TextLabel", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0.0;
			Font                   = "SourceSans";
			FontSize               = "Size18";
			Name                   = "Message";
			Parent                 = NotificationChatFrame;
			Position               = UDim2.new(0, PseudoChatSettings.LabelOffsetXOutput, 0, 0);
			Size                   = UDim2.new(1, -PseudoChatSettings.LabelOffsetXOutput, 1, 0);
			TextColor3             = Data.ChatColor;
			Text                   = PseudoChatSettings.ContentFailed;
			TextStrokeColor3       = Color3.new(0, 0, 0);
			TextWrapped            = true;
			TextStrokeTransparency = Data.MessageLabelTextStrokeTransparency;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = Parent.ZIndex;
		})
		MessageLabel.Text = tostring(Data.Message)

		-- if MessageLabel.TextBounds.Y == 18 then
		-- 	print("MessageLabel.TextBounds.Y: " .. MessageLabel.TextBounds.Y)
		-- 	print("MessageLabel.TextBounds.X: " .. MessageLabel.TextBounds.X)
		-- 	print("MessageLabel.AbsoluteSize.Y: " .. MessageLabel.AbsoluteSize.Y)
		-- 	wait()
		-- 	print("MessageLabel.TextBounds.Y: " .. MessageLabel.TextBounds.Y)
		-- 	print("MessageLabel.TextBounds.X: " .. MessageLabel.TextBounds.X)
		-- 	print("MessageLabel.AbsoluteSize.Y: " .. MessageLabel.AbsoluteSize.Y)
		-- end

		local Height = qMath.RoundUp(MessageLabel.TextBounds.Y, PseudoChatSettings.LineHeight)
		NotificationChatFrame.Size = UDim2.new(1, 0, 0, Height)

		return NotificationChatFrame
	end

	OutputParser = OutputStream.MakeOutputParser(function(Data)
		--- Constructs a new "data" field to be sent.
		-- @param Message The chat the player said
		-- @param ChatColor The ChatColor to render at

		local Parsed = {}

		Data.Message                            = Data.Message and tostring(Data.Message) or "[ No Message Provided ]"
		Data.ChatColor                          = Data.ChatColor or PseudoChatSettings.DefaultNotificationColor;
		Data.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency or 0.8

		Parsed.Message                            = Data.Message
		Parsed.ChatColor                          = Data.ChatColor
		Parsed.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency
		

		return Parsed
	end, function(Data)
		return Data
	end)

	OutputOutputClass = OutputStream.MakeOutputClass("OutputOutputClass", 
		OutputParser, 
		OutputRender
	);
end
lib.OutputOutputClass = OutputOutputClass

do
	local function OutputRender(Parent, Data, DoNotAnimate)
		--- Renders a new "Output" from the Data given.
		-- @param Data The data given. 
		local RenderFrame = Make("Frame", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Parent                 = Parent;
			Size                   = UDim2.new(1, 0, 0, 60000); -- 65k is the limit, before we go negative.
			Visible                = true;
			Name                   = Data.ClassName;
			ZIndex                 = Parent.ZIndex;	
		})

		local CommandDot = Make("ImageLabel", {
			Name                   = "CommandDot";
			Parent                 = RenderFrame;
			Size                   = UDim2.new(0, 14, 0, 14);
			BackgroundTransparency = 1;
			Position               = UDim2.new(0, 18, 0, 4);
			BorderSizePixel        = 0; 
			Image                  = "rbxassetid://176695944";
			ImageTransparency      = 0;
			ImageColor3            = Data.CommandColor;
			ZIndex                 = Parent.ZIndex;
		});

		local UserLabel = Make("TextLabel", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = Data.PlayerExecutingName .. "Label";
			Parent                 = RenderFrame; -- For text bounds, reassigned later. 
			Position               = UDim2.new(0, 38, 0, 0);
			Size                   = UDim2.new(1, -38, 0, 0);
			Text                   = Data.CommandName:upper() .. "  ";
			TextColor3             = Data.CommandColor;--Color3.new(1, 1, 1);
			TextStrokeColor3       = Color3.new(0, 0, 0);
			TextStrokeTransparency = 0.87; --0.8;
			TextTransparency       = 0;
			TextWrapped            = true;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = Parent.ZIndex;	
			Font                   = "SourceSans";
			FontSize               = "Size18"
		})
		UserLabel.Size = UDim2.new(0, UserLabel.TextBounds.X, 1, 0)

		--[[
		local Backing = Make("Frame", {
			Parent                 = UserLabel;
			ZIndex                 = Parent.ZIndex;
			BackgroundTransparency = 0;
			BackgroundColor3       = Data.CommandColor;
			Size                   = UDim2.new(1, 6, 1, 0);
			Position               = UDim2.new(0, -3, 0, 0);
			BorderSizePixel        = 0;
			Name                   = "Backing";
		})--]]
		-- qGUI.BackWithRoundedRectangle(Backing, 5, Data.CommandColor)

		local MessageLabel = Make("TextLabel", {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = Data.PlayerExecutingName .. "MessageLabel - " .. Data.CommandDescription;
			Parent                 = RenderFrame; -- For text bounds, reassigned later. 
			Position               = UDim2.new(0, 38, 0, 0);
			Size                   = UDim2.new(1, -38, 1, 0);
			-- Text                   = PseudoChatSettings.ContentFailed;
			TextColor3             = Color3.new(1, 1, 1);
			TextStrokeColor3       = Color3.new(0, 0, 0);
			TextStrokeTransparency = 0.8;
			TextTransparency       = 0;
			TextWrapped            = true;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = Parent.ZIndex;
			Font                   = "SourceSans";
			FontSize               = "Size18"
		})

		MessageLabel.Position = UDim2.new(0, UserLabel.Position.X.Offset + UserLabel.TextBounds.X, 0, 0)
		MessageLabel.Size = UDim2.new(1, -(UserLabel.Position.X.Offset + UserLabel.TextBounds.X), 1, 0)

		MessageLabel.Text = os.date("[%I:%M %_p] ") .. Data.PlayerExecutingName .. ": " .. Data.CommandDescription

		local Height = qMath.RoundUp(MessageLabel.TextBounds.Y, PseudoChatSettings.LineHeight)
		RenderFrame.Size = UDim2.new(1, 0, 0, Height)

		if DoNotAnimate then
			
		else
			if CommandDot then
				local OldPosition          = CommandDot.Position
				local OldColor             = CommandDot.ImageColor3
				CommandDot.Position    = UDim2.new(0, -18, 0, 4)
				CommandDot.ImageColor3 = Color3.new(1, 1, 1);

				qGUI.ResponsiveCircleClickEffect(CommandDot, nil, nil, 0.5, true)

				CommandDot:TweenPosition(OldPosition, "Out", "Quad", 0.15, true)
				qGUI.TweenColor3(CommandDot, {ImageColor3 = OldColor}, 0.15, true)
			end

			GenericTextFadeIn(RenderFrame, 0.15)
		end

		return RenderFrame
	end

	local OutputParser = OutputStream.MakeOutputParser(function(Data)
		--- Constructs a new "data" field to be sent.

		local Parsed = {}

		Data.CommandName         = Data.CommandName or "Unknown";
		Data.CommandDescription  = Data.CommandDescription and tostring(Data.CommandDescription) or "[ No Message Provided ]"
		Data.PlayerExecutingName = Data.PlayerExecutingName or "[ Unknown ]"
		Data.CommandColor        = Data.CommandColor or GetPlayerNameColor(Data.CommandName);

		Parsed.CommandName         = Data.CommandName
		Parsed.CommandDescription  = Data.CommandDescription
		Parsed.CommandColor        = Data.CommandColor
		Parsed.PlayerExecutingName = Data.PlayerExecutingName

		return Parsed
	end, function(Data)
		return Data
	end)

	AdminLogOutputClass = OutputStream.MakeOutputClass("AdminLogOutputClass", 
		OutputParser, 
		OutputRender
	);
end
lib.AdminLogOutputClass = AdminLogOutputClass


return lib
