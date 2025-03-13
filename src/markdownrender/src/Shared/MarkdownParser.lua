--[=[
	Parses text into markdown
	@class MarkdownParser
]=]

local MarkdownParser = {}
MarkdownParser.__index = MarkdownParser
MarkdownParser.ClassName = "MarkdownParser"

function MarkdownParser.new(text)
	local self = setmetatable({}, MarkdownParser)

	self._text = text or error("No text")

	return self
end

function MarkdownParser:GetLines()
	local lines = {}
	local text = self._text .. "\n" -- append extra line to force ending match
	for line in text:gmatch("([^\r\n]*)[\r\n]") do
		table.insert(lines, line)
	end
	return lines
end

function MarkdownParser:ParseList(oldLines)
	local lines = {}
	local currentList

	for _, line in oldLines do
		local space, bullet, text

		if type(line) == "string" then
			space, bullet, text = line:match("^([ \t]*)([%-%*])%s*(.+)%s*$")
		end

		if space and bullet and text then
			space = string.gsub(space, "    ", "X")
			space = string.gsub(space, " ", "")
			space = string.gsub(space, "\t", "X")
			local Level = #space + 1

			if currentList and currentList.Level ~= Level then
				table.insert(lines, currentList)
				currentList = nil
			end

			if currentList then
				table.insert(currentList, text)
			else
				currentList = {}
				currentList.Level = Level
				currentList.Type = "List"

				table.insert(currentList, text)
			end
		else
			if currentList then
				table.insert(lines, currentList)
				currentList = nil
			end
			table.insert(lines, line)
		end
	end

	if currentList then
		table.insert(lines, currentList)
	end

	return lines
end

function MarkdownParser:ParseHeaders(oldLines)
	local lines = {}

	for _, line in oldLines do
		local poundSymbols, text

		if type(line) == "string" then
			poundSymbols, text = line:match("^%s*([#]+)%s*(.+)%s*$")
		end

		local level = poundSymbols and #poundSymbols
		if text and level and level >= 1 and level <= 5 then
			table.insert(lines, {
				Type = "Header",
				Level = level,
				Text = text,
			})
		else
			table.insert(lines, line)
		end
	end

	return lines
end

function MarkdownParser:ParseParagraphs(oldLines)
	local lines = {}

	local currentParagraph
	for _, line in oldLines do
		if type(line) == "table" then
			table.insert(lines, line)
		else
			if line:match("[^%s]") then
				if currentParagraph then
					currentParagraph = currentParagraph .. " " .. line
				else
					currentParagraph = line
				end
			else
				if currentParagraph then
					table.insert(lines, currentParagraph)
					currentParagraph = nil
				end
			end
		end
	end

	if currentParagraph then
		table.insert(lines, currentParagraph)
	end

	return lines
end

-- Parses the given text into a list of lines
function MarkdownParser:Parse()
	local lines = self:GetLines()

	lines = self:ParseList(lines)
	lines = self:ParseHeaders(lines)
	lines = self:ParseParagraphs(lines) -- do this last

	return lines
end

return MarkdownParser