local ReplicatedStorage       = game:GetService("ReplicatedStorage")
local Players                 = game:GetService("Players")

local NevermoreEngine         = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary       = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local qInstance               = LoadCustomLibrary("qInstance")
local qString                 = LoadCustomLibrary("qString")
local qCFrame                 = LoadCustomLibrary("qCFrame")
local OverriddenConfiguration = LoadCustomLibrary("OverriddenConfiguration")
local EventGroup              = LoadCustomLibrary("EventGroup")

qSystems:Import(getfenv(0));

-- AreaLoader.lua
-- Handles building loading and management. Handles it server-side. 
-- @author Quenty

local lib = {}

local MakeGridManager = Class(function(GridManager, Center, StudsPerGridSquare, Rows, Columns)
	local Grid = {}

	-- Generate grid.
	for Row = 1, Rows do
		Grid[Row] = {}
	end

	local function GetOpenSlotPosition()
		--- Return's a Vector2 of the location that is open, if one is open
		--  Otherwise, return's nil

		for Row = 1, Rows do
			local RowData = Grid[Row]
			for Column = 1, Columns do
				if RowData[Column] == nil then
					return Vector2.new(Row, Column)
				end
			end
		end
		return nil
	end
	GridManager.GetOpenSlotPosition = GetOpenSlotPosition
	GridManager.getOpenSlotPosition = GetOpenSlotPosition

	local function GetListOfFilledSlots()
		--- Get's a list of all filled slots

		local List = {}

		for Row = 1, Rows do
			local RowData = Grid[Row]
			for Column = 1, Columns do
				if RowData[Column] ~= nil then
					List[#List+1] = RowData[Column]
				end
			end
		end

		return List
	end
	GridManager.GetListOfFilledSlots = GetListOfFilledSlots
	GridManager.getListOfFilledSlots = GetListOfFilledSlots

	local function GetListOfOpenSlots()
		-- Return's list of slots that are open

		local List = {}

		for Row = 1, Rows do
			local RowData = Grid[Row]
			for Column = 1, Columns do
				if RowData[Column] == nil then
					List[#List+1] = RowData[Column]
				end
			end
		end

		return List
	end
	GridManager.GetListOfOpenSlots = GetListOfOpenSlots
	GridManager.getListOfOpenSlots = GetListOfOpenSlots

	local function SlotInBounds(SlotLocation)
		local RowIndex = SlotLocation.X
		local ColumnIndex = SlotLocation.Y

		if RowIndex >= 1 and RowIndex <= Rows then
			if ColumnIndex >= 1 and ColumnIndex <= Columns then
				return true
			end
		end

		return false
	end
	GridManager.SlotInBounds = SlotInBounds
	GridManager.slotInBounds = SlotInBounds

	local function IsSlotOpen(SlotLocation)
		-- @param SlotLocation Vector2, the location of the slot.

		if SlotInBounds(SlotLocation) then
			return Grid[SlotLocation.X][SlotLocation.Y] == nil
		else
			return false
		end
	end
	GridManager.IsSlotOpen = IsSlotOpen
	GridManager.isSlotOpen = IsSlotOpen

	local function AddItemToSlot(SlotLocation, Item)
		--- Adds the item to the slot. 
		-- @param SlotLocation Vector2, the location of the slot.
		-- @param Item The item to add to it. Can be anything except nil.

		if IsSlotOpen(SlotLocation) then
			Grid[SlotLocation.X][SlotLocation.Y] = Item
			return true
		else
			error("[GridManager] - Slot is not open, cannot add to it")
			return false
		end
	end
	GridManager.AddItemToSlot = AddItemToSlot
	GridManager.addItemToSlot = AddItemToSlot

	local function RemoteItemFromSlot(SlotLocation)
		if SlotInBounds(SlotLocation) then
			if IsSlotOpen(SlotLocation) then
				local Removed = Grid[SlotLocation.X][SlotLocation.Y]
				if Removed then
					Grid[SlotLocation.X][SlotLocation.Y] = nil
					return Removed
				else
					error("[GridManager] - Slot did not have any content!")
				end
			end
		else
			error("[GridManager] - Slot is not in bounds. Obviously cannot remove from it.")
		end
	end
	GridManager.RemoteItemFromSlot = RemoteItemFromSlot
	GridManager.remoteItemFromSlot = RemoteItemFromSlot

	local function SlotLocationToWorldLocation(SlotLocation)
		local CenteredSlotLocation = (SlotLocation - (Vector2.new(Rows, Columns)/2))
		return (Center + Vector3.new(CenteredSlotLocation.X * StudsPerGridSquare, 0, CenteredSlotLocation.Y * StudsPerGridSquare))
	end
	GridManager.SlotLocationToWorldLocation = SlotLocationToWorldLocation
	GridManager.slotLocationToWorldLocation = SlotLocationToWorldLocation
end)

local MakeGateConnection = Class(function(GateConnection, BaseGate, DestinationID, DoorID)
	--- Represents the connection between a gate and a Area
	-- @param BaseGate The gateway in, BasePart
	-- @param DestinationGateRender The rendering function to use if GateOut fails. ()
	-- @param DoorID The doorId in the DestinationID

	GateConnection.BaseGate              = BaseGate
	GateConnection.DestinationID         = DestinationID
	GateConnection.DoorID                = DoorID
	GateConnection.DestinationGate       = nil
end)

local MakeAreaLoader = Class(function(AreaLoader, Container, Configuration)
	--- @param Container The container all the buildings go into.

	local Configuration    = OverriddenConfiguration.new(Configuration, {
		StudsPerGridSquare = 300;
		RenderHeight       = 10000;
		GridSize           = 8; -- 64 should be enough, no?
		Lifetime           = 30; -- Lifetime is areas after players leave, in seconds.
		UpdateCycle        = 60; -- Every X seconds run the GC.
	})

	-- MaximumLifetime for an area is UpdateCycle + Lifetime

	local Grid = MakeGridManager(Vector3.new(0, Configuration.RenderHeight, 0), Configuration.StudsPerGridSquare, Configuration.GridSize, Configuration.GridSize)
	local DestinationIDToRender = {}

	local function PositionCharacter(Door, Character)
		--- Positions the character relative to the front of the door. Better algorithm laster.

		local DoorBase = Door.CFrame - Vector3.new(0, Door.Size.Y/2, 0)
		local DistanceCheckingRay = Ray.new(Character.Torso.Position, Vector3.new(0,-999,0))

		local IgnoreList = {Character}

		local Hit, Position = Workspace:FindPartOnRayWithIgnoreList(DistanceCheckingRay, IgnoreList)
		local DistanceOffGround
		
		if Hit and Position then
			DistanceOffGround = math.max(3, (Character.Torso.Position - Position).magnitude)
			-- print("Player is " .. DistanceOffGround .. " studs off of the ground")
		else
			DistanceOffGround = 3
		end
		
		Character.Torso.CFrame = (DoorBase * CFrame.new(0, 0, -4)) + Vector3.new(0, DistanceOffGround, 0)
	end

	local EventTracker = EventGroup.MakeEventGroup()
	local Areas = {}

	local function LoadNewArea(Parent, AreaModel, MainPart, NewPlayer, NewCharacter)
		--- Loads the new area into a new location
		-- @param Parent The parent of the new area
		-- @param MainPart The mainpart of the whole model. 

		local NewLocation = Grid.GetOpenSlotPosition()
		if NewLocation then
			local NewSpawnLocation = Grid.SlotLocationToWorldLocation(NewLocation)

			local NewArea = {}
			NewArea.GridLocation         = NewLocation
			NewArea.WorldLocation        = NewSpawnLocation

			Grid.AddItemToSlot(NewLocation, NewArea)

			local GatewayConnections = {}

			local function AddGatewayConnection(GateConnection)
				print("[AreaLoader] - Added GateConnection")
				--- Adds the GateConnection to the system, and sets the DestinationGate
				-- @param GateConnection The connection to add.

				local DoorName = GateConnection.DoorID
				GateConnection.DestinationGate = AreaModel:FindFirstChild(DoorName) or error("New Area does not have a door named '" .. DoorName .."'")
				GateConnection.DestinationArea = NewArea

				GateConnection.DestinationGate.Touched:connect(function(Part)
					local Character, Player = GetCharacter(Part)
					if Character and Player then
						if CheckCharacter(Player) and Character.Humanoid.Health > 0 then
							PositionCharacter(GateConnection.BaseGate, Character)
							print("Player leave")
							NewArea.UntrackCharacter(Player)
						end
					end
				end)

				GatewayConnections[#GatewayConnections+1] = GateConnection
			end
			NewArea.AddGatewayConnection = AddGatewayConnection
			NewArea.addGatewayConnection = AddGatewayConnection

			local NewModel = Make 'Model' {
				Parent     = Parent;
				Name       = AreaModel.Name .. "Cloned";
				Archivable = false;
				AreaModel;
			}
			NewArea.Model = Model

			local Bricks = qInstance.GetBricks(AreaModel)
			qCFrame.TransformModel(Bricks, MainPart.CFrame, CFrame.new(NewSpawnLocation))

			-- START GC SECTION --

			local Characters = {}
			local LastUpdate = tick() -- Record the last time players occuped the area

			local function GCCheckCycle()
				--- Checks if the area can be GC, and if so, GC's it.
				-- Conditions are met when there are no active players, and lifetime is exceeded

				local CurrentTime = tick()
				local Count = 0
				for Player, Character in pairs(Characters) do
					if (Player and Player.Parent == Players and Character and Character.Parent) then
						Count = Count + 1
					else
						-- print("Player invalid")
						NewArea.UntrackCharacter(Player)
					end
				end
				if Count <= 0 and LastUpdate + Configuration.Lifetime < CurrentTime then
					NewArea.Destroy()
				else
					LastUpdate = CurrentTime
				end
			end
			NewArea.GCCheckCycle = GCCheckCycle

			local function TrackCharacter(Player, Character)
				--- Tracks a player. 
				-- @param Player The player to track
				-- @param Charater The character of the player
				-- @pre Charater is checked (Verify Humanoid)

				-- print("[AreaLoader] - Tracking player " .. Player.Name)
				
				Characters[Player] = Character

				EventTracker[NewArea][Player.Name].Died = Character.Humanoid.Died:connect(function()
					-- print("Player died")
					NewArea.UntrackCharacter(Player)
				end)

				EventTracker[NewArea][Player.Name].Respawn = Player.CharacterAdded:connect(function()
					-- print("Player respawn")
					NewArea.UntrackCharacter(Player)
				end)

				LastUpdate = tick()
			end
			NewArea.TrackCharacter = TrackCharacter
			NewArea.trackCharacter = TrackCharacter

			local function UntrackCharacter(Player)
				--- Untracks a player, should be called when a player is not in the area anymore
				-- @param Player The player to untrack.

				-- print("[AreaLoader] - Untracked " .. Player.Name)
				Characters[Player] = nil
				EventTracker[NewArea][Player.Name] = nil
				LastUpdate = tick()
				-- GCCheckCycle() 
			end
			NewArea.UntrackCharacter = UntrackCharacter
			NewArea.untrackCharacter = UntrackCharacter

			-- END GC SECTION --
			local function Destroy()
				Areas[NewArea] = nil
				-- print("[AreaLoader] - GC Area.")
				NewArea.Destroy        = nil
				NewArea.TrackCharacter = nil
				NewArea.trackCharacter = nil
				Characters = nil
				NewSpawnLocation = nil

				EventTracker[NewArea] = nil -- GC events is so awesome. <3 Anaminus

				Grid.RemoteItemFromSlot(NewLocation)

				for _, Item in pairs(GatewayConnections) do
					Item.DestinationGate = nil
					Item.DestinationArea = nil
				end
				NewModel.Parent = nil
				NewModel:Destroy()
			end
			NewArea.Destroy = Destroy
			NewArea.destroy = Destroy

			Areas[NewArea] = true -- Track areas

			return NewArea
		else
			print("[AreaLoader] - Unable to find open slot. D:")
			return nil
		end
	end

	EventTracker.PlayerLeaving = Players.PlayerRemoving:connect(function(Player)
		for NewArea, _ in pairs(Areas) do
			-- print("Player leave game")
			NewArea.UntrackCharacter(Player)
		end
	end)

	Spawn(function()
		while true do
			local Count = 0
			for NewArea, _ in pairs(Areas) do
				Count = Count + 1
				NewArea.GCCheckCycle()
			end
			print("[AreaLoader] - ActiveArea count = " .. Count)
			wait(Configuration.UpdateCycle)
		end
	end)

	local function AddDestination(DestinationID, DestinationRender, ...)
		--- Adds a destination to the render handler. 
		-- @param DestinationID String, the ID of the destination available.
		-- @param DestinationRender Function that returns the model to use as the destination.
		--        DestinationRender(GatewayConnection)
		--            @param GatewayConnection The connection being used to request the model.
		--            @return Model, MainPart

		DestinationID = DestinationID:lower()
		if not DestinationIDToRender[DestinationID] then
			DestinationIDToRender[DestinationID] = {
				Render    = DestinationRender;
				Arguments = {...};
			}
		else
			error("[AreaLoader] - DestinationID '" .. DestinationID .. "' is already registered.")
		end
	end
	AreaLoader.AddDestination = AddDestination
	AreaLoader.addDestination = AddDestination


	local function OnGatewayRequest(Player, Character, GatewayConnection, DestinationRender)
		--- When a player requests to go into a gateway, (triggered by touch), this will actaully handle the request.

		if GatewayConnection.DestinationGate then
			GatewayConnection.DestinationArea.TrackCharacter(Player, Character)

			PositionCharacter(GatewayConnection.DestinationGate, Character)
		else
			local Rendered, MainPart = DestinationRender.Render(GatewayConnection, unpack(DestinationRender.Arguments))
			local RenderArea = LoadNewArea(Container, Rendered, MainPart, Player, Character)
			RenderArea.AddGatewayConnection(GatewayConnection)
			PositionCharacter(GatewayConnection.DestinationGate, Character)
			RenderArea.TrackCharacter(Player, Character)
		end
	end

	function OnGatewayTouch(Part, GatewayConnection, DestinationRender)
		--- Handles gateway touchy thing, verifys that a connection request occured
		-- @param Part The part that touched
		-- @param  GatewayConnection The connection linked to the part.

		local Character, Player = GetCharacter(Part)
		if Character and Player then
			if CheckCharacter(Player) and Character.Humanoid.Health > 0 then
				OnGatewayRequest(Player, Character, GatewayConnection, DestinationRender)

				return true
			end
		end
		return false
	end

	local function SetupGateway(GatewayIn, DestinationID, DoorID)
		--- Setups up the connection structure, and the event on-touch.
		-- @param GatewayIn The gateway model going in
		-- @param DestinationID The destination ID (already registered) to where this gateway goes. Will probably be generated based on parent-child structure.
		-- @param DoorID String, the DoorID of the gateway.

		DestinationID = DestinationID:lower()

		if DestinationIDToRender[DestinationID] then
			local DestinationRender = DestinationIDToRender[DestinationID]
			local GatewayConnection = MakeGateConnection(GatewayIn, DestinationID, DoorID)

			GatewayIn.Touched:connect(function(Part)
				OnGatewayTouch(Part, GatewayConnection, DestinationRender)
			end)
		else
			error("[AreaLoader] - Destination '" .. DestinationID .. "' is not registered.")
		end
	end
	AreaLoader.SetupGateway = SetupGateway
	AreaLoader.setupGateway = SetupGateway

	local function ParseGatewayName(GatewayName)
		--- Parses a gateway's name and return's the DoorID and DestinationID
		-- @param GatewayName The gateway name to parse.
		-- @return nil, if it failed, otherwise, the DestinationID, Followed by the GatewayIn

		-- Gateways are setup like this: "Door:<DestinationId>:<DoorId>"
		-- Model.Name = "Door:DestinationA:DoorA"

		local BrokenString = qString.BreakString(GatewayName, ":")
		if BrokenString[1] and qString.CompareStrings(BrokenString[1], "Door") then
			if #BrokenString == 3 then
				return BrokenString[2], BrokenString[3]
			else
				return nil
			end
		else
			return nil
		end
	end
	AreaLoader.ParseGatewayName = ParseGatewayName
	AreaLoader.ParseGatewayName = ParseGatewayName

	local function LookForGatewaysAndSetup(Model)
		--- Sweeps a model's children and searches for valid doors. Call after adding destinations.
		-- @param Model The model to sweep

		CallOnChildren(Model, function(Item)
			if Item:IsA("BasePart") and Item.Name:sub(1, 5) == "Door:" then
				local DestinationID, DoorID = ParseGatewayName(Item.Name)
				if DestinationID and DoorID then
					SetupGateway(Item, DestinationID, DoorID)
				else
					error("[AreaLoader] - Invalid door found at '" .. Item:GetFullname() .. "'")
				end
			end
		end)
	end
	AreaLoader.LookForGatewaysAndSetup = LookForGatewaysAndSetup
	AreaLoader.LookForGatewaysAndSetup = LookForGatewaysAndSetup
end)
lib.MakeAreaLoader = MakeAreaLoader
lib.makeAreaLoader = MakeAreaLoader

return lib