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

local Type              = LoadCustomLibrary('Type')
local qString           = LoadCustomLibrary('qString')
local qSystems          = LoadCustomLibrary('qSystems')

local lib               = {}

qSystems:Import(getfenv(0));

local MakePlayerReference = class 'PlayerReference' (function(PlayerReference, CheckFunction)
	--VerifyArg(CheckFunction, "function", "CheckFunction"); -- Should return a table full of players

	function PlayerReference:Check(Players, User, ...)
		--VerifyArg(Players, "table", "Players")
		--VerifyArg(User, "Player", "User")

		return CheckFunction(Players, User, ...);
	end
end)



local MakePlayerSystem = Class 'PlayerSystem' (function(PlayerSystem, MoreArguments, SpecificGroups)
	--VerifyArg(Settings, "Settings", "Settings")

	local PlayerReferences = {}
	local SimpleReference = {} -- An Alias system for shortened names...
	PlayerSystem.SimpleReference = SimpleReference -- For stuff like SimpleReference["EpicPerson"] = "Quenty" so you can do kill/EpicPerson and it kills Quenty

	MoreArguments = MoreArguments or {",", ";"}
	SpecificGroups = SpecificGroups or {"."}

	function PlayerSystem:GetPlayersFromString(String, User)
		--VerifyArg(String, "string", "String")
		--VerifyArg(User, "Player", "User", true)

		local Targets = {}
		local AllPlayers = Players:GetPlayers();

		local function CanAdd(Player)
			-- Returns false if the Player is in the list already.  

			for _, Item in pairs(Targets) do
				if Item == Player then
					return false;
				end
			end
			return true;
		end

		local function Add(Player)
			--VerifyArg(Player, "Player", "Player")
			
			if CanAdd(Player) then
				--print("[qPlayerSystem] - Adding '"..Player.Name.."'")
				Targets[#Targets+1] = Player;
			else
				--print("[qPlayerSystem] - The Player '"..Player.Name.."' has already been added to the list")
			end
		end

		local function AddTable(List)
			--VerifyArg(List, "table", "List")

			for _, Value in pairs(List) do
				VerifyArg(Value, "Player", "Value")

				Add(Value);
			end
		end

		String = String:lower()

		local SeperatedIntoSectors = qString.BreakString(String, MoreArguments)
		for _, BrokenString in pairs(SeperatedIntoSectors) do
			local SecondBreak = qString.BreakString(BrokenString, SpecificGroups)
			--local NameLength = #BrokenString; 

			local PlayerReferenceName = SecondBreak[1]; -- Like "Group.363434", where the Name would be "Group"
			
			local SecondBreakModified = {} -- Without the first one, so it may be used in argument passing of ArgumentObjects
			for index = 2, #SecondBreak do
				SecondBreakModified[index-1] = SecondBreak[index];
			end

			local ReferenceObject --= PlayerReferences[PlayerReferenceName];
			for Name, Item in pairs(PlayerReferences) do
				if not ReferenceObject and qString.CompareStrings(Name, PlayerReferenceName) then
					ReferenceObject = Item
				end
			end

			if ReferenceObject then -- So we found a match, like kill/team.admins 
				local Received = ReferenceObject:Check(AllPlayers, User, unpack(SecondBreakModified))

				if type(Received) == "table" then
					AddTable(Received) -- Get the list, then add it to Targets
				elseif Type.isAnInstance(Received) == "Instance" and game.IsA(Received, "Player") then
					Add(Received)
				else
					error("[qPlayerSystem] - Did not receive a correct value type from the reference object '"..PlayerReferenceName.."'! Got a "..Type.getType(Received).." value")
				end
			else
				if SimpleReference[PlayerReferenceName] then
					print("[qPlayerSystem] - Getting from SimpleReferences")
					AddTable(PlayerSystem:GetPlayersFromString(SimpleReference[PlayerReferenceName]))
				else
					for _, Player in pairs(AllPlayers) do -- Loop through the players 
						local PlayerName = Player.Name
						if qString.CompareCutFirst(PlayerName, BrokenString) then -- and try to find matches of names
							Add(Player)
						end
					end
				end				
			end
		end

		return Targets;
	end

	function PlayerSystem:AddReference(Name, CheckFunction)
		--VerifyArg(Name, "string", "Name");
		--VerifyArg(CheckFunction, "function", "CheckFunction");

		local NewReference = MakePlayerReference(CheckFunction)
		PlayerReferences[Name:lower()] = NewReference;
	end

	function PlayerSystem:AddAlias(Name, NewAliasName)
		--VerifyArg(Name, "string", "Name")

		if type(NewAliasName) == "string" then
			local Object = PlayerReferences[Name:lower()] 

			if not Object then
				error("[qPlayerSystem] - Could not find the object of '"..Name.."' in database, so the Alias of '"..NewAliasName.."' could not be set")
			elseif PlayerReferences[NewAliasName:lower()] then
				warn("[qPlayerSystem] - You are overwriting "..NewAliasName.." in the PlayerReference database with '"..Name.."'")
			end

			PlayerReferences[NewAliasName:lower()] = Object
		elseif type(NewAliasName) == "table" then
			for _, Item in pairs(NewAliasName) do
				PlayerSystem:AddAlias(Name, Item)
			end
		else
			argumentError("NewAliasName", false, "table or string", Type.getType(NewAliasName))
		end
	end

	function PlayerSystem:RemoveReference(Name)
		--VerifyArg(Name, "string", "Name") 

		PlayerReferences[Name:lower()] = nil;
	end

	PlayerSystem.Remove = PlayerSystem.RemoveReference
	PlayerSystem.Alias = PlayerSystem.AddAlias
	PlayerSystem.Add = PlayerSystem.AddReference
end)

local function MakeDefaultPlayerSystem(MoreArguments, SpecificGroups)
	-- Generates the default system of a 'PlayerArgumentSystem'

	local Plyrs           = MakePlayerSystem(MoreArguments, SpecificGroups)

	Plyrs:Add("All", function(Players, User)
			return Players;
		end)
		Plyrs:Alias("All", {"Everyone", "Everybody", "everyman"})

	Plyrs:Add("Random", function(Players, User)
			return {Players[math.random(1, #Players)]}
		end)
		Plyrs:Alias("Random", {"Rand"})

	Plyrs:Add("Guests", function(Players, User)
			local List = {}

			for _, Player in pairs(Players) do
				if qString.CompareCutFirst(Player.Name, "Guest ") then
					List[#List+1] = Player
				end
			end

			return List;
		end)
		
	Plyrs:Add("Self", function(Players, User)
			if User then
				return {User}
			else
				warn("No user was given, so it was impossible to identify a user from the list")
			end
		end)
		Plyrs:Alias("Self", {"Myself", "Me"})

	Plyrs:Add("Team", function(Players, User, TeamName) -- Fairly sketchy, because usually team names have spaces, which can't beused, because 
			if TeamName and type(TeamName) == "string" then
				local FoundTeam
				local List = {}

				if not FoundTeam then -- Incase kill/Team.NameHere
					for _, Team in pairs(Teams:GetTeams()) do -- Search by name. 
						if qString.CompareCutFirst(Team.Name, TeamName) then
							FoundTeam = Team
							break
						end
					end
				end
				if not FoundTeam then -- Look for a team color match? Sure!
					for _, Team in pairs(Teams:GetTeams()) do
						if qString.CompareCutFirst(Team.TeamColor.Name, TeamName) then 
							FoundTeam = Team
							break
						end
					end
				end
				if not FoundTeam then
					if qString.CompareCutFirst("Neutral", TeamName) then -- Incase kill/Team.neutra
						local NeutralTeam
						for _, Team in pairs(Teams:GetTeams()) do
							if qString.CompareCutFirst(Team.Name, "Neutral") then
								NeutralTeam = Team
							end
						end
						if NeutralTeam then
							FoundTeam = NeutralTeam
						else
							for _, Player in pairs(Players) do
								if Player.Neutral then
									List[#List + 1] = Player 
								end
							end
							return List
						end
					end
				end
				if not FoundTeam then
					print("[Commands] - Could not find team")
				else
					local TeamColorName = FoundTeam.TeamColor.Name

					for _, Player in pairs(Players) do
						if Player.TeamColor.Name == TeamColorName and not Player.Neutral then
							List[#List + 1] = Player 
						end
					end

					return List
				end
			end
			local TeamColorName = User.TeamColor.Name -- Default to user team...
			local List = {}
			
			for _, Player in pairs(Players) do
				if Player.TeamColor.Name == TeamColorName and not Player.Neutral then
					List[#List + 1] = Player 
				end
			end

			return List
		end)

	Plyrs:Add("Group", function(Players, User, GroupId, RankId) 
		if GroupId and tonumber(GroupId) then
			local List = {}
			for _, Player in pairs(Players) do
				if Player:IsInGroup(tonumber(GroupId)) then
					if RankId and tonumber(RankId) then
						if Player:GetRankInGroup(tonumber(GroupId)) >= RankId then
							List[#List+1] = Player
						end
					else
						List[#List+1] = Player
					end
				end
			end
			return List;
		else
			error("Group ID Required.")
		end
	end)

	return Plyrs
end

lib.MakeDefaultPlayerSystem = MakeDefaultPlayerSystem

lib.MakePlayerSystem = MakePlayerSystem;
lib.makePlayerSystem = MakePlayerSystem;

NevermoreEngine.RegisterLibrary('qPlayerSystem', lib);