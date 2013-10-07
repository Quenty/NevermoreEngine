while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local Type              = LoadCustomLibrary('Type')

qSystems:Import(getfenv(0));

local lib = {}
local Logs = {}

local function AddSubDataLayer(DataName, Parent)
	-- For organization of data. Adds another configuration with the name "DataName", if one can't be found, and then returns it. 

	local DataContainer = Parent:FindFirstChild(DataName) or Make 'Configuration' {
		Name = DataName;
		Parent = Parent;
		Archivable = true;
	}

	return DataContainer
end
lib.AddSubDataLayer = AddSubDataLayer
lib.addSubDataLayer = AddSubDataLayer


local MakePersistantLog = class 'PersistantLog' (function(Log, LogContainer) -- Can already add a current log...
	-- Basically, you add a configuratino filled with whatever you want.  The format is up to you.  But this log is just
	-- a basic data structure to contain those, and access them, as well as make sure they exist. 
	Logs[LogContainer] = Log

	--print("[PersistantLog] - Log created @ "..LogContainer:GetFullName())

	Log.DataLengthMax = 30; -- How many log objects it will hold. 
	Log.ItemAdded = Make 'BindableEvent' {
		Name = "ItemAddedToLog";
		Archivable = false;
	}--CreateSignal()

	--[[ @ 3 as DataLengthMax

		3 : Quenty first says hi
		2 : Quenty then does this
		1 : Quenty finally did this.

		AddObject("Hello") --> Log objects all shift up. 

		3 : Quenty then does this
		2 : Quenty finally did this.
		1 : Hello

	--]]

	--[[local GetNextHighestIndex
	function GetNextHighestIndex(Value)
		print("Getting next highest @ " .. Value)
		wait(0.5)
		-- In case there's a missing value, this will return the next highest value, so it can be shifted down.

		Value = Value + 1;
		if Value > Log.DataLengthMax then
			return nil
		end

		local LogValue = LogContainer:FindFirstChild(Value)
		if LogValue then
			return LogValue
		else
			return GetNextHighestIndex(Value)
		end
	end--]]

	function Log:GetObjects()
		-- Returns all the objects in an array, newest ones first. 

		local Index = 1;
		local ReturnValues = {}
		local KeepSearching = true;

		while KeepSearching do
			local LogObjectForIndex = LogContainer:FindFirstChild(Index)
			if LogObjectForIndex then
				ReturnValues[Index] = LogObjectForIndex;
			else
				KeepSearching = false
			end

			Index = Index + 1;
			if Index >= Log.DataLengthMax then
				KeepSearching = false
			end
		end

		return ReturnValues
	end

	local ItemsToAdd = {}
	local IsProcessItems = false

	local ProcessItems
	function ProcessItems()
		-- Queue adding items into the system.  Make sure they get added in the correct order...

		if not IsProcessItems then
			IsProcessItems = true

			local Index = 1
			local DoStop = false

			while not DoStop do
				if Index > #ItemsToAdd then
					DoStop = true
				else
					local NewObject = ItemsToAdd[Index]
					--print("[PersistantLog] - Adding new object into log...")
					if NewObject then
						for _, Value in pairs(LogContainer:GetChildren()) do
							local ValuesValue = tonumber(Value.Name)
							if not ValuesValue then
								print("[PersistantLog] - Could not get number from value's name, destroying...")
								Value:Destroy()
							elseif ValuesValue >= Log.DataLengthMax then
								print("[PersistantLog] - Removing items out of bound @ "..Value.Name)
								Value:Destroy()
							else
								Value.Name = ValuesValue + 1;
							end
						end
						
						NewObject.Name = "1"
						NewObject.Parent = LogContainer
					else
						print("[PersistantLog] - NewObject in queue was nil...")
						DoStop = true
					end
				end
				Index = Index + 1
			end

			ItemsToAdd = {}
			--[[NewObject.Name = "1";
			NewObject.Parent = LogContainer;
			IsProcessItems = false--]]
			IsProcessItems = false
			if #ItemsToAdd >= 1 then
				ProcessItems()
			end
		else
			print("[PersistantLog] - Already processing items...")
		end
	end

	function Log:AddObject(Object) -- Object should probably be another configuration object, but could be a number value, etc. 
		table.insert(ItemsToAdd, Object)
		if not IsProcessItems then
			ProcessItems()
		else
			print("[PersistantLog] - Already processing items, will not process more...")
		end
	end

	LogContainer.ChildAdded:connect(function(Item)
		--[[if Item.Name == "1" then
			--print("[PersistantLog] - Object added to log (Script @ "..script:GetFullName().."), Log @ "..LogContainer:GetFullName())
			Log.ItemAdded:Fire(Item)
		else
			print("[PersistantLog] - Invalid item added to log (Name ~= 1), Name = '" .. Item.Name .."'")
		end--]]
		if tonumber(Item.Name) then
			Log.ItemAdded:Fire(Item)
		else
			print("[PersistantLog] - Invalid item added to log (Name ~= number), Name = '" .. Item.Name .."'")
		end
	end)

end)

local function GetPersistantLog(LogContainer)
	return Logs[LogContainer] or MakePersistantLog(LogContainer)
end
lib.GetPersistantLog = GetPersistantLog
lib.getPersistantLog = GetPersistantLog


lib.MakePersistantLog = MakePersistantLog
NevermoreEngine.RegisterLibrary('PersistantLog', lib)