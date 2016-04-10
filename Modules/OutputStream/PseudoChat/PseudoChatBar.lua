local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local Maid              = LoadCustomLibrary("Maid")
local qString           = LoadCustomLibrary("qString")
local qGUI              = LoadCustomLibrary("qGUI")
local Signal            = LoadCustomLibrary("Signal")

local Make              = qSystems.Make
local Class             = qSystems.Class

-- PseudoChatBar.lua
-- @author Quenty
-- Last modified November 17th, 2014

local MakePseudoChatBar = Class(function(PseudoChatBar, ScreenGui, Parent)
	--- Creates a new pseudo chat bar for chatting

	local IsPhone = qGUI.IsPhone(ScreenGui)
	Parent = Parent or ScreenGui

	local Configuration = {
		DefaultText          = IsPhone and "Tap here to chat" or "Push \"/\" to chat";
		XOffset              = 10; --38 -- 38 is the alignment w/ the chat.;
		ZIndex               = 10;
		DefaultTransparency  = 1;
		SelectedTransparency = 0.5;
		AnimationTime        = 0.05;
		AnimationTimeHide    = 0.3;
		DefaultHeight        = IsPhone and 18 or 26;
		RightYOffset         = 30; -- Spacing on the right.
	}

	-- if CurrentPlatformName == "IOS" or CurrentPlatformName == "Android" then
	-- 	Configuration.XOffset = 10;
	-- end

	local NewChat         = Signal.new()
	PseudoChatBar.NewChat = NewChat

	-- GENERATE GUIS 

	local ChatBarBacking = Make("Frame", {
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = Configuration.DefaultTransparency;
		BorderSizePixel        = 0;
		Name                   = "ChatBar";
		Position               = UDim2.new(0, 0, 1, -Configuration.DefaultHeight);
		Size                   = UDim2.new(1, -Configuration.RightYOffset, 0, Configuration.DefaultHeight);
		ZIndex                 = Configuration.ZIndex-1;
	})
	PseudoChatBar.Gui = ChatBarBacking

	Make("Frame", {
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 0.95;
		BorderSizePixel        = 0;
		Size                   = UDim2.new(1, 0, 0, 1);
		ZIndex                 = Configuration.ZIndex;
		Name                   = "TopBarOutline";
		Parent                 = ChatBarBacking;
	})

	local InputButton = Make("ImageButton", {
		BackgroundTransparency = 1;
		Parent                 = ChatBarBacking;
		ZIndex                 = Configuration.ZIndex;
		Size                   = UDim2.new(1, 0, 1, 0);
		BorderSizePixel        = 0;
		Name                   = "CatchClick";
	})

	local InputGui = Make("TextBox", {
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Font                   = "SourceSans";
		FontSize               = "Size18";
		Name                   = "ChatBar";
		Parent                 = ChatBarBacking;
		Position               = UDim2.new(0, Configuration.XOffset, 0, 0);
		Size                   = UDim2.new(1, -Configuration.XOffset - 10, 1, 0);
		Text                   = Configuration.DefaultText;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeTransparency = 0.9;
		TextTransparency       = 0;
		TextXAlignment         = IsPhone and "Center" or "Left";
		ZIndex                 = Configuration.ZIndex-1;
		MultiLine              = false;
		ClearTextOnFocus       = false;
	})

	local LastChat = ""
	local LastInput = "" --- Utilized for autocomplete things.
	PseudoChatBar.Focused = false
	local InputCleaner

	local function StartFocus()
		if not PseudoChatBar.Focused then
			-- print("Start focused", tick())

			PseudoChatBar.Focused = true

			InputGui.Text = ""
			game:GetService("RunService").RenderStepped:wait(0)
			-- wait()
			InputGui:CaptureFocus()
			InputGui.Text = ""

			InputCleaner = Maid.new()
			qGUI.TweenTransparency(ChatBarBacking, {BackgroundTransparency = Configuration.SelectedTransparency}, Configuration.AnimationTime, true)

			--[[
			if not UserInputService.KeyboardEnabled then
				-- http://stackoverflow.com/questions/1419221/what-is-the-iphones-default-keyboard-animation-rate

				-- Dang it ROBLOX, I have to hardcode. Poor japanese people. 
				ChatBarBacking:TweenPosition(UDim2.new(0, 0, 0.5, -Configuration.DefaultHeight - 30), "Out", "Quad", 0.3, true)
			end--]]
		end
	end

	local function RespondOnInput()
		local XPosition = InputGui.AbsolutePosition.X + InputGui.TextBounds.X
		local YPosition = InputGui.AbsolutePosition.Y + InputGui.AbsoluteSize.Y/2

		qGUI.ResponsiveCircleClickEffect(ChatBarBacking, XPosition, YPosition, Configuration.AnimationTimeHide*2, false, math.max(100, XPosition))
	end

	local function GetAutoCompleteOption(Message)

		local Start, End = Message:find("%w*$")
		local LastWord = Message:sub(Start, End)
		if LastWord and #LastWord >= 2 then
			--local Possibles = {}
			-- print(LastWord)

			for _, Player in pairs(Players:GetPlayers()) do
				if qString.CompareCutFirst(Player.Name, LastWord) then
					--Possibles[#Possibles+1] = Player.Name

					if Start == 1 then
						return Message:sub(1, Start-1) .. Player.Name .. ": "
					else
						return Message:sub(1, Start-1) .. Player.Name .. " "
					end
				end
			end

			--return Possibles
		else
			return
		end
	end

	local function StopFocus(EnterPressed)
		-- print("Lost focus")

		if PseudoChatBar.Focused then
			-- print("Stopped focus", tick())
			qGUI.TweenTransparency(ChatBarBacking, {BackgroundTransparency = Configuration.DefaultTransparency}, Configuration.AnimationTimeHide, true)

			LastInput = ""

			PseudoChatBar.Focused = false;

			InputCleaner:DoCleaning()
			InputCleaner = nil

			if EnterPressed then
				if InputGui.Text ~= "" and InputGui.Text ~= Configuration.DefaultText then
					LastChat = InputGui.Text

					RespondOnInput()

					NewChat:fire(LastChat)
				end
			else
				LastChat = InputGui.Text
			end

			InputGui.Text = Configuration.DefaultText

			--[[
			if not UserInputService.KeyboardEnabled or ChatBarBacking.Position.Y.Scale ~= 1 then
				ChatBarBacking:TweenPosition(UDim2.new(0, 0, 1, -Configuration.DefaultHeight), "Out", "Quad", 0.3, true)
			end--]]
		end
	end

	UserInputService.InputBegan:connect(function(Input)
		if not PseudoChatBar.Focused then
			if Input.KeyCode.Name == "Slash" then
				StartFocus()
			end
		else
			if Input.KeyCode.Name == "Up" then
				InputGui.Text = LastChat
				InputGui:CaptureFocus()

				LastInput = InputGui.Text
			elseif Input.KeyCode.Name == "Tab" then
				local Option = GetAutoCompleteOption(InputGui.Text)
				-- print("Option: " .. tostring(Option))

				if not Option then
					Option = GetAutoCompleteOption(InputGui.Text:sub(1, #InputGui.Text-1))
				end

				if Option then
					if InputGui.Text ~= Option then
						InputGui.Text = Option
						InputGui:CaptureFocus()
						RespondOnInput()
					end
				end
			else
				LastInput = InputGui.Text
			end
		end
	end)

	InputGui.FocusLost:connect(StopFocus)

	InputButton.MouseButton1Click:connect(function(X, Y)
		StartFocus()
	end)

	ChatBarBacking.Parent = Parent
end)

return setmetatable({MakePseudoChatBar = MakePseudoChatBar}, {__call = function(_, ...) MakePseudoChatBar(...) end})
