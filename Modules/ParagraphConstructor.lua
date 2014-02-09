while not _G.NevermoreEngine do wait(0) end

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local qString           = LoadCustomLibrary('qString')
local MarkdownSystem    = LoadCustomLibrary('MarkdownSystem')
local qGUI              = LoadCustomLibrary('qGUI')

local lib    = {}
local Styles = {}

qSystems:Import(getfenv(0))

local NewColor3 = qGUI.NewColor3

local TemporaryLabel

local function ModifyWithClone(instance, values)
	-- Modifies an instance by using a table, but clones instances instead of parenting...

	for key, value in next, values do
		if type(key) == "number" then
			value:Clone().Parent = instance
		else 	
			instance[key] = value
		end
	end
	return instance
end

local function GetSentenceBreakdown(MaxX, CurrentX, Text, Style, ScreenGui)
	--- Breaks the given Text into fragments to be rendred as a paragraph.
	-- @param MaxX Number, in pixels, the width (X) of the frame it is being put into.
	-- @param CurrentX The distance in pixels (width, X), of that the marker has already gone. This parameter
	--                 may be used when a sentence has stying in the middle.
	-- @param Text The text to break into. A string.
	-- @param [Style] The style to use, a table. The style must be given so the label can know how far to go
	--                / render before stopping.
	-- @param ScreenGui A ScreenGui that is active, because TextBounds doesn't work. 
	-- @return Table 'Fragments' A table of all the fragments generated,
	--         number The CurrentX it ended at

	-- Note that this system does sometimes generate excess labels. Still working on that. 


	--print("Breaking down \"" .. Text .. "\"")

	if (not TemporaryLabel) or (TemporaryLabel and not TemporaryLabel.Parent) then
		if TemporaryLabel then
			TemporaryLabel:Destroy()
		end
		TemporaryLabel = Make 'TextLabel' {
			BackgroundTransparency = 1;
			Name                   = "TemporaryLabel";
			Parent                 = assert(ScreenGui, "ScreenGui is nil");
			Position               = UDim2.new(0, 0, 0, -105);
			Size                   = UDim2.new(0, 100, 0, 100);
			Visible                = true;
			Archivable = true;
		}
	end

	Style = Style or {}
	local Fragments = {}
	local Words = {}

	for Text, Whitespace in string.gmatch(Text, "([%w%p]*)([%s]*)") do
		if Text ~= "" then 
			Words[#Words+1] = Text 
		end 
		if Whitespace ~= "" then 
			Words[#Words+1] = Whitespace 
		end 
	end

	local TemporaryLabel = ModifyWithClone(TemporaryLabel, Style)
	TemporaryLabel.Text = ""

	--[[
	OverflowWarFail:
		1234567890
		HelloBigWorld

	Overflow Correct: 
		1234567890
		HelloBigWoXXX
		rld

	--]]

	local FragmentCount = 1
	local CurrentLine

	local function CloneLabel(OldText)
		-- Adds OldText to the fragment list, presuming that OldText is all of that style's text for that line.

		--print("Adding clone label of \"" .. OldText .. "\"")
		TemporaryLabel.Text = OldText -- We can get text's like ""... For now, ignore.
		local Label = TemporaryLabel:Clone()
		Label.Text = TemporaryLabel.Text
		Label.Size = UDim2.new(0, TemporaryLabel.TextBounds.x, 0, TemporaryLabel.TextBounds.y)
		Fragments[FragmentCount] = Label
		CurrentLine = Label
		FragmentCount = FragmentCount + 1
		CurrentX = 0;
	end

	for _, Word in pairs(Words) do
		local OldText = TemporaryLabel.Text
		local NewText = TemporaryLabel.Text .. Word
		TemporaryLabel.Text = NewText

		if not qString.IsWhitespace(Word) then
			if (TemporaryLabel.TextBounds.X + CurrentX) >= MaxX then -- If we can't add the next word, then...
				CloneLabel(OldText) -- And add the current line information that is there.
				-- Now we need to add the word to the next new line.

				TemporaryLabel.Text = Word -- Add... :D

				if TemporaryLabel.TextBounds.X > MaxX then -- Next Word is too long to fit on a single line, Overflow correctly
					-- by basically fitting as many characters as we can per a line...

					TemporaryLabel.Size = UDim2.new(0, MaxX, 0, 100)
					local WorkingWord = Word
					while #WorkingWord ~= 0 do -- While letters are left in the word, do...
						TemporaryLabel.Text = TemporaryLabel.Text .. WorkingWord:sub(1, 1) -- Add the first letter to the word..
						if (TemporaryLabel.TextBounds.X + CurrentX) >= MaxX then -- If it overflows...
							CloneLabel(TemporaryLabel.Text:sub(1, #TemporaryLabel.Text-1)) -- Add the whole part of the word to the label, 
							-- and then effectively add the next letter to the label...
							TemporaryLabel.Text = WorkingWord:sub(1, 1)
						end
						WorkingWord = WorkingWord:sub(2)
					end
				end -- Else, the new word fits fine, move on....
			end -- Otherwise the new word fits fine, keep on adding words...
		--[[else -- Handling Whitespace (Can overflow indefinitely)
			if (TemporaryLabel.TextBounds.X + CurrentX) >= MaxX then -- We overflowed... Technically, nothing happens?
				-- CloneLabel(OldText)
				-- TemporaryLabel.Text = Word
			end--]]
		end
	end
	CloneLabel(TemporaryLabel.Text)

	return Fragments, (CurrentLine and TemporaryLabel.TextBounds.X or CurrentX)
end

local function ConstructParagraph(Container, Content, ParagrahFormat, ScreenGui)
	-- Given a Container sized at UDim2.new(0, ?, 0, ?), this will resize the Y part of the Container and fill it with 'Content'.



	ParagrahFormat = ParagrahFormat or {}
	ParagrahFormat.LineSpacingAt = ParagrahFormat.LineSpacingAt or 1.2

	local CurrentX = 0;
	local MaxX = Container.AbsoluteSize.X
	local Lines = {}
	local LineNumber = 1;

	local function GetLine(LineNumber)
		local Line = Lines[LineNumber]
		if not Line then
			Line = {
				Fragments = {};
				HeightY = 0;
			}
			Lines[LineNumber] = Line;
		end
		return Line
	end

	for _, TextClass in pairs(Content) do -- We're breaking it into segments based upon style
		--print("Processing Content " .. TextClass.Text .. " ")
		local Text = assert(TextClass.Text, "Could not get Text");
		local Style = assert(TextClass.Style, "Could not get Style");

		local Fragments

		Fragments, CurrentX = GetSentenceBreakdown(MaxX, CurrentX, Text, Style, ScreenGui)
		for _, Fragment in pairs(Fragments) do -- And then process it into lines, regardless of style.
			local Line = GetLine(LineNumber)
			--print("Added new fragment \"" .. Fragment.Text .. "\" to line " .. LineNumber .. " @ index " .. (#Line.Fragments+1))
			Line.Fragments[#Line.Fragments+1] = Fragment
			local TextBoundY = Fragment.Size.Y.Offset
			if Line.HeightY < TextBoundY then
				Line.HeightY = TextBoundY
			end
			LineNumber = LineNumber + 1
		end
		LineNumber = LineNumber - 1 -- Last line may still contain content, we we start at that, not one above.
	end

	local CurrentY = 0
	for LineNumber, Line in pairs(Lines) do
		--print("Processing Line "..LineNumber.." #Line.Fragments = " .. (#Line.Fragments) .. "; Line.HeightY = " .. Line.HeightY)
		local LineSpacing = Line.HeightY * (ParagrahFormat.LineSpacingAt - 1)
		CurrentY = CurrentY + Line.HeightY + LineSpacing
		CurrentX = 0;
		for _, Fragment in pairs(Line.Fragments) do
			--print("Processing Fragment \"" .. Fragment.Text .. "\"")
			Fragment.Name = "Fragment" .. LineNumber
			Fragment.Parent = Container;
			Fragment.Position = UDim2.new(0, CurrentX, 0, CurrentY - Fragment.Size.Y.Offset - LineSpacing)
			CurrentX = CurrentX + Fragment.Size.X.Offset
		end
	end

	return Container, CurrentY, CurrentX
end
lib.ConstructParagraph = ConstructParagraph
lib.constructParagraph = ConstructParagraph


Styles.Headers = {}
	Styles.Headers[1] = {
		TextColor3 = NewColor3(255, 255, 255);
		BackgroundColor3 = NewColor3(255, 255, 255);
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		TextXAlignment = "Left";
		TextYAlignment = "Center";
		TextStrokeTransparency = 1;
		TextTransparency = 0;
		TextStrokeColor3 = NewColor3(0, 0, 0);
		FontSize = "Size48";
		Font = "ArialBold";
	}
	Styles.Headers[2] = {
		TextColor3 = NewColor3(255, 255, 255);
		BackgroundColor3 = NewColor3(255, 255, 255);
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		TextXAlignment = "Left";
		TextYAlignment = "Center";
		TextStrokeTransparency = 1;
		TextTransparency = 0;
		TextStrokeColor3 = NewColor3(0, 0, 0);
		FontSize = "Size36";
		Font = "ArialBold";
	}
	Styles.Headers[3] = {
		TextColor3 = NewColor3(255, 255, 255);
		BackgroundColor3 = NewColor3(255, 255, 255);
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		TextXAlignment = "Left";
		TextYAlignment = "Center";
		TextStrokeTransparency = 1;
		TextTransparency = 0;
		TextStrokeColor3 = NewColor3(0, 0, 0);
		FontSize = "Size24";
		Font = "ArialBold";
	}
	Styles.Headers[4] = {
		TextColor3 = NewColor3(255, 255, 255);
		BackgroundColor3 = NewColor3(255, 255, 255);
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		TextXAlignment = "Left";
		TextYAlignment = "Center";
		TextStrokeTransparency = 1;
		TextTransparency = 0;
		TextStrokeColor3 = NewColor3(0, 0, 0);
		FontSize = "Size18";
		Font = "ArialBold";
	}
	Styles.Headers[5] = {
		TextColor3 = NewColor3(255, 255, 255);
		BackgroundColor3 = NewColor3(255, 255, 255);
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		TextXAlignment = "Left";
		TextYAlignment = "Center";
		TextStrokeTransparency = 1;
		TextTransparency = 0;
		TextStrokeColor3 = NewColor3(0, 0, 0);
		FontSize = "Size14";
		Font = "ArialBold";
	}
Styles.Normal = {
	TextColor3 = NewColor3(215, 215, 215);
	BackgroundColor3 = NewColor3(255, 255, 255);
	BackgroundTransparency = 1;
	BorderSizePixel = 0;
	TextXAlignment = "Left";
	TextYAlignment = "Center";
	TextStrokeTransparency = 1;
	TextTransparency = 0;
	TextStrokeColor3 = NewColor3(0, 0, 0);
	FontSize = "Size14";
	Font = "Arial";
}
Styles.TransparentFrame = {
	BackgroundColor3       = Color3.new(0, 0, 0);
	BackgroundTransparency = 1;
	BorderSizePixel        = 0;
	-- Style                  = "Custom";
}



local function ParseText(MarkdownText)
	-- Using the MarkdownSystem, convert ito beautiful beautiful tables using concepts I don't understand fully.
	
	local MarkdownedTable = MarkdownSystem.MarkdownToTable(MarkdownText)
	return MarkdownedTable
end

local Handlers = {
	normal = function(Data, NewContainer, ScreenGui)
		if Data.text ~= "" then
			local TextContent = {}

			TextContent[1] = { -- Will improve later for markdown emphasis, etc.
				Text = Data.text;
				Style = Styles.Normal;
			}

			local NewContainer, ContainerHeight = ConstructParagraph(NewContainer, TextContent, {
				LineSpacingAt = 1.15; -- Standard in MS Word (115%)
			}, ScreenGui)

			return NewContainer, ContainerHeight
		else
			--print("[ParagraphConstructor] - Could not Process: Data.text == \"\"");
			return false;
		end
	end;
	header = function(Data, NewContainer, ScreenGui)
		if Data.text ~= "" then
			local TextContent = {}

			TextContent[1] = { 
				Text = assert(Data.text, "Data.text is nil");
				Style = Styles.Headers[Data.level or 1];
			}

			local NewContainer, ContainerHeight = ConstructParagraph(NewContainer, TextContent, {
				LineSpacingAt = 1;
			}, ScreenGui)


			return NewContainer, ContainerHeight
		else
			--print("[ParagraphConstructor] - Could not Process: Data.text == \"\"");
			return false;
		end
	end;
	list_item = function(Data, NewContainer, ScreenGui)
		if Data.text ~= "" then
			local TextContent = {}

			TextContent[1] = {
				Text = Data.text;
				Style = Styles.Normal;
			}

			local NewNewContainer = NewContainer:Clone()
			NewNewContainer.Size = UDim2.new(1, -20, 1, 0)
			NewNewContainer.Position = UDim2.new(0, 20, 0, 0)
			NewNewContainer.Parent = NewContainer

			local BulletPoint = Make 'Frame' {
				Size = UDim2.new(0, 6, 0, 6);
				Position = UDim2.new(0, 4, 0.5, -3);
				BorderSizePixel = 0;
				BackgroundTransparency = 0;
				BackgroundColor3 = Color3.new(1, 1, 1);
				Name = "BulletPoint";
				Parent = NewContainer;
				ZIndex = NewContainer.ZIndex;
			}

			local NewNewContainer, ContainerHeight = ConstructParagraph(NewNewContainer, TextContent, {
				LineSpacingAt = 1;
			}, ScreenGui)

			return NewContainer, ContainerHeight
		else
			--print("[ParagraphConstructor] - Could not Process: Data.text == \"\"");
			return false;
		end
	end;
}

local function GetHandler(HandlerName)
	-- Return's a markdown handler, will default to 'normal' if all else fails.
	-- So yeah, this is a really weird system.

	if not Handlers[HandlerName] then
		print("Warning: Could not find '" .. HandlerName .. "' defaulting to 'normal'")
	end

	return Handlers[HandlerName] or Handlers.normal
end

local function ConstructBlock(MarkdownText, Container, ScreenGui, Format)
	-- Format's a "Block" of MardownText, that is, basically a document.
	-- MarkdownText is a string, using markdown text
	-- Container is the container we dump it into
	-- ScreenGui is the screenGUI that will be utilized to create it (really required for some rendering / size getting issues)
	-- Format is a configuration table. 

	Format = Format or {}
	Format.MarginLeft    = Format.MarginLeft or 10
	Format.MarginRight   = Format.MarginRight or 10
	Format.SpacingAfter  = Format.SpacingAfter or 5
	Format.SpacingBefore = Format.SpacingBefore or 5

	local HeightY = 0

	local ParsedText = ParseText(MarkdownText)
	for Index, Item in pairs(ParsedText) do
		HeightY = HeightY + Format.SpacingBefore
		local NewContainer = Make 'Frame' (Styles.TransparentFrame)
		NewContainer.Parent = Container
		NewContainer.Position = UDim2.new(0, Format.MarginLeft, 0, HeightY)
		NewContainer.Size = UDim2.new(1, -Format.MarginLeft - Format.MarginRight, 0, 0)
		NewContainer.Name = Index.."Container"

		local Success, NewHeightY = GetHandler(Item.type)(Item, NewContainer, ScreenGui)
		if Success then
			HeightY = HeightY + NewHeightY + Format.SpacingAfter
			NewContainer.Size = UDim2.new(NewContainer.Size.X.Scale, NewContainer.Size.X.Offset, 0, NewHeightY + Format.SpacingAfter)
		else
			HeightY = HeightY - Format.SpacingBefore -- Remove old spacing. :/
		end
	end

	return Container, HeightY
end
lib.ConstructBlock = ConstructBlock
lib.constructBlock = ConstructBlock

NevermoreEngine.RegisterLibrary("ParagraphConstructor", lib)