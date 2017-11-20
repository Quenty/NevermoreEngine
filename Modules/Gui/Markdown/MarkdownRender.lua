local TextService = game:GetService("TextService")

-- Intent: Renders the markdown from MarkdownParser
-- @author Quenty

local MarkdownRender = {}
MarkdownRender.__index = MarkdownRender
MarkdownRender.ClassName = "MarkdownRender"
MarkdownRender.SpaceAfterParagraph = 10
MarkdownRender.TextSize = 18
MarkdownRender.Indent = 30
MarkdownRender.BaseTextColor3 = Color3.new(56/255, 56/255, 56/255)

function MarkdownRender.new(Gui, Width)
	local self = setmetatable({}, MarkdownRender)
	
	self.Gui = Gui or error("No Gui")
	self.Width = Width or error("No Width")
	
	return self
end

function MarkdownRender:GetFrame()
	local Frame = Instance.new("Frame")
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0
	Frame.Size = UDim2.new(1, 0, 0, 0)
	Frame.ZIndex = self.Gui.ZIndex
	
	return Frame
end

function MarkdownRender:GetTextLabel()
	local TextLabel = Instance.new("TextLabel")
	TextLabel.BackgroundTransparency = 1
	TextLabel.Size = UDim2.new(1, 0, 0, 0)
	TextLabel.ZIndex = self.Gui.ZIndex
	
	return self:FormatTextLabel(TextLabel)
end

function MarkdownRender:FormatTextLabel(TextLabel)
	TextLabel.Font = Enum.Font.SourceSans
	TextLabel.TextColor3 = self.BaseTextColor3
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	TextLabel.TextYAlignment = Enum.TextYAlignment.Top
	TextLabel.TextWrapped = true
	TextLabel.TextSize = self.TextSize
	TextLabel.TextStrokeTransparency = 1
	
	return TextLabel
end

function MarkdownRender:RenderParagraphLabel(Label, Text)
	-- Strip ending punctuation which screws with roblox's wordwrapping and .TextFits
	local StrippedText = Text:gsub("(%p+)$", "")
	
	local Width = self.Width or error("No width")
	local LabelWidth = Label.Size.X.Scale*Width + Label.Size.X.Offset
	local TextSize = TextService:GetTextSize(StrippedText, Label.TextSize, Label.Font, Vector2.new(LabelWidth, Label.TextSize*20))
	Label.Size = UDim2.new(Label.Size.X, UDim.new(0, TextSize.Y))
	
	Label.Text = Text
	
	return Label
end

function MarkdownRender:RenderParagraph(Text, Options)
	Options = Options or {}
	
	local Label = self:GetTextLabel()
	Label.Text = Text
	Label.Name = "Paragraph"
	Label.Parent = Options.Parent or self.Gui
	
	self:RenderParagraphLabel(Label, Text)
	
	return Label
end

function MarkdownRender:GetBullet(Level)
	local Bullet = Instance.new("Frame")
	Bullet.Name = "Bullet"
	Bullet.BorderSizePixel = 0
	
	Bullet.BackgroundColor3 = self.BaseTextColor3
	Bullet.ZIndex = self.Gui.ZIndex
	
	if Level == 2 then
		Bullet.Size = UDim2.new(0, 6, 0, 1)
	else
		Bullet.Size = UDim2.new(0, 4, 0, 4)
	end
	
	return Bullet
end

function MarkdownRender:RenderList(ListData)
	assert(type(ListData.Level) == "number" and ListData.Level > 0)

	local Frame = self:GetFrame()
	Frame.Name = ("ListLevel_%d"):format(ListData.Level)
	Frame.Size = UDim2.new(1, -(ListData.Level)*self.Indent, 0, 0)
	Frame.Position = UDim2.new(0, -Frame.Size.X.Offset, 0, 0)
	Frame.Parent = self.Gui
	
	local YHeight = 0
	for Index, Text in ipairs(ListData) do
		local TextLabel = self:RenderParagraph(Text, { Parent = Frame })
		
		local Bullet = self:GetBullet(ListData.Level)
		Bullet.AnchorPoint = Vector2.new(0.5, 0.5)
		Bullet.Position = UDim2.new(0, -self.Indent/2, 0, self.TextSize/2 + 1)
		Bullet.Parent = TextLabel
		
		TextLabel.Name = ("%d_%s"):format(Index, TextLabel.Name)
		TextLabel.Position = UDim2.new(TextLabel.Position.X, UDim.new(0, YHeight))
		YHeight = YHeight + TextLabel.Size.Y.Offset + 2
	end
	
	Frame.Size = UDim2.new(Frame.Size.X, UDim.new(0, YHeight))
	
	return Frame
end

function MarkdownRender:RenderHeader(HeaderData)
	local Label = self:GetTextLabel()
	Label.Name = "Header" .. HeaderData.Level
	Label.Parent = self.Gui
	Label.TextSize = self.TextSize + (5-HeaderData.Level) * 2
	
	
	self:RenderParagraphLabel(Label, HeaderData.Text)
	Label.TextYAlignment = Enum.TextYAlignment.Center
	Label.Size = UDim2.new(Label.Size.X, UDim.new(Label.Size.Y.Scale, Label.Size.Y.Offset + 6)) -- Extra padding
	
	local Underline = self:GetFrame()
	Underline.Name = "Underline"
	Underline.BackgroundTransparency = 0
	Underline.BackgroundColor3 = Color3.new(0.9, 0.9, 0.9)
	Underline.Size = UDim2.new(1, 0, 0, 1)
	Underline.AnchorPoint = Vector2.new(0, 1)
	Underline.Position = UDim2.new(0, 0, 1, 0)
	Underline.Parent = Label
	
	return Label
end


function MarkdownRender:Render(Data)
	local YHeight = 0
	for Index, Item in pairs(Data) do
		local GuiObject
		if type(Item) == "string" then
			GuiObject = self:RenderParagraph(Item)
			GuiObject.Position = UDim2.new(GuiObject.Position.X, UDim.new(0, YHeight))
			YHeight = YHeight + GuiObject.Size.Y.Offset + self.SpaceAfterParagraph
		elseif type(Item) == "table" then
			if Item.Type == "List" then
				GuiObject = self:RenderList(Item)
				GuiObject.Position = UDim2.new(GuiObject.Position.X, UDim.new(0, YHeight))
				YHeight = YHeight + GuiObject.Size.Y.Offset
				
				if not (type(Data[Index+1]) == "table" and Data[Index+1].Type == "List" and Data[Index+1].Level ~= Item.Level) then
					YHeight = YHeight + self.SpaceAfterParagraph
				end
			elseif Item.Type == "Header" then
				if Data[Index-1] then -- Add additional spacing for headers
					YHeight = YHeight + self.SpaceAfterParagraph
				end
				
				GuiObject = self:RenderHeader(Item)
				GuiObject.Position = UDim2.new(GuiObject.Position.X, UDim.new(0, YHeight))
				YHeight = YHeight + GuiObject.Size.Y.Offset + self.SpaceAfterParagraph
			else
				error(("Bad data type '%s'"):format(tostring(Item.Type)))
			end
		else
			error("Bad data type")
		end
		
		if GuiObject then
			GuiObject.Name = ("%d_%s"):format(Index, GuiObject.Name)
		end
	end
	
	self.Gui.Size = UDim2.new(self.Gui.Size.X, UDim.new(0, YHeight))
end

return MarkdownRender