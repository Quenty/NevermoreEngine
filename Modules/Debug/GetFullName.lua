local find = string.find
local match = string.match
local gsub = string.gsub
local _GetFullName = script.GetFullName

local function GetFullName(Object)
	--- Gets the string of the directory of the object, in proper format
	-- Roblox's GetFullName isn't adequate enough

	local index = 0

	local function first()
		index = index + 1
		return index ~= 1
	end
	
	local function manipulateName(Name)
		local numberAtBeginning = find(Name, "^%d")
		if numberAtBeginning and Name == match(Name, "%d+") then
		-- Find a number at the beginning
		-- If it is just a number, we do not need brackets
			return "["..Name.."]"
		elseif numberAtBeginning or find(Name, "%s") then
			return "[\""..Name.."\"]"
		else
			return (first() and "." or "")..Name
		end
	end

	return (gsub(gsub(_GetFullName(Object), "Workspace", "workspace") .. ".", "(.-)%.", manipulateName))
end

return GetFullName
