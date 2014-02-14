local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local EventGroup        = LoadCustomLibrary("EventGroup")
local BoxInventory      = LoadCustomLibrary("BoxInventory")
local qInstance         = LoadCustomLibrary("qInstance")

qSystems:Import(getfenv(0))


-- BoxInventoryManager.lua
-- This script handles the networking side of the inventory system. Basically, it makes sure events replicate correctly.

-- @author Quenty

--[[ -- Change Log --
Febrary 13th, 2014
v.1.1.1
- Made inventory remove on client, and then send request, on retreival, if it fails then it
  adds it back in .
- Added save and load functions

February 7th, 2014
v.1.1.0
- Added IsUIDRegistered function
- Added GetInventoryName function
- Fixed error with addition to ItemList on client.

v.1.0.0
- Initial script written
- Added change log
--]]

local lib = {}

local MakeBoxInventoryServerManager = Class(function(BoxInventoryServerManager, Player, StreamName)
	--- Create one per a player. StreamName should be unique per a player (I think?)
	-- @param Player The player to make the stream for
	-- @param StreamName The name of the stream

	-- Get raw stream data.
	local RemoteFunction  = NevermoreEngine.GetDataStreamObject(StreamName)
	local RemoteEvent = NevermoreEngine.GetEventStreamObject(StreamName)

	local Managers = {}

	local function AddInventoryToManager(BoxInventory, InventoryUID)
		-- @param BoxInventory The BoxInventory to send events for.
		-- @param InventoryUID String, the UID to associate the inventory with.

		local Events = EventGroup.MakeEventGroup() -- We'll manage events like this.

		local InventoryManager = {} -- Returned object
		InventoryManager.UID = InventoryUID
		InventoryManager.Updated = CreateSignal() -- Whenever it updates. Suppose to be used as a hook to save the inventory.

		local function FireEventOnClient(EventName, ...)
			--- Fires the event on the client with the EventName given. Used internally.
			-- @param EventName String, the name of the event. 

			RemoteEvent:FireClient(Player, InventoryUID, EventName, ...)
		end

		-- SAVING UTILITY STUFF --
		local function ValidateData(OldValue)
			if OldValue and OldValue.SaveVersion == "1.0" and type(OldValue.TimeStamp) == "number" and type(OldValue.Items) == "table" then
				return true
			else
				
				if OldValue then
					print("OldValue.SaveVersion == " .. tostring(OldValue.SaveVersion) .. "; type(OldValue.TimeStamp) == '" .. type(OldValue.TimeStamp) .."'; type(OldValue.Items) == '" .. type(OldValue.Items) .."'")
				else
					print("OldValue is " .. tostring(OldValue))
				end
				return false
			end
		end

		local function UpdateSaveInventory(OldValue)
			-- Utility function used by SaveInventory, updated inventory.
			-- Meant to be caled by DataStore:UpdateAsync's function thingy

			return {
				Items       = InventoryManager.GetListOfItems();
				TimeStamp   = tick();
				SaveVersion = "1.0";
			}
		end

		local function SaveInventory(DataStore, Key)
			-- @param DataStore The DataStore to load from
			-- @param Key The key to use when loading.

			if DataStore then
				DataStore:UpdateAsync(Key, UpdateSaveInventory)
			else
				print("[InventoryManager] - No Datastore provided, cannot save")
			end
		end
		InventoryManager.SaveInventory = SaveInventory
		InventoryManager.saveInventory = SaveInventory

		local function LoadValidData(ItemSystem, InventoryData)
			for _, Data in pairs(InventoryData.Items) do
				if type(Data.classname) == "string" and Data.uid then
					local NewConstruct = ItemSystem.ConstructClassFromData(Data)
					if NewConstruct then

						-- Add item, make sure we can add it.
						local DidAdd = BoxInventory.AddItem(NewConstruct, nil, true)

						if not DidAdd then
							print("[ItemSystem][LoadInventory] - Inventory failed to add item")
						end
					else
						print("[ItemSystem][LoadInventory] - Unable to construct new Item class '" .. Item.classname .."'")
					end
				end
			end

			-- We set it to not sort on add. Now we sort!
			BoxInventory.DeepSort()
		end

		local function LoadInventory(ItemSystem, DataStore, Key)
			--- Load's the inventory. Only call once nubs.
			-- @param DataStore The DataStore to load from
			-- @param Key The Key to use when loading

			if DataStore then
				local InventoryData = DataStore:GetAsync(Key)
				if ValidateData(InventoryData) then
					LoadValidData(ItemSystem, InventoryData)
				else
					print("[InventoryManager][LoadInventory] - Invalid data from datastore given.")
				end
			else
				print("[InventoryManager] - No Datastore provided, cannot save")
			end
		end
		InventoryManager.LoadInventory = LoadInventory
		InventoryManager.loadInventory = LoadInventory
		
		-- OTHER METHODS --

		local function Destroy()
			--- Destroy's the InventoryManager

			-- Tell the client the inventory is disconnecting
			FireEventOnClient(EventName, "InventoryRemoving")
			InventoryManager.Updated:Destroy()
			Events("Clear")
			Events = nil
			InventoryManager.Destroy = nil
			FireEventOnClient = nil
			Managers[InventoryUID] = nil
		end
		InventoryManager.Destroy = Destroy
		InventoryManager.destroy = Destroy

		-- VALID REQUESTS --
		local function GetListOfItems()
			--- Return's a list of items in the inventory
			--- Only returns the Data, nothing more.
			--- Used by the networking side of this.

			local Items = BoxInventory.GetListOfItems()
			local ParsedItems = {}

			for _, Item in pairs(Items) do
				-- print("[BoxInventoryClientManager] - Item.Data = " .. tostring(Item.Data))
				ParsedItems[#ParsedItems+1] = Item.Content.Data
			end

			return ParsedItems
		end
		InventoryManager.GetListOfItems = GetListOfItems
		InventoryManager.getListOfItems = GetListOfItems

		local function GetInventoryName()
			-- Return's the inventories name. Used internally

			return BoxInventory.Name
		end
		InventoryManager.GetInventoryName = GetInventoryName
		InventoryManager.getInventoryName = GetInventoryName

		local function GetLargestGridSize()
			-- Get's the largest grid size. Used internally

			return BoxInventory.LargestGridSize
		end
		InventoryManager.GetLargestGridSize = GetLargestGridSize
		InventoryManager.getLargestGridSize = GetLargestGridSize

		local function RemoveItemFromInventory(UID)
			-- Remove's the item with the UID (Unique Identifier), from the inventory. Used internally.
			if UID then
				local Items = BoxInventory.GetListOfItems()
				for _, ItemSlot in pairs(Items) do
					local Item = ItemSlot.Content
					if Item.UID == UID then
						Item.Interfaces.BoxInventory.RemoveSelfFromInventory()
						return true
					end
				end
				print("[BoxInventoryServerManager] - Unable to find item with UID '" .. UID .. "'")
				return false
			else
				error("[BoxInventoryServerManager] - UID is '" .. tostring(UID) .."'")
			end
		end
		InventoryManager.RemoveItemFromInventory = RemoveItemFromInventory
		InventoryManager.removeItemFromInventory = RemoveItemFromInventory

		-- Setup actual events --
		Events.ItemAdded = BoxInventory.ItemAdded:connect(function(Item, Slot)
			-- We won't (and can't) send the slot. Only the ItemData is safe. 
			InventoryManager.Updated:fire()
			FireEventOnClient("ItemAdded", Item.Data)
		end)
		Events.ItemRemoved = BoxInventory.ItemRemoved:connect(function(Item, Slot)
			-- We won't (and can't) send the slot. Only the ItemData is safe.  Client side will interpret based on UID to remove the correct item.
			InventoryManager.Updated:fire()
			FireEventOnClient("ItemRemoved", Item.Data)
		end)

		-- Make sure we aren't killing a manager.
		if Managers[InventoryUID] ~= nil then
			error("[BoxInventoryServerManager] A manager with the UID of '" .. InventoryUID .. "' already exists!")
		end

		Managers[InventoryUID] = InventoryManager
		return InventoryManager
	end
	BoxInventoryServerManager.AddInventoryToManager = AddInventoryToManager
	BoxInventoryServerManager.addInventoryToManager = AddInventoryToManager

	local function RemoveInventoryFromManager(InventoryUID)
		Managers[InventoryUID]:Destroy()
	end


	-- List of requests that can be called to a manager.
	local ValidRequests = {
		GetListOfItems          = true;
		GetInventoryName        = true;
		GetLargestGridSize      = true;
		RemoveItemFromInventory = true;
	}

	RemoteFunction.OnServerInvoke = function(Requester, InventoryUID, Request, ...)
		-- Fix networking problems on SoloTestMode
		if NevermoreEngine.SoloTestMode then
			Requester = Players:GetPlayers()[1]
		end

		if Requester == Player then
			if InventoryUID then
				if ValidRequests[Request] then
					if Managers[InventoryUID] then
						return Managers[InventoryUID][Request](...)
					else
						error("[BoxInventoryServerManager] - An inventory with the UID '" .. InventoryUID .. "' does not exist!")
					end
				elseif Request == "IsUIDRegistered" then
					return (Managers[InventoryUID] ~= nil)
				else
					error("[BoxInventoryServerManager] - Invalid request '" .. tostring(Request) .."' !")
				end
			else
				error("[BoxInventoryServerManager] - InventoryUID is nil or false")
			end
		else
			error("[BoxInventoryServerManager] - RemoteFunction.OnServerInvoke, Requester (" .. tostring(Requester) .. ") ~= Player (" .. tostring(Player) ..").")
		end
	end

	local function Destroy()
		--- GC's the overall Manager

		for UID, Manager in pairs(Managers) do
			Manager:Destroy()
		end

		RemoteFunction.OnServerInvoke = nil
		RemoteEvent:Destroy()
		RemoteFunction:Destroy()
	end
	BoxInventoryServerManager.Destroy = Destroy
	BoxInventoryServerManager.destroy = Destroy
end)
lib.MakeBoxInventoryServerManager = MakeBoxInventoryServerManager
lib.makeBoxInventoryServerManager = MakeBoxInventoryServerManager

local CrateDataCache = {}

local MakeBoxInventoryClientManager = Class(function(BoxInventoryClientManager, Player, StreamName, ItemSystem)
	local RemoteFunction = NevermoreEngine.GetDataStreamObject(StreamName)
	local RemoteEvent    = NevermoreEngine.GetEventStreamObject(StreamName)

	local Inventories = {}

	local function MakeClientInventoryInterface(InventoryUID)
		-- print("[BoxInventoryClientManager] - Registering ClientInventoryInterface '" .. InventoryUID .."'")
		
		--- Connects to the server system, and makes an inteface that can be interaced with.
		-- Tracks only the items in the current inventory, so duplicates *may* exist if removal occurs.
		-- Removal should only occur on serverside.. 

		local InventoryInterface = {}
		InventoryInterface.UID         = InventoryUID
		InventoryInterface.Interfaces  = {} -- Client side Interfaces linker.
		
		InventoryInterface.ItemAdded   = CreateSignal()
		InventoryInterface.ItemRemoved = CreateSignal()

		local Events = EventGroup.MakeEventGroup() -- We'll manage events like this.
		local ItemList = {}

		while not RemoteFunction:InvokeServer(InventoryUID, "IsUIDRegistered") do
			print("[BoxInventoryClientManager] - Waiting for server to register UID '" .. InventoryUID .."'")
			wait(0)
		end

		InventoryInterface.Name            = RemoteFunction:InvokeServer(InventoryUID, "GetInventoryName")
		InventoryInterface.LargestGridSize = RemoteFunction:InvokeServer(InventoryUID, "GetLargestGridSize")
		
		-- Methods --
		local function Destroy()
			Events("Clear")
			Events = nil
			InventoryInterface.UID            = nil
			InventoryInterface.Destroy        = nil
			InventoryInterface.GetListOfItems = GetListOfItems
			Inventories[InventoryUID]         = nil

			InventoryInterface.ItemAdded:destroy()
			InventoryInterface.ItemRemoved:destroy()

			InventoryInterface.ItemAdded   = nil
			InventoryInterface.ItemRemoved = nil
		end
		InventoryInterface.Destroy = Destroy
		InventoryInterface.destroy = Destroy

		local function GetItemFromData(ItemData)
			--- Searches ItemList for an item with the same UID
			-- @return The item found, if it is found,
			--         boolean found.

			local UID = ItemData.uid

			for _, Item in pairs(ItemList) do
				if Item.UID == UID then
					return Item, true
				end
			end

			return nil, false
		end

		local OnItemRemove
		local OnItemAdd

		local function AddInterfacesToItem(ItemData, Constructed)
			--- Addes interfaces to an item
			-- @param ItemData The item data
			-- @param Constructed The newly constructed item

			local BoxInventoryManagerInterface = {} do
				BoxInventoryManagerInterface.PendingRemoval = false

				local function RemoveItemFromInventory()
					-- You have no idea how inefficient this is...

					if not BoxInventoryManagerInterface.PendingRemoval then
						OnItemRemove(ItemData)
						BoxInventoryManagerInterface.PendingRemoval = true
						local DidRemove = {RemoteFunction:InvokeServer(InventoryUID, "RemoveItemFromInventory", Constructed.UID)}
						if not DidRemove then
							print("[BoxInventoryClientManager] - Data failed to remove, adding back to inventory")

							OnItemAdd(ItemData)
							BoxInventoryManagerInterface.PendingRemoval = false
						end
						return DidRemove
					end
				end
				BoxInventoryManagerInterface.RemoveItemFromInventory = RemoveItemFromInventory
			end
			Constructed.Interfaces.BoxInventoryManager = BoxInventoryManagerInterface

			local BoxInventoryInterface = {} do
				BoxInventoryInterface.CrateData = CrateDataCache[Constructed.Model] 

				if not BoxInventoryInterface.CrateData then
					if Constructed.Model then
						BoxInventoryInterface.CrateData = BoxInventory.GenerateCrateData(qInstance.GetBricks(Constructed.Model))
						CrateDataCache[Constructed.Model] = BoxInventoryInterface.CrateData
					else
						error("[BoxInventoryClientManager] - BoxInventory requires all items to have a 'Model'")
					end
				end

				BoxInventoryInterface.RemoveSelfFromInventory = BoxInventoryManagerInterface.RemoveItemFromInventory
			end
			Constructed.Interfaces.BoxInventory = BoxInventoryInterface
		end

		local function DeparseItemData(ItemData)
			--- Deparses the item into a valid item. If the item already exists, will return it.
			-- @param ItemData The item data
			-- @return The deparsed item. True if it already was in the system, false if it wasn't

			if not ItemData.uid then
				error("[BoxInventoryClientManager] - Cannot deparse, no UID")
			end

			-- Make sure item does not exist already...
			local Item, ItemFound = GetItemFromData(ItemData)
			if ItemFound then
				return Item, true
			else
				local Constructed = ItemSystem.ConstructClassFromData(ItemData)

				AddInterfacesToItem(ItemData, Constructed)

				return Constructed, false
			end
		end

		local function GetListOfItems(DoNotNetwork)
			--- Return's a list of items in the inventory. 
			local List = RemoteFunction:InvokeServer(InventoryUID, "GetListOfItems")
			if List then
				local ListOfItems = {}

				for _, ItemData in pairs(List) do
					local Item, IsNewItem = DeparseItemData(ItemData)
					ListOfItems[#ListOfItems+1] = Item
					if IsNewItem then
						InventoryInterface.ItemAdded:fire(NewItem)
					end
				end

				ItemList = ListOfItems
				return ListOfItems
			else
				print("[BoxInventoryClientManager] - Failed to retrieve item list")
			end
		end
		InventoryInterface.GetListOfItems = GetListOfItems
		InventoryInterface.getListOfItems = GetListOfItems

		function OnItemAdd(ItemData)
			local NewItem, AlreadyInSystem = DeparseItemData(ItemData)
			if not AlreadyInSystem then
				ItemList[#ItemList+1] = NewItem
				InventoryInterface.ItemAdded:fire(NewItem)
			else
				print("[BoxInventoryClientManager][OnItemAdd] - Item " .. ItemData.classname .. " UID '" .. ItemData.uid .. "'' already exists in the inventory")
			end
		end

		function OnItemRemove(ItemData)
			local Item, AlreadyInSystem = GetItemFromData(ItemData)
			if AlreadyInSystem then
				if not Item.Interfaces.BoxInventoryManager.PendingRemoval then
					InventoryInterface.ItemRemoved:fire(Item)
				else
					print("[BoxInventoryClientManager][OnItemRemove] - Item " .. ItemData.classname .. "@" .. ItemData.uid .. " is pending removal. Removal confirmed, setting PendingRemoval to false")
					Item.Interfaces.BoxInventoryManager.PendingRemoval = false
				end
			else 
				print("[BoxInventoryClientManager][OnItemRemove] - Item " .. ItemData.classname .. "@" .. ItemData.uid .. " was not in the inventory. ")
			end
			
		end

		local function HandleNewEvent(EventName, ...)
			--- Handles new events that update the inventory

			-- print("[BoxInventoryClientManager] - New event '" .. EventName .."' fired")
			if EventName == "ItemAdded" then
				OnItemAdd(...)
			elseif EventName == "ItemRemoved" then
				OnItemRemove(...)
			else
				print("[BoxInventoryClientManager] - No event linked to '" .. tostring(EnventName) .. "'")
			end
		end
		InventoryInterface.HandleNewEvent = HandleNewEvent
		InventoryInterface.handleNewEvent = HandleNewEvent

		-- Update list --
		GetListOfItems()

		if Inventories[InventoryUID] then
			error("[BoxInventoryClientManager] - An inventory with the UID '" .. InventoryUID .. "' already exists.")
		else
			Inventories[InventoryUID] = InventoryInterface
		end
		return Inventories[InventoryUID]
	end
	BoxInventoryClientManager.MakeClientInventoryInterface = MakeClientInventoryInterface
	BoxInventoryClientManager.makeClientInventoryInterface = MakeClientInventoryInterface

	local ClientEventConnection = RemoteEvent.OnClientEvent:connect(function(InventoryUID, EventName, ...)
		if InventoryUID then
			local InventoryInterface = Inventories[InventoryUID]
			if InventoryInterface then
				InventoryInterface.HandleNewEvent(EventName, ...)
			else
				print("[BoxInventoryClientManager] - No InventoryInterface exists with UID of '" .. tostring(InventoryUID) .."'")
			end
		else
			print("[BoxInventoryClientManager] - InventoryUID is not correct, is '" .. tostring(InventoryUID) .."'")
		end
	end)

	local function Destroy()
		-- Destroys the BoxInventoryClientManager, cannot destroy connection objects.

		ClientEventConnection:disconnect()
		ClientEventConnection = nil

		for _, InventoryInterface in pairs(Inventories) do
			InventoryInterface:Destroy()
		end
		Inventories = nil
		BoxInventoryClientManager.Destroy = nil
	end
	BoxInventoryClientManager.Destroy = Destroy
	BoxInventoryClientManager.destroy = Destroy
end)
lib.MakeBoxInventoryClientManager = MakeBoxInventoryClientManager
lib.makeBoxInventoryClientManager = MakeBoxInventoryClientManager

return lib