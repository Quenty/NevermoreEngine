local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")

local NevermoreEngine    = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary  = NevermoreEngine.LoadLibrary

local qSystems           = LoadCustomLibrary("qSystems")
local qString            = LoadCustomLibrary("qString")
local PseudoChatSettings = LoadCustomLibrary("PseudoChatSettings")
local qColor3            = LoadCustomLibrary("qColor3")
local qMath              = LoadCustomLibrary("qMath")
local qGUI               = LoadCustomLibrary("qGUI")
local OutputStream       = LoadCustomLibrary("OutputStream")

local RbxUtility         = LoadLibrary("RbxUtility")

qSystems:Import(getfenv(0));

local lib = {}

-- @author Quenty
-- This script handles parsing and rendering of specific pseudo chat stuff,
-- to be used with OutputStream
-- Last Modified January 26th, 2014

local GetPlayerNameColorRaw do 
	local PlayerColours = {
		BrickColor.new("Bright red"),
		BrickColor.new("Bright blue"),
		BrickColor.new("Earth green"),
		BrickColor.new("Bright violet"),
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

local function GetPlayerFromName(PlayerName)
	--- Get's a player from their username.
	-- @param PlayerName THe name of the player
	-- @return The player, if they are in-game.

	local Player = Players:FindFirstChild(PlayerName)
	if Player and Player:IsA("Player") then
		return Player
	else
		return nil
	end
end
lib.GetPlayerFromName = GetPlayerFromName
lib.getPlayerFromName = GetPlayerFromName

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

	local Player = GetPlayerFromName(Name)

	if PseudoChatSettings.SpecialNameColors[Name] then
		return PseudoChatSettings.SpecialNameColors[Name]
	else
		if not Player or Player.Neutral then
			return GetPlayerNameColorRaw(Name)
		else
			return Player.TeamColor.Color
		end
	end
end
lib.GetPlayerNameColor = GetPlayerNameColor
lib.getPlayerNameColor = GetPlayerNameColor

local CachedSpaceStringList = {}

local function ComputeSpaceString(Label, PlayerLabel)
	--- Given a name, return the spaces required to push a text wrapped thing out of the way. Tricky Sorcus. Tricky. 
	-- @param Label The label to test upon, probably the message label.
	-- @param PlayerLabel The label representing the Player's name.

	local newString = " "
	
	Label.Text = newString

	while Label.TextBounds.X < PlayerLabel.TextBounds.X do
		print(Label.TextBounds.X .. " < " .. PlayerLabel.TextBounds.X)
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
		end
	end)
end
local ChatParser, ChatRender, ChatOutputClass do -- Chat parsing
	function ChatRender(Parent, Data, DoNotAnimate)
		--- Renders a frame, and returns it
		-- @param Data The data is sent from the below parser, to the client
		--[[ The following expected
			Message 'String' The message to be displayed.
			PlayerColor 'Color3' The Color3 value, in JSON, of the Player's name.
			ClassName 'String' The class of the chat. Automatically added.
			ChatColor 'Color3' The Color3 value
		--]]
		-- @return Gui Frame, resized correctly for the parent. 

		local PlayerChatFrame = Make 'Frame' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Parent                 = Parent;
			Size                   = UDim2.new(1, 0, 1, 0);
			Visible                = true;
			Name                   = Data.ClassName;
		}

		local PlayerLabel = Make 'TextLabel' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			FontSize               = PseudoChatSettings.ChatFontSize;
			Name                   = "ChatNameLabel";
			Parent                 = PlayerChatFrame; -- For text bounds, reassigned later. 
			Position               = UDim2.new(0, PseudoChatSettings.LabelOffsetX, 0, 0);
			Size                   = UDim2.new(1, -PseudoChatSettings.LabelOffsetX, 1, 0);
			Text                   = Data.PlayerName..":";
			TextColor3             = Data.PlayerColor;
			TextStrokeColor3       = Color3.new(0.5, 0.5, 0.5);
			TextStrokeTransparency = 1;
			TextTransparency       = 0;
			TextWrapped            = false;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = Parent.ZIndex;	
		}

		local MessageLabel = Make 'TextLabel' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0.0;
			FontSize               = PseudoChatSettings.ChatFontSize;
			Name                   = "Message";
			Parent                 = PlayerChatFrame;
			Position               = UDim2.new(0, PseudoChatSettings.LabelOffsetX, 0, 0);
			Size                   = UDim2.new(1, -PseudoChatSettings.LabelOffsetX, 1, 0);
			TextColor3             = Data.ChatColor;
			TextStrokeColor3       = Color3.new(0, 0, 0);
			TextWrapped            = true;
			TextStrokeTransparency = Data.MessageLabelTextStrokeTransparency;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = Parent.ZIndex;
		}

		-- Set Message's Text --
		local MessageSpacer = GetSpaceString(MessageLabel, PlayerLabel)
		MessageLabel.Text   = MessageSpacer .. PseudoChatSettings.ContentFailed
		MessageLabel.Text   = MessageSpacer .. Data.Message

		local Height = qMath.RoundUp(MessageLabel.TextBounds.Y, PseudoChatSettings.LineHeight)
		PlayerChatFrame.Size = UDim2.new(1, 0, 0, Height)

		if DoNotAnimate then
			
		else
			GenericTextFadeIn(PlayerChatFrame, 0.5)
		end
		return PlayerChatFrame
	end

	ChatParser = OutputStream.MakeOutputParser(function(Data)
		--- Constructs a new "data" field to be sent, as well as fills in Data.

		local Parsed = {}

		Data.Message     = qString.TrimString(Data.Message and tostring(Data.Message) or "[ No Message Provided ]")
		Data.PlayerName  = Data.PlayerName or "NoPlayerName";
		Data.PlayerColor = Data.PlayerColor or GetPlayerNameColor(Data.PlayerName)
		Data.ChatColor   = Data.ChatColor or GetPlayerChatColor(Data.PlayerName)
		Data.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency or 0.8

		Parsed.Message     = Data.Message
		Parsed.PlayerName  = Data.PlayerName
		Parsed.PlayerColor = qColor3.Encode(Data.PlayerColor)
		Parsed.ChatColor   = qColor3.Encode(Data.ChatColor)		
		Parsed.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency

		-- print(Parsed.PlayerColor)
		-- print(Parsed.ChatColor)

		return Parsed
	end, function(Data)
		--- Decodes JSON (unparses) it.
		-- @return Table, if unparsed successfully, otherwise, nil

		-- print(Data.PlayerColor)
		-- print(Data.ChatColor)

		local DecodedChatColor = qColor3.Decode(Data.ChatColor)
		if DecodedChatColor then
			Data.ChatColor = DecodedChatColor
		else
			Warn("[OutputParser] - Unable to parse Notifications's ChatColor in data")
		end

		local DecodedPlayerColor = qColor3.Decode(Data.PlayerColor)
		if DecodedPlayerColor then
			Data.PlayerColor = DecodedPlayerColor
		else
			Warn("[OutputParser] - Unable to parse Notifications's PlayerColor in data")
		end

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

		local NotificationChatFrame = Make 'Frame' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Parent                 = Parent;
			Size                   = UDim2.new(1, 0, 1, 0);
			Visible                = true;
			Name                   = Data.ClassName;
		}

		local MessageLabel = Make 'TextLabel' {
			BackgroundTransparency = 1;
			BorderSizePixel        = 0.0;
			FontSize               = PseudoChatSettings.ChatFontSize;
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
		}
		MessageLabel.Text = tostring(Data.Message)

		local Height = qMath.RoundUp(MessageLabel.TextBounds.Y, PseudoChatSettings.LineHeight)
		NotificationChatFrame.Size = UDim2.new(1, -PseudoChatSettings.LabelOffsetXOutput, 0, Height)

		return NotificationChatFrame
	end

	OutputParser = OutputStream.MakeOutputParser(function(Data)
		--- Constructs a new "data" field to be sent.
		-- @param Message The chat the player said
		-- @param ChatColor The ChatColor to render at

		local Parsed = {}

		Data.Message     = qString.TrimString(Data.Message and tostring(Data.Message) or "[ No Message Provided ]")
		Data.ChatColor   = Data.ChatColor or PseudoChatSettings.DefaultNotificationColor;
		Data.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency or 0.8

		Parsed.Message     = Data.Message
		Parsed.ChatColor   = qColor3.Encode(Data.ChatColor)		
		Parsed.MessageLabelTextStrokeTransparency = Data.MessageLabelTextStrokeTransparency
		

		return Parsed
	end, function(Data)
		--- Decodes JSON (unparses) it.
		-- @param JSONData String JSON data, to be deparsed

		local DecodedChatColor = qColor3.Decode(Data.ChatColor)
		if DecodedChatColor then
			Data.ChatColor = DecodedChatColor
		else
			Warn("[OutputParser] - Unable to parse Notifications's ChatColor in data")
		end

		return Data
	end)

	OutputOutputClass = OutputStream.MakeOutputClass("OutputOutputClass", 
		OutputParser, 
		OutputRender
	);
end
lib.OutputOutputClass = OutputOutputClass

return lib