--[=[
	Renders the markdown. See [MarkdownParser] for parsing.

	:::warning
	This API surface has not been touched for a while and may not be suitable for production.
	:::

	@class MarkdownRender
]=]

local TextService = game:GetService("TextService")

local MarkdownRender = {}
MarkdownRender.__index = MarkdownRender
MarkdownRender.ClassName = "MarkdownRender"
MarkdownRender.SpaceAfterParagraph = 10
MarkdownRender.SpaceAfterHeader = 5
MarkdownRender.SpaceBetweenList = 2
MarkdownRender.TextSize = 18
MarkdownRender.Indent = 30
MarkdownRender.TextColor3 = Color3.fromRGB(56, 56, 56)
MarkdownRender.MaxHeaderLevel = 3 -- h5 is the largest

--[=[
	Creates a new markdown render
	@param gui GuiObject
	@param width number -- Width to render at
	@return MarkdownRender
]=]
function MarkdownRender.new(gui, width)
	local self = setmetatable({}, MarkdownRender)

	self._gui = gui or error("No Gui")
	self._width = width or error("No width")

	return self
end

function MarkdownRender:WithOptions(options)
	self.TextSize = options.TextSize
	self.SpaceAfterParagraph = options.SpaceAfterParagraph

	return self
end

--[=[
	Renders the data in the given gui
	@param data table -- Data from MarkdownParser.
]=]
function MarkdownRender:Render(data)
	local height = 0
	for index, item in data do
		local gui
		if type(item) == "string" then
			gui = self:_renderParagraph(item)
			gui.Position = UDim2.new(gui.Position.X, UDim.new(0, height))
			height = height + gui.Size.Y.Offset

			if index ~= #data then
				height = height + self.SpaceAfterParagraph
			end
		elseif type(item) == "table" then
			if item.Type == "List" then
				gui = self:_renderList(item)
				gui.Position = UDim2.new(gui.Position.X, UDim.new(0, height))
				height = height + gui.Size.Y.Offset

				local nextIsNestedList = (type(data[index+1]) == "table"
					and data[index+1].Type == "List"
					and data[index+1].Level ~= item.Level)

				if index ~= #data  then
					if nextIsNestedList then
						height = height + self.SpaceBetweenList
					else
						height = height + self.SpaceAfterParagraph
					end
				end
			elseif item.Type == "Header" then
				gui = self:_renderHeader(item)
				gui.Position = UDim2.new(gui.Position.X, UDim.new(0, height))
				height = height + gui.Size.Y.Offset

				if index ~= #data then
					height = height + self.SpaceAfterHeader
				end
			else
				error(string.format("Bad data type '%s'", tostring(item.Type)))
			end
		else
			error("Bad data type")
		end

		if gui then
			gui.Name = string.format("%d_%s", index, gui.Name)
		end
	end

	self._gui.Size = UDim2.new(self._gui.Size.X, UDim.new(0, height))
end

function MarkdownRender:_getFrame()
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.ZIndex = self._gui.ZIndex

	return frame
end

function MarkdownRender:_getTextLabel()
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 0, 0)
	textLabel.ZIndex = self._gui.ZIndex

	return self:_formatTextLabel(textLabel)
end

function MarkdownRender:_formatTextLabel(textLabel)
	textLabel.Font = Enum.Font.SourceSans
	textLabel.TextColor3 = self.TextColor3
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.TextSize = self.TextSize
	textLabel.TextStrokeTransparency = 1

	return textLabel
end

-- Strip ending punctuation which screws with roblox's wordwrapping and .TextFits
function MarkdownRender:_renderParagraphLabel(label, text)
	local labelWidth = label.Size.X.Scale*self._width + label.Size.X.Offset

	local strippedText = string.gsub(text, "(%p+)$", "")
	local textSize = TextService:GetTextSize(strippedText, label.TextSize, label.Font,
		Vector2.new(labelWidth, label.TextSize*20))

	label.Size = UDim2.new(label.Size.X, UDim.new(0, textSize.Y))
	label.Text = text

	return label
end

function MarkdownRender:_renderParagraph(text, options)
	options = options or {}

	local label = self:_getTextLabel()
	label.Text = text
	label.Name = "Paragraph"
	label.Parent = options.Parent or self._gui

	self:_renderParagraphLabel(label, text)

	return label
end

function MarkdownRender:_getBullet(level)
	local bullet = Instance.new("Frame")
	bullet.Name = "bullet"
	bullet.BorderSizePixel = 0

	bullet.BackgroundColor3 = self.TextColor3
	bullet.ZIndex = self._gui.ZIndex

	if level == 2 then
		bullet.Size = UDim2.new(0, 6, 0, 1)
	else
		bullet.Size = UDim2.new(0, 4, 0, 4)
	end

	return bullet
end

function MarkdownRender:_renderList(listData)
	assert(type(listData.Level) == "number" and listData.Level > 0, "Bad listData")

	local frame = self:_getFrame()
	frame.Name = string.format("List_%d", listData.Level)
	frame.Size = UDim2.new(1, -(listData.Level)*self.Indent, 0, 0)
	frame.Position = UDim2.new(0, -frame.Size.X.Offset, 0, 0)
	frame.Parent = self._gui

	local height = 0
	for index, text in ipairs(listData) do
		local textLabel = self:_renderParagraph(text, { Parent = frame })
		textLabel.Name = string.format("%d_%s", index, textLabel.Name)
		textLabel.Position = UDim2.new(textLabel.Position.X, UDim.new(0, height))

		local bullet = self:_getBullet(listData.Level)
		bullet.AnchorPoint = Vector2.new(0.5, 0.5)
		bullet.Position = UDim2.new(0, -self.Indent/2, 0, self.TextSize/2 + 1)
		bullet.Parent = textLabel

		height = height + textLabel.Size.Y.Offset
		if index ~= #listData then
			height = height + self.SpaceBetweenList
		end
	end

	frame.Size = UDim2.new(frame.Size.X, UDim.new(0, height))

	return frame
end

function MarkdownRender:_renderHeader(headerData)
	local label = self:_getTextLabel()
	label.Name = "Header" .. headerData.Level
	label.TextSize = self.TextSize + (self.MaxHeaderLevel-headerData.Level)
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = self._gui
	label.Font = Enum.Font.SourceSansSemibold

	self:_renderParagraphLabel(label, headerData.Text)
	label.Size = UDim2.new(label.Size.X, UDim.new(label.Size.Y.Scale, label.Size.Y.Offset + 6)) -- Extra padding

	local underline = self:_getFrame()
	underline.Name = "Underline"
	underline.BackgroundTransparency = 0
	underline.BackgroundColor3 = Color3.new(0.9, 0.9, 0.9)
	underline.Size = UDim2.new(1, 0, 0, 1)
	underline.AnchorPoint = Vector2.new(0, 1)
	underline.Position = UDim2.new(0, 0, 1, 0)
	underline.Parent = label

	return label
end

return MarkdownRender