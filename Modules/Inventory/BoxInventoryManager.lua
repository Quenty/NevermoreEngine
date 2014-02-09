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
		local InventoryManager = {}
		InventoryManager.UID = InventoryUID

		local function FireEventOnClient(EventName, ...)
			--- Fires the event on the client with the EventName given. Used internally.
			-- @param EventName String, the name of the event. 

			RemoteEvent:FireClient(Player, InventoryUID, EventName, ...)
		end
		
		local function Destroy()
			--- Destroy's the InventoryManager

			-- Tell the client the inventory is disconnecting
			FireEventOnClient(EventName, "InventoryRemoving")

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

			FireEventOnClient("ItemAdded", Item.Data)
		end)
		Events.ItemRemoved = BoxInventory.ItemRemoved:connect(function(Item, Slot)
			-- We won't (and can't) send the slot. Only the ItemData is safe.  Client side will interpret based on UID to remove the correct item.

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

				if not Constructed.Interfaces.BoxInventory then
					local NewInterface = {}
					NewInterface.CrateData = CrateDataCache[Constructed.Model] 

					if not NewInterface.CrateData then
						if Constructed.Model then
							NewInterface.CrateData = BoxInventory.GenerateCrateData(qInstance.GetBricks(Constructed.Model))
							CrateDataCache[Constructed.Model] = NewInterface.CrateData
						else
							error("[BoxInventoryClientManager] - BoxInventory requires all items to have a 'Model'")
						end
					end

					function NewInterface.RemoveSelfFromInventory()
						-- You have no idea how inefficient this is...

						return RemoteFunction:InvokeServer(InventoryUID, "RemoveItemFromInventory", Constructed.UID)
					end
					
					Constructed.Interfaces.BoxInventory = NewInterface
				end 

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

		local function OnItemAdd(ItemData)
			local NewItem, AlreadyInSystem = DeparseItemData(ItemData)
			if not AlreadyInSystem then
				ItemList[#ItemList+1] = NewItem
				InventoryInterface.ItemAdded:fire(NewItem)
			else
				print("[BoxInventoryClientManager][OnItemAdd] - Item " .. ItemData.classname .. " UID '" .. ItemData.uid .. "'' already exists in the inventory")
			end
		end

		local function OnItemRemove(ItemData)
			local Item, AlreadyInSystem = GetItemFromData(ItemData)
			if AlreadyInSystem then
				InventoryInterface.ItemRemoved:fire(Item)
			else
				print("[BoxInventoryClientManager][OnItemRemove] - Item " .. ItemData.classname .. "@" .. ItemData.uid .. " was not in the inventory.")
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
	BoxInventoryClientManager.MakeClientInventoryInterface = MakeClientInventoryInterface

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