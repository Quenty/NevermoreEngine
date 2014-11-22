local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qGUI              = LoadCustomLibrary("qGUI")
local Maid              = LoadCustomLibrary("Maid")

local Make              = qSystems.Make

local lib               = {}

-- TitleGenerator.lua
-- @author Quenty

local function GenerateTitle(ScreenGui, Text, TopLabelText, BottomLabelText) 	
	-- Generates a title that looks like this
	--[[
	

	--------------
	   T I T L E
	--------------

	Which is then GCed after a while. 
	TopLabelText may be used to create a text above the top white bar, and 
	BottomLabelText below the bottom white bar
	--]]
	-- @param ScreenGui The screenGUi (or parent) to put in. It will be centered to this. Recommened ScreenGui
	-- @param Text The text to use
	-- @param [TopLabelText] The "top label" text to use.
	-- @param [BottomLabelText] - The "bottom label" text to use

	local Configuration = {
		Height             = 90; -- How high is the whole thing? Bars will be offset by LabelHeight.
		ZIndex             = 10; -- What ZIndex does it use?
		LifeTime           = 3;  -- How long does it last?
		AnimationTime      = 1;  -- How long does it animate in/out?
		ShadowTransparency = 0.9; -- Use text stroke transparency to make more contrast.
		BarTransparency    = 0.3; -- How transparency are the bars.
		BarHeight          = 4;
		ExpandFactor       = 8; -- When it disappears

		LabelHeight = 20; -- The Top and bottom labels.
	}

	local Container = Make("Frame", {
		Archivable             = false;
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "TitleContainer";
		ZIndex                 = Configuration.ZIndex;
		ClipsDescendants       = true;
	})
	Container.Parent = ScreenGui

	-- Middle Label
	local MiddleLabelSize
	local MiddleTextLabels = {} do
		Text = Text:upper()

		local SizeX = 0
		for Index = 1, #Text do
			local Character = Text:sub(Index, Index)
			if Character ~= " " then
				local TextLabel = Make("TextLabel", {
					Archivable             = false;
					BackgroundTransparency = 1;
					BorderSizePixel        = 0;
					Font                   = "Arial";
					FontSize               = "Size36";
					Name                   = "MiddleLabel" .. Character;
					Parent                 = Container;
					Size                   = UDim2.new(0, 0, 1, 0);
					Text                   = Character;
					TextColor3             = Color3.new(1, 1, 1);
					TextStrokeTransparency = 1;
					TextTransparency       = 1;
					TextXAlignment         = "Left";
					ZIndex                 = Configuration.ZIndex;
				})

				-- Alternate sliding in from left or right.
				if Index % 2 == 0 then
					TextLabel.Position = UDim2.new(0, 0, 0.5, -Configuration.Height/2);
				else
					TextLabel.Position = UDim2.new(1, 0, 0.5, -Configuration.Height/2);
				end

				local Position = UDim2.new(0.25, SizeX, 0, 0) -- The middle 50% of the frame will contain characters.

				delay(Configuration.AnimationTime * ((Index/#Text)/2), function()
					TextLabel:TweenPosition(Position, "Out", "Quad", Configuration.AnimationTime/2, true)
					qGUI.TweenTransparency(TextLabel, {TextTransparency = 0, TextStrokeTransparency = Configuration.ShadowTransparency}, Configuration.AnimationTime/2, true)
				end)
				SizeX = SizeX + TextLabel.TextBounds.X + 5
				MiddleTextLabels[#MiddleTextLabels+1] = TextLabel;
			else
				SizeX = SizeX + 10
			end
		end
		MiddleLabelSize = SizeX
	end

	-- TopLabel
	local TopLabels = {} if TopLabelText then
		TopLabelText = TopLabelText:upper()

		local SizeX = 0
		for Index = 1, #TopLabelText do
			local Character = TopLabelText:sub(Index, Index)
			if Character ~= " " then
				local TextLabel = Make("TextLabel", {
					Archivable             = false;
					BackgroundTransparency = 1;
					BorderSizePixel        = 0;
					Font                   = "Arial";
					FontSize               = "Size14";
					Name                   = "TopLabel" .. Character;
					Parent                 = Container;
					Size                   = UDim2.new(0, 0, 0, Configuration.LabelHeight);
					Text                   = Character;
					TextColor3             = Color3.new(1, 1, 1);
					TextStrokeTransparency = 1;
					TextTransparency       = 1;
					TextXAlignment         = "Left";
					ZIndex                 = Configuration.ZIndex;
				})

				TextLabel.Position = UDim2.new(1, 0, 0, 0); -- We'll slide in from the right.

				local Position = UDim2.new(3/16, SizeX, 0, 0)

				delay(Configuration.AnimationTime * ((Index/#TopLabelText)/2), function()
					TextLabel:TweenPosition(Position, "Out", "Quad", Configuration.AnimationTime/2, true)
					qGUI.TweenTransparency(TextLabel, {TextTransparency = 0, TextStrokeTransparency = Configuration.ShadowTransparency}, Configuration.AnimationTime/2, true)
				end)
				SizeX = SizeX + TextLabel.TextBounds.X + 3

				TopLabels[#TopLabels+1] = TextLabel
			else
				SizeX = SizeX + 5
			end
		end
	end

	-- BottomLabel
	local BottomLabels = {} if BottomLabelText then
		BottomLabelText = BottomLabelText:upper()

		local SizeX = 0
		for Index = #BottomLabelText, 1, -1 do
			local Character = BottomLabelText:sub(Index, Index)
			if Character ~= " " then
				local TextLabel = Make("TextLabel", {
					Archivable             = false;
					BackgroundTransparency = 1;
					BorderSizePixel        = 0;
					Font                   = "Arial";
					FontSize               = "Size14";
					Name                   = "BottomLabel" .. Character;
					Parent                 = Container;
					Size                   = UDim2.new(0, 0, 0, Configuration.LabelHeight);
					Text                   = Character;
					TextColor3             = Color3.new(1, 1, 1);
					TextStrokeTransparency = 1;
					TextTransparency       = 1;
					TextXAlignment         = "Right";
					ZIndex                 = Configuration.ZIndex;
				})

				TextLabel.Position = UDim2.new(0, 0, 1, -Configuration.LabelHeight); -- We'll slide in from the left

				local Position = UDim2.new(13/16, -SizeX, 1, -Configuration.LabelHeight)

				delay(Configuration.AnimationTime * (((#BottomLabelText - Index)/#BottomLabelText)/2), function()
					TextLabel:TweenPosition(Position, "Out", "Quad", Configuration.AnimationTime/2, true)
					qGUI.TweenTransparency(TextLabel, {TextTransparency = 0, TextStrokeTransparency = Configuration.ShadowTransparency}, Configuration.AnimationTime/2, true)
				end)
				SizeX = SizeX + TextLabel.TextBounds.X + 3-- Compenstate for letter?

				BottomLabels[#BottomLabels+1] = TextLabel
			else
				SizeX = SizeX + 5
			end
		end
	end

	-- Add decoration
	local TopStripe = Make("Frame", {
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "TopDecoration";
		Parent                 = Container;
		Position               = UDim2.new(0.25/2, 0, 0, Configuration.LabelHeight);
		Size                   = UDim2.new(0.75, 0, 0, Configuration.BarHeight);
		ZIndex                 = Configuration.ZIndex;
	})

	local BottomStripe = Make("Frame", {
		Archivable             = false;
		BackgroundColor3       = Color3.new(1, 1, 1);
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Name                   = "BottomDecoration";
		Parent                 = Container;	
		Position               = UDim2.new(0.25/2, 0, 1, -Configuration.BarHeight - Configuration.LabelHeight);
		Size                   = UDim2.new(0.75, 0, 0, Configuration.BarHeight);
		ZIndex                 = Configuration.ZIndex;
	})

	qGUI.TweenTransparency(TopStripe, {BackgroundTransparency = Configuration.BarTransparency}, Configuration.AnimationTime, true)
	qGUI.TweenTransparency(BottomStripe, {BackgroundTransparency = Configuration.BarTransparency}, Configuration.AnimationTime, true)

	-- Container.Size = UDim2.new(0, Configuration.BarHeight*2, 0, Configuration.Height)
	-- Container.Position = UDim2.new(0.5, 0, 0.5, -Configuration.Height)

	Container.Size = UDim2.new(0, MiddleLabelSize*2, 0, 0)
	Container.Position = UDim2.new(0.5, -MiddleLabelSize, 0.5, -Configuration.Height/2)

	Container:TweenSizeAndPosition(UDim2.new(0, MiddleLabelSize*2, 0, Configuration.Height), UDim2.new(0.5, -MiddleLabelSize, 0.5, -Configuration.Height), "Out", "Quad", Configuration.AnimationTime, true)

	--- GC / Removal
	delay(Configuration.LifeTime, function()
		-- Bars
		qGUI.TweenTransparency(TopStripe, {BackgroundTransparency = 1}, Configuration.AnimationTime, true)
		qGUI.TweenTransparency(BottomStripe, {BackgroundTransparency = 1}, Configuration.AnimationTime, true)

		Container:TweenSizeAndPosition(UDim2.new(0, MiddleLabelSize*2, 0, Configuration.Height*Configuration.ExpandFactor), UDim2.new(0.5, -MiddleLabelSize, 0.5, -Configuration.Height*(Configuration.ExpandFactor/2 + 0.5)), "In", "Quad", Configuration.AnimationTime, true)
		TopStripe:TweenSizeAndPosition(UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 0.25, Configuration.LabelHeight), "Out", "Quad", Configuration.AnimationTime)
		BottomStripe:TweenSizeAndPosition(UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 0.75, -Configuration.BarHeight - Configuration.LabelHeight), "Out", "Quad", Configuration.AnimationTime)

		-- Midle animation
		for Index, TextLabel in pairs(MiddleTextLabels) do
			delay(Configuration.AnimationTime * ((Index/#Text)/2), function()
				TextLabel:TweenPosition(UDim2.new(Index % 2 == 0 and 1 or 0, 0, 0, 0), "In", "Quad", Configuration.AnimationTime/2, true)
				qGUI.TweenTransparency(TextLabel, {TextTransparency = 1, TextStrokeTransparency=1}, Configuration.AnimationTime/2, true)
			end)
		end

		-- Top Animation
		for Index, TextLabel in pairs(TopLabels) do
			delay(Configuration.AnimationTime * ((Index/#Text)/2), function()
				TextLabel:TweenPosition(UDim2.new(0, 0, 0, 0), "In", "Quad", Configuration.AnimationTime/2, true)
				qGUI.TweenTransparency(TextLabel, {TextTransparency = 1, TextStrokeTransparency=1}, Configuration.AnimationTime/2, true)
			end)
		end

		-- Bottom Animation
		for Index, TextLabel in pairs(BottomLabels) do
			delay(Configuration.AnimationTime * (((Index)/#Text)/2), function()
				TextLabel:TweenPosition(UDim2.new(1, 0, 1, -Configuration.LabelHeight), "In", "Quad", Configuration.AnimationTime/2, true)
				qGUI.TweenTransparency(TextLabel, {TextTransparency = 1, TextStrokeTransparency=1}, Configuration.AnimationTime/2, true)
			end)
		end


		wait(Configuration.AnimationTime)

		-- CLEAN UP -- 
		for _, TextLabel in pairs(MiddleTextLabels) do
			TextLabel:Destroy()
		end

		for Index, TextLabel in pairs(TopLabels) do
			TextLabel:Destroy()
		end

		TopStripe:Destroy()
		BottomStripe:Destroy()
		Container:Destroy()
	end)
end
lib.GenerateTitle = GenerateTitle
lib.generateTitle = GenerateTitle

return lib