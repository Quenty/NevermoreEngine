local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")

local NevermoreEngine          = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary        = NevermoreEngine.LoadLibrary

local qSystems = LoadCustomLibrary("qSystems")
local Maid     = LoadCustomLibrary("Maid")
local qString  = LoadCustomLibrary("qString")
local qGUI     = LoadCustomLibrary("qGUI")

qSystems:Import(getfenv(0))

-- PseudoChatBar.lua
-- @author Quenty

local lib = {}

local MakePseudoChatBar = Class(function(PseudoChatBar, ScreenGui)
	--- Creates a new pseudo chat bar for chatting

	local Configuration = {
		DefaultText = UserInputService.MouseEnabled and "Push \"/\" to chat" or "Tap here to chat";
		XOffset     = 65;
		ZIndex      = 10;
		DefaultTransparency = 1;
		SelectedTransparency = 0.3;
		AnimationTime = 0.05;
		AnimationTimeHide = 0.1;
		DefaultHeight = 30;
	}

	local NewChat         = CreateSignal()
	PseudoChatBar.NewChat = NewChat

	-- GENERATE GUIS 

	local ChatBarBacking = Make("Frame", {
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = Configuration.DefaultTransparency;
		BorderSizePixel        = 0;
		Name                   = "ChatBar";
		Position               = UDim2.new(0, 0, 1, -Configuration.DefaultHeight);
		Size                   = UDim2.new(1, 0, 0, Configuration.DefaultHeight);
		ZIndex                 = Configuration.ZIndex-1;
	})
	PseudoChatBar.Gui = ChatBarBacking

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
		Font                   = "Arial";
		FontSize               = "Size14";
		Name                   = "ChatBar";
		Parent                 = ChatBarBacking;
		Position               = UDim2.new(0, Configuration.XOffset, 0, 0);
		Size                   = UDim2.new(1, -Configuration.XOffset, 1, 0);
		Text                   = Configuration.DefaultText;
		TextColor3             = Color3.new(1, 1, 1);
		TextStrokeTransparency = 0.9;
		TextTransparency       = 0;
		TextXAlignment         = "Left";
		ZIndex                 = Configuration.ZIndex-1;
		MultiLine = false;
	})

	local LastChat = ""
	local LastInput = "" --- Utilized for autocomplete things.
	PseudoChatBar.Focused = false
	local InputCleaner

	local function StartFocus()
		if not PseudoChatBar.Focused then
			PseudoChatBar.Focused = true

			InputGui.Text = ""
			game:GetService("RunService").RenderStepped:wait(0)
			-- wait()
			InputGui:CaptureFocus()
			InputGui.Text = ""

			InputCleaner = Maid.new()
			qGUI.TweenTransparency(ChatBarBacking, {BackgroundTransparency = Configuration.SelectedTransparency}, Configuration.AnimationTime, true)
		end
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
					return Message:sub(1, Start-1) .. Player.Name .. " "
				end
			end

			--return Possibles
		else
			return
		end
	end

	local function StopFocus(EnterPressed)
		if PseudoChatBar.Focused then
			qGUI.TweenTransparency(ChatBarBacking, {BackgroundTransparency = Configuration.DefaultTransparency}, Configuration.AnimationTimeHide, true)

			LastInput = ""

			PseudoChatBar.Focused = false;

			InputCleaner:DoCleaning()
			InputCleaner = nil

			if EnterPressed then
				if InputGui.Text ~= "" and InputGui.Text ~= Configuration.DefaultText then
					LastChat = InputGui.Text
					NewChat:fire(LastChat)
				end

				-- InputGui.Text = Configuration.DefaultText
			else
				LastChat = InputGui.Text
			end

			InputGui.Text = Configuration.DefaultText

		end
	end

	UserInputService.InputBegan:connect(function(Input)
		Spawn(function()
			if not PseudoChatBar.Focused then
				-- print(Input)
				-- print(tostring(Input.KeyCode))
				-- print(Input.KeyCode.Name)
				if Input.KeyCode.Name == "Slash" then
					StartFocus()
				-- elseif Input.KeyCode.Name == "Tab" then
				-- 	print("Tab")
				end
			else
				if Input.KeyCode.Name == "Up" then
					InputGui.Text = LastChat
					LastInput = InputGui.Text
				elseif Input.KeyCode.Name == "Tab" then
					local Option = GetAutoCompleteOption(InputGui.Text)
					-- print("Option: " .. tostring(Option))

					if not Option then
						Option = GetAutoCompleteOption(InputGui.Text:sub(1, #InputGui.Text-1))
					end

					if Option then
						InputGui.Text = Option
					end
				else
					LastInput = InputGui.Text
				end
			end
		end)
	end)

	InputGui.FocusLost:connect(StopFocus)

	InputButton.MouseButton1Click:connect(function()
		StartFocus()
	end)

	ChatBarBacking.Parent = ScreenGui
end)
lib.MakePseudoChatBar = MakePseudoChatBar

return lib;