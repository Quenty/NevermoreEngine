local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local CircularBuffer    = LoadCustomLibrary("CircularBuffer")
local Table             = LoadCustomLibrary("Table")

qSystems:Import(getfenv(0));

local lib = {}

-- @author Quenty
-- OutputClassStreamLoggers.lua
-- This script handles some logging stuff for OutputStreams. 
-- Last modified January 26th, 2014

local MakeGlobalOutputStreamLog = Class(function(GlobalOutputStreamLog, BufferSize)
	--- Represents a "stream" that can be subscribbed too. Each stream has it's own way of
	-- logging data, and filtering it out towards clients. This stream is one that has no
	-- permissions system at all. 
	-- @param [BufferSize] Int, the size of the buffer. Defaults at 100

	-- Output streams can then be syndicated into one window. Windows will subscribe to output
	-- streams. 

		--[[
		Data Specification

		Data		
			string `Parsed`
				Parsed JSON, saved to the data. 
	--]]


	local Logs = CircularBuffer.New(BufferSize or 100)

	function GlobalOutputStreamLog:GetLogs(Client)
		--- Return's all the logs based upon the client.
		-- @param Client The client retrieving the logs for, can be used to filter out specific players, say
		--               on an admin log.
		-- @pre The data must have a variable called "Parsed" in it, before being logged.
		-- @return A table of parsed JSON logs. 

		local NewData = {}
		for _, Item in pairs(Logs:GetData()) do
			NewData[#NewData + 1] = Item.Parsed
		end
		return NewData
	end

	--[[function GlobalOutputStreamLog:Sendable(Client, Data)
		--- Figures out whether or not the data should be sent to the client. 
		-- @param Client The client to check
		-- @param Data The data to check
		-- @return Boolean true if it should be sent, false otherwise. 

		return true
	end--]]

	function GlobalOutputStreamLog:LogData(Data)
		--- Logs the Data into the Logs. 
		-- @param Data The data to log
		-- Data must contain "Parsed" data type.

		Logs:Add(Data)
	end
end)
lib.MakeGlobalOutputStreamLog = MakeGlobalOutputStreamLog
lib.makeGlobalOutputStreamLog = MakeGlobalOutputStreamLog

local MakePlayerNotificationStreamLog = Class(function(PlayerNotificationStreamLog, BufferSize)
	--- Like a GlobalOutputStreamLog, but it specifically filters it to certain players. It sends temporary
	-- notifications, and should be used to yell at players, but not log anything valuable. 
	-- @param [BufferSize] Int, the size of the buffer. Defaults at 100

	-- Technical issues can occur when the buffer get's killed, but it shouldn't matter at all, as
	-- logging here is trivial. 

	--[[
		Data Specification

		Data
			table `FilterList`
				number `userId` -- userId is preferred by 99999999%
				number `userId`
				...
				String `PlayerName`
				String `PlayerName`
				String `PlayerName`
				...

			boolean `Inclusive`
				If this boolean is true, then it will only send to players whose userId or name (Caps sensitive) is in the FilterList
				Otherwise, if it is false, it will send it to any player who is NOT in the filter list. 
			
			string `Parsed`
				Parsed JSON, saved to the data. 
	--]]

	local Logs = CircularBuffer.New(BufferSize or 100)

	function PlayerNotificationStreamLog:GetLogs(Client)
		--- Return's all the logs based upon the client.
		-- @param Client The client retrieving the logs for, can be used to filter out specific players, say
		--               on an admin log.
		-- @pre The data must have a variable called "Parsed" in it, before being logged.
		-- @return A table of parsed JSON logs. 

		local NewData = {}
		for _, Item in pairs(Logs:GetData()) do
			if PlayerNotificationStreamLog:Sendable(Client, Item) then
				NewData[#NewData+1] = Item.Parsed
			end
		end
		return NewData
	end

	function PlayerNotificationStreamLog:Sendable(Client, Data)
		--- Figures out whether or not the data should be sent to the client. 
		-- @param Client The client to check
		-- @param Data The data to check
		-- @return Boolean true if it should be sent, false otherwise. 

		if Data.FilterList then
			for _, Item in pairs(Data.FilterList) do
				if Item == Client or Item == Client.userId or Item == Client.Name then
					return Data.Inclusive
				end
			end
			return not Data.Inclusive
		else
			-- print("No filter list. " .. tostring(Data.FilterList) .. ", Data = " .. tostring(Data))
			error("[PlayerNotificationStreamLog] - Data does not have filter list")
		end
	end

	function PlayerNotificationStreamLog:LogData(Data)
		--- Logs the Data into the Logs. 
		-- @param Data The data to log
		-- Data must contain "Parsed" data type.

		-- print("Logging data, Data.FilterList = " .. tostring(Data.FilterList))
		Logs:Add(Data)
	end
end)
lib.MakePlayerNotificationStreamLog = MakePlayerNotificationStreamLog
lib.makePlayerNotificationStreamLog = MakePlayerNotificationStreamLog

local MakeFilteredLogStreamLog = Class(function(FilteredLogStreamLog, BufferSize)
	--- This class filters on a single unit basis. It's for admin logs and error logs that the general
	-- player should not see. 

	-- @param [BufferSize] Int, the size of the buffer. Defaults at 100

	-- Leaves the caching up the the Filter function. 

	local Logs = CircularBuffer.New(BufferSize or 100)

	function FilteredLogStreamLog:GetLogs(Client)
		--- Return's all the logs based upon the client.
		-- @param Client The client retrieving the logs for, can be used to filter out specific players, say
		--               on an admin log.
		-- @pre The data must have a variable called "Parsed" in it, before being logged.
		-- @return A table of parsed JSON logs. 

		local NewData = {}
		for _, Item in pairs(Logs:GetData()) do
			if FilteredLogStreamLog:Sendable(Client, Item) then
				NewData[#NewData+1] = Item.Parsed
			end
		end
		return NewData
	end

	function FilteredLogStreamLog:LogData(Data)
		--- Logs the Data into the Logs. 
		-- @param Data The data to log
		-- Data must contain "Parsed" data type.

		Logs:Add(Data)
	end

	function FilteredLogStreamLog:Sendable(Client, Data)
		--- Figures out whether or not the data should be sent to the client. 
		-- @param Client The client to check
		-- @param Data The data to check
		-- @return Boolean true if it should be sent, false otherwise. 

		return Data.Filter(Client)
	end
end)
lib.MakeFilteredLogStreamLog = MakeFilteredLogStreamLog
lib.makeFilteredLogStreamLog = MakeFilteredLogStreamLog

local MakeGlobalFilteredLogStreamLog = Class(function(FilteredLogStreamLog, Filter, BufferSize)
	--- This class filters on a "global" basis. It's for admin logs and error logs that the general
	-- player should not see. 
	-- @param Filter Function, indicates whether or not a player should be sent the data
		-- function `Filter` ( Player `Client` )
		-- @return boolean `ShouldSend` A boolean, if true, it should send the player the data. 

	-- @param [BufferSize] Int, the size of the buffer. Defaults at 100

	-- Leaves the caching up the the Filter function. 

	local Logs = CircularBuffer.New(BufferSize or 100)

	function FilteredLogStreamLog:GetLogs(Client)
		--- Return's all the logs based upon the client.
		-- @param Client The client retrieving the logs for, can be used to filter out specific players, say
		--               on an admin log.
		-- @pre The data must have a variable called "Parsed" in it, before being logged.
		-- @return A table of parsed JSON logs. 

		local NewData = {}
		for _, Item in pairs(Logs:GetData()) do
			if FilteredLogStreamLog:Sendable(Client, Item) then
				NewData[#NewData+1] = Item.Parsed
			end
		end
		return NewData
	end

	function FilteredLogStreamLog:LogData(Data)
		--- Logs the Data into the Logs. 
		-- @param Data The data to log
		-- Data must contain "Parsed" data type.

		Logs:Add(Data)
	end

	function FilteredLogStreamLog:Sendable(Client, Data)
		--- Figures out whether or not the data should be sent to the client. 
		-- @param Client The client to check
		-- @param Data The data to check
		-- @return Boolean true if it should be sent, false otherwise. 

		return Filter(Client)
	end
end)
lib.MakeGlobalFilteredLogStreamLog = MakeGlobalFilteredLogStreamLog
lib.makeGlobalFilteredLogStreamLog = MakeGlobalFilteredLogStreamLog

return lib