-- OverriddenConfiguration.lua
-- @author Quenty
-- Last modified January 25th, 2014

--[[-- Change log

-- September 12th, 2014
- Added a deepcopyish system, metatable based. 

-- January 26th, 2014
- Added change log
- Updated so UserConfiguration may be nil

-- January 25th, 2014
- Wrote initial script

--]]
local lib = {}

local function ErrorOut()
	error("Cannot modify configuration!")
end

local function RecurseMakeOverridenConfiguration(UserConfiguration, DefaultConfiguration)
	--- Primary use is to allow a configuration without having to have every single default value. 

	-- NOTES: The UserConfiguration should not be modified (You may end up modifying DefaultConfiguration!) 
	-- NOTES: This will override the metatable on the UserConfiguration.
	-- NOTES: This will remove redundent information from the user configuration. 

	-- This is useful for sending data/configurations around networks as it allows you to send only data that is different.


	setmetatable(UserConfiguration, nil) --

	for Index, Value in pairs(DefaultConfiguration) do
		if UserConfiguration[Index] == Value then -- Remove unnecessary data.
			UserConfiguration[Index] = nil
		elseif type(Value) == "table" then
			if UserConfiguration[Index] == nil then
				UserConfiguration[Index] = {}
			elseif type(UserConfiguration[Index]) ~= "table" then
				error("User configuration had a non-table value in an index (" .. Index .. ") that should be a table")
			end
			--if UserConfiguration[Index] ~= nil then
				UserConfiguration[Index] = RecurseMakeOverridenConfiguration(UserConfiguration[Index], Value)
			--end
		end
	end

	setmetatable(UserConfiguration, {__index=DefaultConfiguration; __newindex=ErrorOut})

	return UserConfiguration

end

local function MakeOverridenConfiguration(UserConfiguration, DefaultConfiguration)
	UserConfiguration = UserConfiguration or {}

	if UserConfiguration ~= DefaultConfiguration then
		UserConfiguration = RecurseMakeOverridenConfiguration(UserConfiguration, DefaultConfiguration)
	else
		error("User configuration is equal to default configuration")
	end

	return UserConfiguration
end



local function RecurseAppendDefaultData(UserData, DefaultData)
	--- Primary use is to allow a data without having to have every single default value. Good for networking
	--- Will NOT wipe out existing values... will append.

	setmetatable(UserData, nil) --

	for Index, Value in pairs(DefaultData) do
		if UserData[Index] == Value then -- Remove unnecessary data.
			UserData[Index] = nil
		elseif type(Value) == "table" then
			if UserData[Index] == nil then
				UserData[Index] = {}
			elseif type(UserData[Index]) ~= "table" then
				error("User configuration had a non-table value in an index (" .. Index .. ") that should be a table")
			end
			--if UserData[Index] ~= nil then
				UserData[Index] = RecurseAppendDefaultData(UserData[Index], Value)
			--end
		end
	end

	setmetatable(UserData, {__index=DefaultData})

	return UserData

end

local function AppendDefaultData(UserData, DefaultData)
	UserData = UserData or {}

	if UserData ~= DefaultData then
		UserData = RecurseAppendDefaultData(UserData, DefaultData)
	else
		error("User configuration is equal to default configuration")
	end

	return UserData
end



--[[
local function MakeOverridenConfiguration(UserConfiguration, DefaultConfiguration)
	--- Makes a configuration that can be overridden be a user when constructing. Shallow update.
	-- @param UserConfiguration Table. The configuration that the user provides. May be incomplete or empty.
	-- @param DefaultConfiguration Table. The default configuration. 
	
	if UserConfiguration then
		local NewTable = {}

		for Index, Value in pairs(DefaultConfiguration) do
			if UserConfiguration[Index] then
				NewTable[Index] = UserConfiguration[Index]
			else
				NewTable[Index] = Value
			end
		end

		return NewTable
	else
		return DefaultConfiguration
	end
end--]]

lib.MakeOverridenConfiguration = MakeOverridenConfiguration
lib.makeOverridenConfiguration = MakeOverridenConfiguration
lib.New                        = MakeOverridenConfiguration
lib.new                        = MakeOverridenConfiguration

lib.AppendDefaultData = AppendDefaultData

return lib