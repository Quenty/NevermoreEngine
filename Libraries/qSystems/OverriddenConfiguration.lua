local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

qSystems:Import(getfenv(0));

-- OverriddenConfiguration.lua
-- @author Quenty
-- Last modified January 25th, 2014

--[[-- Change log
-- Janaurty 26th, 2014
- Added change log
- Updated so UserConfiguration may be nil

-- January 25th, 2014
- Wrote initial script

--]]
local lib = {}

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
end
lib.MakeOverridenConfiguration = MakeOverridenConfiguration
lib.makeOverridenConfiguration = MakeOverridenConfiguration
lib.New = MakeOverridenConfiguration
lib.new = MakeOverridenConfiguration

return lib