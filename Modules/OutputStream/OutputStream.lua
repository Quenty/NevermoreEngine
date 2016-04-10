local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

local qSystems       = LoadCustomLibrary("qSystems")
local Table          = LoadCustomLibrary("Table")
local RbxUtility     = LoadLibrary("RbxUtility")
local CircularBuffer = LoadCustomLibrary("CircularBuffer")
local Signal         = LoadCustomLibrary("Signal")
local RemoteManager  = LoadCustomLibrary("RemoteManager")

local Class = qSystems.Class

local lib = {}

--[[-- Change Log
November 17th, 2014
- Removed importing

January 27th, 2014
- Fixed logging
- Added change log

January 26th, 2014
- Initial rewrite


--]]

--[[
This is an improved version of RenderStream, and focuses upon improving the
reliability of the program, as well as the flexibility. 

Logging and Filtering
- Subscription services?


HOW IT WORKS
------------

Stuff is classified by how it's suppose to display. That is, each "display item" has three different things
- Parser
- Render

Each Stream has it's own log, which also filters out players. 

Now, streams can (and will be) syndicated by the OutputStreamSyndicator (on the client).
Streams can thus filter out data, but also maintain a coherent "overview" on the client.

Streams can even be reused in different syndications (OutputStreamSyndicator) so admin logs, say
can go into a global server output log, and also into an admin log thing.

The thing is, the logger or whatever is on the server is still MAINTAINED per a stream per a class.

It's all very haxy and inefficient, maybe, but the only way I could figure out how to do it while
maintaining every single condition. 
--]]

local ParserUIDCounter = 0;

local function GetUID()
	--- Return's a UID (Unique ID) for the chat parser to use.
	ParserUIDCounter = ParserUIDCounter + 1
	return ParserUIDCounter
end

local MakeOutputParser = Class(function(OutputParser, Parse, Unparse)
	--- Parses and deparses data between transit. 
	-- @param Parse Lua function 
		-- Parse( Table `Data`)
			--- Returns a Table of the data to be sent over. Send back a new table, not the unparsed data. 
		-- Unparse( Table `Data`)
			--- Return's a Table of the deparsed data


	function OutputParser.Parse(OutputClassName, Data)
		--- Parses the Data into a packet, adds 3 elements.
		-- @return Data
			-- Data will have these items in it
			-- ClassName (String)
			-- UID (Number)
			-- TimeStamp (Number)
			-- Parsed (Table, parsed Data)

		Data.ClassName = OutputClassName
		Data.UID = GetUID()
		Data.TimeStamp = tick()

		local Parsed = Parse(Data)

		Parsed.ClassName = OutputClassName
		Parsed.UID = Data.UID
		Parsed.TimeStamp = Data.TimeStamp

		Data.Parsed = Parsed

		return Data
	end

	OutputParser.Unparse = Unparse
	-- Will simply mutate Data
end)
lib.MakeOutputParser = MakeOutputParser
lib.makeOutputParser = MakeOutputParser

local MakeOutputClass = Class(function(OutputClass, Name, Parser, Render)
	--- Represents a type of output to render. 
	
	OutputClass.Name = Name
	OutputClass.Parser = Parser
	OutputClass.Render = Render
end)
lib.MakeOutputClass = MakeOutputClass
lib.makeOutputClass = MakeOutputClass

local MakeOutputStreamServer = Class(function(OutputStreamServer, Logger, StreamName)
	--- Handles connections send and receive, and brings all the classes together.
	-- @param Logger A logger, should have the following properties.
		-- :GetLogs(Client)
		-- :LogData(Data)
		-- [:Sendable](Client, Data)
	-- OutputClassStreamLoggers.lua as some examples. 

	-- Client subscribes to any OutputStreamServer
	--  --> Updates get pushed to client. 

	OutputStreamServer.Name = StreamName

	local StreamRemoteFunction = RemoteManager:GetFunction("OutputStream/" .. StreamName)
	local StreamRemoteEvent = RemoteManager:GetEvent("OutputStream/" .. StreamName)

	local OutputClasses = {}

	local function GetOutputClass(OutputClassName)
		return OutputClasses[OutputClassName:lower()]
	end

	local function AddOutputClass(OutputClass)
		--- Adds the OutputClass to the system so it can be used. Could be called "Create" but it doesn't really create it.
		-- @param OutputClass The class itself. 

		local OutputClassName = OutputClass.Name

		if not GetOutputClass(OutputClassName) then
			OutputClasses[OutputClassName:lower()] = OutputClass
		else
			error("[OutputStreamServer] - StreamName " .. OutputClassName .. " is already registered. ")
		end
	end
	OutputStreamServer.AddOutputClass = AddOutputClass
	OutputStreamServer.addOutputClass = AddOutputClass

	local function Send(OutputClassName, Data)
		--- Constructs a new OutputStream item and then sends it to the appropriate places.

		local OutputClass = GetOutputClass(OutputClassName)
		if OutputClass then
			-- print("Filter list [0.5] @ Send " .. tostring(Data.FilterList) .. ", Data = " .. tostring(Data))
			OutputClass.Parser.Parse(OutputClassName, Data)
			assert(Data.Parsed ~= nil, "Data.Parsed is nil")
			-- print("Filter list [1] @ Send " .. tostring(Data.FilterList) .. ", Data = " .. tostring(Data))
			if Logger.Sendable then
				for _, Player in pairs(Players:GetPlayers()) do

					-- print("Filter list [2] @ Send " .. tostring(Data.FilterList) .. ", Data = " .. tostring(Data))
					if Logger:Sendable(Player, Data) then
						StreamRemoteEvent:SendToPlayer(Player, "Push", OutputClassName, Data.Parsed)
					end
				end
			else
				StreamRemoteEvent:SendToAllPlayers("Push", OutputClassName, Data.Parsed)
			end

			Logger:LogData(Data)
		else
			error("[OutputStreamServer] - OutputClass '" .. OutputClassName .. "' is not registered.")
		end
		-- print("Done sending data.")
	end
	OutputStreamServer.Send = Send
	OutputStreamServer.send = Send

	StreamRemoteFunction:Callback(function(Client, Request)
		-- print("[OutputStreamServer] - Returning log pull from Client " .. tostring(Client))
		if Request == "Pull" then
			return Logger:GetLogs(Client)
		else
			error("Unable to handle request '" .. Request .. "'")
		end
	end)
end)
lib.MakeOutputStreamServer = MakeOutputStreamServer
lib.makeOutputStreamServer = MakeOutputStreamServer

local MakeOutputStreamClient = Class(function(OutputStreamClient, StreamName)
	--- Manages connections, on the client, and subscriptions. Should be reconstructed after every reset. 
	-- @param StreamName The name of the Stream, string. Should be unique, as it will construct a new DataStream and EventStream from it.
	
	assert(type(StreamName) == "string", "[OutputStreamClient] - StreamName is a '" .. type(StreamName) .. "' tostring() == " .. tostring(StreamName))

	local StreamRemoteFunction = RemoteManager:GetFunction("OutputStream/" .. StreamName)
	local StreamRemoteEvent = RemoteManager:GetEvent("OutputStream/" .. StreamName)

	OutputStreamClient.Name = StreamName

	local OutputClasses = {}
	local OutputClassesSignals = {}

	OutputStreamClient.NewItem = Signal.new() --[[
	Fires with: OutputClass, Data
		--> OutputClass doesn't change.
		Data has the specific unparsed data.
			Data.ClientData = {} -- Created for storing stuff in rendering
			Data has been processed by the OutputClass automatically.
	]]

	local function GetOutputClass(OutputClassName)
		return OutputClasses[OutputClassName:lower()]
	end

	local function AddOutputClass(OutputClass)
		--- Adds the OutputClass to the system so it can be used. 
		-- @param OutputClass The class itself. 

		local OutputClassName = OutputClass.Name
		
		if not GetOutputClass(OutputClassName) then
			OutputClasses[OutputClassName:lower()] = OutputClass
		else
			error("[OutputStreamClient] - StreamName " .. OutputClassName .. " is already registered. ")
		end
	end
	OutputStreamClient.AddOutputClass = AddOutputClass
	OutputStreamClient.addOutputClass = AddOutputClass

	StreamRemoteEvent:Listen(function(Request, OutputClassName, Data)
		if Request == "Push" then
			assert(Data.TimeStamp ~= nil, "TimeStamp is nil")
	
			local OutputClass = GetOutputClass(OutputClassName)
			if OutputClass then
				Data.ClientData = {} -- Client data for rendering stuff.
	
				OutputClass.Parser.Unparse(Data)
				OutputStreamClient.NewItem:fire(OutputClass, Data)
			else
				warn("[OutputStreamClient] - No OutputStream class for '" .. tostring(OutputClassName) .. "'")
			end
		else
			error("Invalid request '" .. tostring(Request) .."'")
		end
	end)


	local function GetLogs()
		--- Takes all the logs from all the classes

		local Logs = StreamRemoteFunction:CallServer("Pull")
		if Logs then
			local UnparsedLogs = {}
			for Index, Item in pairs(Logs) do
				local Class = GetOutputClass(Item.ClassName)
				if Class then
					Item.ClientData = {}
					Class.Parser.Unparse(Item)
					UnparsedLogs[#UnparsedLogs+1] = {
						Data = Item;
						OutputClass = Class;
					}
				else
					warn("[OutputStreamClient] - Class '" .. Item.ClassName .. "' is not registered!")
				end
			end
			return UnparsedLogs, true
		else
			warn("[OutputStreamClient] - Could not retrieve logs! Logs were nil!")
			return {}, false
		end
	end
	OutputStreamClient.GetLogs = GetLogs
	OutputStreamClient.getLogs = GetLogs

	local function GetSortedLogs()
		--- Sorts by TimeStamp
		local UnparsedLogs, Success = GetLogs()
		table.sort(UnparsedLogs, function(A, B)
			return A.Data.TimeStamp < B.Data.TimeStamp
		end)
		return UnparsedLogs
	end
	OutputStreamClient.GetSortedLogs = GetSortedLogs
	OutputStreamClient.getSortedLogs = GetSortedLogs
end)
lib.MakeOutputStreamClient = MakeOutputStreamClient
lib.makeOutputStreamClient = MakeOutputStreamClient

-- _G.OutputSyndicatedLogs = {}
-- local LoggerDatabase = _G.OutputSyndicatedLogs

local MakeOutputStreamSyndicator = Class(function(OutputStreamSyndicator, Name, BufferSize)
	--- Managers multiple streams being synced into one. Caches data so chat loads fast on respawn. Used on the client only.
	-- @param Name The name of the Syndictator, purely for technical reasons. If no name is given, one will be generated.
	-- @param [BufferSize] Size of the Cached Buffer to use. 

	BufferSize = BufferSize or 100

	OutputStreamSyndicator.Name = Name or tostring("[ " .. OutputStreamSyndicator .." ]")
	local OutputStreams = {}
	OutputStreamSyndicator.NewItem = Signal.new()

	local function GetOutputStream(StreamName)
		return OutputStreams[StreamName:lower()]
	end

	local function AddOutputStream(OutputStreamClient)

		local OutputStreamClientName = OutputStreamClient.Name
		if not GetOutputStream(OutputStreamClientName) then
			OutputStreams[OutputStreamClientName] = OutputStreamClient

			OutputStreamClient.NewItem:connect(function(OutputClass, Data)
				OutputStreamSyndicator.NewItem:fire(OutputStreamClient, OutputClass, Data)
				-- CircularBuffer:Add(
				-- {
					-- Data        = Data;
					-- OutputClass = OutputClass;
				-- })
			end)
		else
			error("[OutputStreamSyndicator] - Cannot add OutputStreamClient '" .. OutputStreamClientName .. "' as is already is added. ")
		end
	end
	OutputStreamSyndicator.AddOutputStream = AddOutputStream
	OutputStreamSyndicator.addOutputStream = AddOutputStream

	local function GetSyndicatedLogs(NoCache)
		--- NOTE: CACHING NOT APPLIED

		--- Syndicates all the logs together and sorts by time stamp.
		-- @param NoCache Boolean, if true, does not use cached data. 
		-- @return CircularBuffer with the logs in it. 

		-- if NoCache or not LoggerDatabase[Name] then
			local LogList = {}
			for _, Item in pairs(OutputStreams) do
				local Logs = Item:GetLogs()
				for _, Item in pairs(Logs) do
					LogList[#LogList+1] = Item
				end
			end

			--- We have to sort if we get more results back than we need?
			table.sort(LogList, function(A, B)
				return A.Data.TimeStamp < B.Data.TimeStamp
			end)

			if #LogList > BufferSize then
				-- Cull list size.
				local NewList = {}

				for Index = #LogList, #LogList - 100, -1 do
					NewList[#NewList+1] = LogList[Index]
				end
				LogList = NewList

				return NewList
			end

			return LogList
			-- LoggerDatabase[Name] = CircularBuffer.new(BufferSize, LogList)
		-- end

		-- return LoggerDatabase[Name]
	end
	OutputStreamSyndicator.GetSyndicatedLogs = GetSyndicatedLogs
	OutputStreamSyndicator.getSyndicatedLogs = GetSyndicatedLogs
end)
lib.MakeOutputStreamSyndicator = MakeOutputStreamSyndicator
lib.makeOutputStreamSyndicator = MakeOutputStreamSyndicator

return lib
