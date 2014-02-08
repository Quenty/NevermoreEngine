local Players           = Game:GetService("Players")
local Teams             = Game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Type              = LoadCustomLibrary("Type")
local qString           = LoadCustomLibrary("qString")
local qSystems          = LoadCustomLibrary("qSystems")
local Table             = LoadCustomLibrary("Table")

local lib               = {}
qSystems:Import(getfenv(0));

-- PlayerId.lua
-- Last modified on January 23rd, 2014
-- @author Quenty

--[[-- Update Log --
January 23rd, 2014
- Updated to new class system

January 19th, 2014
- Updated to use module scripts.
- Added update log
- Converted name from "qPlayerSystem" to "PlayerId" which makes a lot more sense
- Added "UserId" to default list
- Added Random.3534 (some number) so we can select more than one random player at once.
- Added more aliases to methods in PlayerIdSystem

--]]
local MakePlayerReference = Class(function(PlayerReference, CheckFunction)
	--- Creates a new checker that returns whether or not a player is considered X
	-- @param CheckFunction A function that returns a table of valid players

	function PlayerReference:Check(Players, User, ...)
		--- Returns a table of players that qualify
		-- @param Players A list of players to check
		-- @param User The current player "Checking" so commands like "me" work. May be nil
		-- @param ... Extra data / arguments (As strings) to check for / user
		
		return CheckFunction(Players, User, ...)
	end
end)

local MakePlayerIdSystem = Class(function(PlayerIdSystem, MoreArguments, SpecificGroups)
	--- A system used to Id a player from a string. Parses strings using custom parser templates. 
	-- @param MoreArguments A table of characters that "seperate" or "break" a string. apart. 
	-- @param SpecificGroups Another tablel that breaks it apart.  

	local PlayerReferences = {}
	local SimpleReference = {} -- An Alias system for shortened names...
	PlayerIdSystem.SimpleReference = SimpleReference -- For stuff like SimpleReference["EpicPerson"] = "Quenty" so you can do kill/EpicPerson and it kills Quenty

	MoreArguments = MoreArguments or {",", ";"}
	SpecificGroups = SpecificGroups or {"."}

	local function GetPlayersFromString(self, String, User)
		--- Given a string, get a player from it.
		-- @param String The string to parse. Not case sensitive. 
		-- @param [User] The user that is "using" the system. May be nil. 

		local Targets = {}
		local AllPlayers = Players:GetPlayers();

		local function CanAdd(Player)
			--- Returns false if the Player is in the list already.  
			-- @param Player The player to check for 
			-- @return Boolean, whether or not the player can be added.

			for _, Item in pairs(Targets) do
				if Item == Player then
					return false;
				end
			end
			return true;
		end

		local function Add(Player)
			--- Locally used function, adds the player to the Target list
			-- @param Player The player to add, if the player can be added.

			if CanAdd(Player) then
				Targets[#Targets+1] = Player
			end
		end

		local function AddTable(List)
			-- Adds every "Player" in the list to the Target list, if they can be added. 
			-- @param List The list of players to add.

			for _, Value in pairs(List) do
				Add(Value)
			end
		end

		String = String:lower() -- Make the string not caps sensitive. 

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
					error("[PlayerIdSystem] - Did not receive a correct value type from the reference object '"..PlayerReferenceName.."'! Got a "..Type.getType(Received).." value")
				end
			else
				if SimpleReference[PlayerReferenceName] then
					print("[PlayerIdSystem] - Getting from SimpleReferences")
					AddTable(PlayerIdSystem:GetPlayersFromString(SimpleReference[PlayerReferenceName]))
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

		return Targets
	end
	PlayerIdSystem.GetPlayersFromString = GetPlayersFromString
	PlayerIdSystem.getPlayersFromString = GetPlayersFromString
	PlayerIdSystem.Get = GetPlayersFromString
	PlayerIdSystem.get = GetPlayersFromString

	local function AddReference(self, Name, CheckFunction)
		--- Adds a new "reference" to the system
		-- @param Name The name of the checker. Can be aliased by the AddAlias command. String.
		-- @param CheckFunction A function that should check players.
			--- Returns a table of players that qualify
			-- @param Players A list of players to check
			-- @param User The current player "Checking" so commands like "me" work. May be nil
			-- @param ... Extra data / arguments (As strings) to check for / user

		local NewReference = MakePlayerReference(CheckFunction)
		PlayerReferences[Name:lower()] = NewReference;
	end
	PlayerIdSystem.AddReference = AddReference
	PlayerIdSystem.addReference = AddReference
	PlayerIdSystem.Reference = AddReference
	PlayerIdSystem.reference = AddReference

	local function AddAlias(self, Name, NewAliasName)
		--- Aliases a current Player reference for a new one.
		-- @param Name The name of the current alias.
		-- @param NewAliasName The name of the new alias. Is not caps sensitive. 

		if type(NewAliasName) == "string" then
			local Object = PlayerReferences[Name:lower()] 

			if not Object then
				error("[PlayerIdSystem] - Could not find the object of '"..Name.."' in database, so the Alias of '"..NewAliasName.."' could not be set")
			elseif PlayerReferences[NewAliasName:lower()] then
				warn("[PlayerIdSystem] - You are overwriting "..NewAliasName.." in the PlayerReference database with '"..Name.."'")
			end

			PlayerReferences[NewAliasName:lower()] = Object
		elseif type(NewAliasName) == "table" then
			for _, Item in pairs(NewAliasName) do
				PlayerIdSystem:AddAlias(Name, Item)
			end
		else
			argumentError("NewAliasName", false, "table or string", Type.getType(NewAliasName))
		end
	end
	PlayerIdSystem.AddAlias = AddAlias
	PlayerIdSystem.addAlias = AddAlias
	PlayerIdSystem.Alias = AddAlias
	PlayerIdSystem.alias = AddAlias

	local function RemoveAlias(Name)
		--- Removes a current aliase from the list 
		-- @param Name String, the alias to remove. 

		PlayerReferences[Name:lower()] = nil;
	end
	PlayerIdSystem.RemoveAlias = RemoveAlias
	PlayerIdSystem.removeAlias = RemoveAlias
	PlayerIdSystem.Remove = RemoveAlias
	PlayerIdSystem.remove = RemoveAlias
end)
lib.MakePlayerIdSystem = MakePlayerIdSystem
lib.makePlayerIdSystem = MakePlayerIdSystem
lib.MakePlayerId = MakePlayerIdSystem
lib.makePlayerId = MakePlayerIdSystem


local function MakeDefaultPlayerIdSystem(MoreArguments, SpecificGroups)
	--- Generates the default system of a 'PlayerArgumentSystem'
	-- @param MoreArguments A table of characters that "seperate" or "break" a string. apart. 
	-- @param SpecificGroups Another tablel that breaks it apart.  

	local DefaultPlayerIdSystem = MakePlayerIdSystem(MoreArguments, SpecificGroups)

	DefaultPlayerIdSystem:AddReference("All", function(Players, User)
			return Players
		end)
		DefaultPlayerIdSystem:Alias("All", {"Everyone", "Everybody", "everyman"})

	DefaultPlayerIdSystem:AddReference("Random", function(Players, User, Number)
			if #Players >= 1 then
				if tonumber(Number) then
					--- Select a number of random players...
					local List = {}
					local ToFind = tonumber(Number)

					local PlayerList = Table.Copy(Players)
					while ToFind > 0 and PlayerList[1] do
						local SelectedIndex = math.random(1, #PlayerList)
						List[#List + 1] = PlayerList[SelectedIndex]

						-- Swap the selected and the top
						PlayerList[SelectedIndex] = PlayerList[#PlayerList]
						PlayerList[#PlayerList] = nil
					end

					return List
				else
					return {Players[math.random(1, #Players)]}
				end
			else
				warn("[PlayerId] - There are no players to select from, so random pick failed. ")
			end
		end)
		DefaultPlayerIdSystem:Alias("Random", {"Rand"})

	DefaultPlayerIdSystem:AddReference("Guests", function(Players, User)
			local List = {}

			for _, Player in pairs(Players) do
				if qString.CompareCutFirst(Player.Name, "Guest ") then
					List[#List+1] = Player
				end
			end

			return List;
		end)
	
	DefaultPlayerIdSystem:AddReference("Self", function(Players, User)
			if User then
				return {User}
			else
				warn("[PlayerId] - No user was given, so it was impossible to identify a user from the list")
				return nil
			end
		end)
		DefaultPlayerIdSystem:Alias("Self", {"Myself", "Me"})

	DefaultPlayerIdSystem:AddReference("Team", function(Players, User, TeamName) -- Fairly sketchy, because usually team names have spaces, which can't beused, because 
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
					print("[PlayerIdSystem] - Could not find team with Team Search...")
					return nil
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

	DefaultPlayerIdSystem:AddReference("Group", function(Players, User, GroupId, RankId) 
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
			error("[PlayerId] - Group ID Required.")
		end
	end)

	DefaultPlayerIdSystem:AddReference("UserId", function(Players, User, Id)
		if Id then
			local List = {}
	
			for _, Player in pairs(Players) do
				if Player.userId == Id then
					List[#List+1] = Player
				end
			end
	
			return List
		else
			error("[PlayerId] - Id required")
		end
	end)
	DefaultPlayerIdSystem:Alias("UserId", {"Id", "PlayerId"})

	return DefaultPlayerIdSystem
end
lib.MakeDefaultPlayerIdSystem = MakeDefaultPlayerIdSystem
lib.makeDefaultPlayerIdSystem = MakeDefaultPlayerIdSystem
lib.MakeDefaultPlayerId = MakeDefaultPlayerIdSystem
lib.makeDefaultPlayerId = MakeDefaultPlayerIdSystem

return lib