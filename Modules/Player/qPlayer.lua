-- Utilities involving players and teams

local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Load = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local qCFrame = Load("qCFrame")

local lib = {}

local function CheckPlayer(Player)
	--- Makes sure a player has all necessary components.
	-- @param Player The Player to check for
	-- @return Boolean If the player has all the right components

	return Player and Player:IsA("Player") and Player:IsDescendantOf(Players)
end
lib.CheckPlayer = CheckPlayer

local function CheckCharacter(Player)
	--- Makes sure a character has all the right "parts". This also validates the player's status as
	--  a player. This is useful when you want to load a character, as ROBLOX's character added
	--  event doesn't guarantee loaded character status.
	-- @param Player The player to search for
	-- @return Boolean, True if it's good, false if it's not.
	
	if CheckPlayer(Player) then
		local Character = Player.Character

		if Character then
			return Character.Parent
				and Character:FindFirstChild("Humanoid")
				and Character:FindFirstChild("HumanoidRootPart")
				and Character:FindFirstChild("Torso") 
				and Character:FindFirstChild("Head") 
				and Character.Humanoid:IsA("Humanoid")
				and Character.Head:IsA("BasePart")
				and Character.Torso:IsA("BasePart")
		end
	end
	return warn("[CheckCharacter] - Character Check failed!")
end
lib.CheckCharacter = CheckCharacter

local function IsTeamMate(PlayerOne, PlayerTwo, NeutralCounts)
	--- Are playerone and playertwo teammates?
	-- @param [NeutralCounts=true] Whether neutral counts as neutral. True if neutral players are considered teammates.


	NeutralCounts = NeutralCounts == nil and true or NeutralCounts
	
	if PlayerOne == PlayerTwo then
		return false
	elseif PlayerOne.Neutral == PlayerTwo.Neutral then
		if PlayerOne.Neutral then
			return NeutralCounts
		else
			return PlayerOne.TeamColor.Name == PlayerTwo.TeamColor.Name
		end
	else
		return false
	end
end
lib.IsTeamMate = IsTeamMate
lib.isTeamMate = IsTeamMate

local function GetTeamFromColorName(TeamColorName)
	for _, Team in pairs(Teams:GetTeams()) do
		if Team.TeamColor.Name == TeamColorName then
			return Team
		end
	end
end
lib.GetTeamFromColorName = GetTeamFromColorName
lib.getTeamFromColorName = GetTeamFromColorName

local function GetTeamFromPlayer(Player)
	if Player.Neutral then
		return nil
	else
		return GetTeamFromColorName(Player.TeamColor.Name)
	end
end
lib.GetTeamFromPlayer = GetTeamFromPlayer
lib.GetTeamFromPlayer = GetTeamFromPlayer

local function GetPlayerFromName(PlayerName)
	PlayerName = PlayerName:lower()
	
	local Found = Players:FindFirstChild(PlayerName)
	if Found and Found:IsA("Player") then
		return Found
	end

	-- Otherwise....
	for _, Player in pairs(Players:GetPlayers()) do
		if Player.Name:lower() == PlayerName then
			return Player
		end
	end
end
lib.GetPlayerFromName = GetPlayerFromName
lib.getPlayerFromName = GetPlayerFromName

local function GetPlayersWithinRadius(PlayerList, Position, Radius)
	--- Useful for explosions are stuff...
	--- @param PlayerList A list of players where CheckCharacter(Player) has returned true

	local PlayersFound = {}

	for _, Player in pairs(PlayerList) do
		if (Player.Character.Torso.Position - Position).magnitude <= Radius then
			PlayersFound[#PlayersFound+1] = Player
		end
	end

	return PlayersFound
end
lib.GetPlayersWithinRadius = GetPlayersWithinRadius
lib.getPlayersWithinRadius = GetPlayersWithinRadius

local function GetPlayersWithinBlastRadius(PlayerList, Position, Radius, IgnoreList, TransparencyThreshold, IgnoreCollisions, TerrainCellsAreCubes)
	--- Useful for explosions are stuff, although not super useful. Uses raycasting to check out the situation.

	-- @param PlayerList A list of players where CheckCharacter(Player) has returned true
	-- @param Radius the radius to check for. Must be less than 1000
	-- @param Position the position to check at. 
	-- @param IgnoreList The ignore list to use. Probably throw the projectile in that. Since we're using advance raycast, it may add items to this list.
	-- @param [TerrainCellsAreCubes] default = true

	assert(type(TransparencyThreshold) == "number")

	TerrainCellsAreCubes = TerrainCellsAreCubes == nil and true or TerrainCellsAreCubes

	local PlayersFound = {}

	for _, Player in pairs(PlayerList) do
		local TorsoPosition = Player.Character.Torso.Position
		local Direction = (TorsoPosition - Position)
		if Direction.magnitude <= Radius then
			local CastRay = Ray.new(Position, Direction.unit * Radius)
			local Hit, Position = qCFrame.AdvanceRaycast(CastRay, IgnoreList, TransparencyThreshold, IgnoreCollisions, TerrainCellsAreCubes)

			if Hit:IsDescendantOf(Player.Character) then
				PlayersFound[#PlayersFound+1] = Player
			else
				print("Obstruction")
			end
		end
	end

	return PlayersFound
end
lib.GetPlayersWithinBlastRadius = GetPlayersWithinBlastRadius
lib.getPlayersWithinBlastRadius = GetPlayersWithinBlastRadius

local function GetPlayersWithValidCharacters()
	local PlayersFound = {}

	for _, Player in pairs(Players:GetPlayers()) do
		if CheckCharacter(Player) then
			PlayersFound[#PlayersFound+1] = Player
		end
	end

	return PlayersFound
end
lib.GetPlayersWithValidCharacters = GetPlayersWithValidCharacters
lib.getPlayersWithValidCharacters = GetPlayersWithValidCharacters

local function GetCharacter(Character)
	--- Returns the Player and Character that a descendent is part of, if it is part of one.
	-- @param Character A child of the potential character. 
	-- @return The character found.

	local Player= Players:GetPlayerFromCharacter(Character)

	while not Player do
		if Character.Parent then
			Character = Character.Parent
			Player   = Players:GetPlayerFromCharacter(Character)
		else
			return nil
		end
	end

	-- Found the player, character must be true.
	return Character, Player
end
lib.GetCharacter = GetCharacter
lib.GetPlayerFromCharacter = GetCharacter

local function GetPlayerWhoSatOnChair(PotentialSeatWeld)
	-- Intended to be used with ROBLOX's seat system, where .ChildAdded fires whenever a player
	-- sits in a seat and the child's name is "SeatWeld" and is a "Weld" and the Part1 is a 
	-- HumanoidRootPart
	-- @return Player who sat on seat.

	-- Players must be alive (Health > 0) and pass character check to qualify

	if PotentialSeatWeld and PotentialSeatWeld.Parent and PotentialSeatWeld.Parent and PotentialSeatWeld:IsA("Weld") and PotentialSeatWeld.Name == "SeatWeld" then
		if PotentialSeatWeld.Part1 and PotentialSeatWeld.Part0 then
			local HumanoidRootPart = PotentialSeatWeld.Part1

			if HumanoidRootPart:IsA("BasePart") then
				local Character, Player = GetCharacter(HumanoidRootPart)
				if Character and Player and CheckCharacter(Player) and Character.Humanoid.Health > 0 then
					return Player
				end
			else
				warn("[GetPlayerWhoSatOnChair] - HumanoidRootPart was not a base part??!?")
				return nil
			end
		else
			warn("[GetPlayerWhoSatOnChair] - Weld failed to have part1 or part0")
			return nil
		end

		-- Don't randomly warn everytime a weld get's added.
		return nil
	end
end
lib.GetPlayerWhoSatOnChair = GetPlayerWhoSatOnChair

local function CheckIfPlayerStillSittingOnChair(OriginalSeatWeld, OriginalPlayer)
	-- Checks to see if the weld and player are aOK in the chair. 
	-- Players must be alive (Health > 0) and pass character check to qualify

	if OriginalSeatWeld:IsDescendantOf(game) and OriginalSeatWeld.Part1 and OriginalSeatWeld.Part0 and OriginalSeatWeld.Part0:IsDescendantOf(game) and OriginalSeatWeld.Part1:IsDescendantOf(game) then
		if OriginalPlayer and OriginalPlayer:IsDescendantOf(Players) and CheckCharacter(OriginalPlayer) and OriginalPlayer.Character.Humanoid.Health > 0 then
			local HumanoidRootPart = OriginalSeatWeld.Part1
			if HumanoidRootPart:IsA("BasePart") and HumanoidRootPart:IsDescendantOf(OriginalPlayer.Character) then
				return true
			else
				-- warn("[CheckIfPlayerStillSittingOnChair] - HumanoidRootPart was not a base part, or is not a descendant of the player's character")
				return false
			end
		else
			-- warn("[OriginalPlayer] - Player has invalid character or has left game...")
			return false
		end
	else
		return false
	end
end
lib.CheckIfPlayerStillSittingOnChair = CheckIfPlayerStillSittingOnChair

local function GetHumanoid(Descendant)
	---- Retrieves a humanomid from a descendant (Players only).
	-- @param Descendant The child you're searching up from. Really, this is for weapon scripts. 
	-- @return A humanoid in the parent structure if it can find it. Intended to be used in
	--     workspace  only. Useful for weapon scripts, and all that, especially to work on non
	--     player targets. Will scan *up* to workspace . If workspace   has a humanoid in it, it
	--     won't find it.
	-- Will work even if there are non-humanoid objects named "Humanoid" However, only works on
	-- objects named "Humanoid" (this is intentional)


	while true do
		local Humanoid = Descendant:FindFirstChild("Humanoid")

		if Humanoid then
			if Humanoid:IsA("Humanoid") then
				return Humanoid
			else -- Incase there are other humanoids in there.
				for _, Item in pairs(Descendant:GetChildren()) do
					if Item.Name == "Humanoid" and Item:IsA("Humanoid") then
						return Item
					end
				end
			end
		end

		if Descendant.Parent and Descendant:IsDescendantOf(workspace) then
			Descendant = Descendant.Parent
		else
			return nil
		end
	end
end
lib.GetHumanoid = GetHumanoid

return lib
