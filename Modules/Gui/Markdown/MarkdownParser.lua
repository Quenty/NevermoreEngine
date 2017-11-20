-- Intent: Parses text into markdown
-- @author Quenty

local MarkdownParser = {}
MarkdownParser.__index = MarkdownParser
MarkdownParser.ClassName = "MarkdownParser"

function MarkdownParser.new(Text)
	local self = setmetatable({}, MarkdownParser)
	
	self.Text = Text or error("No Text")
	
	return self
end

function MarkdownParser:GetLines()
	local Lines = {}
	for Line in self.Text:gmatch("([^\r\n]*)[\r\n]") do
		table.insert(Lines, Line)
	end
	return Lines
end

function MarkdownParser:ParseList(OldLines)
	local Lines = {}
	local CurrentList
	
	for _, Line in pairs(OldLines) do
		local Space, Bullet, Text
	
		if type(Line) == "string" then
			Space, Bullet, Text = Line:match("^([ \t]*)([%-%*])%s*(.+)%s*$")
		end
		
		if Space and Bullet and Text then
			Space = Space:gsub("    ", "X")
			Space = Space:gsub(" ", "")
			Space = Space:gsub("\t", "X")
			local Level = #Space + 1
			
			if CurrentList and CurrentList.Level ~= Level then
				table.insert(Lines, CurrentList)
				CurrentList = nil
			end
			
			if CurrentList then
				table.insert(CurrentList, Text)
			else
				CurrentList = {}
				CurrentList.Level = Level
				CurrentList.Type = "List"
				
				table.insert(CurrentList, Text)
			end
		else
			if CurrentList then
				table.insert(Lines, CurrentList)
				CurrentList = nil
			end
			table.insert(Lines, Line)
		end
	end
	
	if CurrentList then
		table.insert(Lines, CurrentList)
		CurrentList = nil
	end
	
	return Lines
end
	
function MarkdownParser:ParseHeaders(OldLines)
	local Lines = {}
	
	for _, Line in pairs(OldLines) do
		local Hashtags, Text 
			
		if type(Line) == "string" then			
			Hashtags, Text = Line:match("^%s*([#]+)%s*(.+)%s*$")
		end
		
		local Level = Hashtags and #Hashtags
		if Text and Level and Level >= 1 and Level <= 5 then
			table.insert(Lines, {
				Type = "Header";
				Level = Level;
				Text = Text;
			})
		else
			table.insert(Lines, Line)
		end
	end
	
	return Lines
end

function MarkdownParser:ParseParagraphs(OldLines)
	local Lines = {}
	
	local CurrentParagraph
	for _, Line in pairs(OldLines) do
		if type(Line) == "table" then
			table.insert(Lines, Line)
		else
			if Line:match("[^%s]") then
				if CurrentParagraph then
					CurrentParagraph = CurrentParagraph .. " " .. Line
				else
					CurrentParagraph = Line
				end
			else
				if CurrentParagraph then
					table.insert(Lines, CurrentParagraph)
					CurrentParagraph = nil
				end
			end
		end
	end
	
	if CurrentParagraph then
		table.insert(Lines, CurrentParagraph)
		CurrentParagraph = nil
	end
		
	return Lines
end

function MarkdownParser:Parse()
	local Lines = self:GetLines()
	
	Lines = self:ParseList(Lines)
	Lines = self:ParseHeaders(Lines)
	Lines = self:ParseParagraphs(Lines) -- do this last
	
	return Lines
end

return MarkdownParser