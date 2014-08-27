local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qCFrame          = LoadCustomLibrary("qCFrame")

qSystems:Import(getfenv(0));

-- qPlayer.lua
-- Just utilities involving players (and teams).

local lib = {}

local function IsTeamMate(PlayerOne, PlayerTwo)
	--- Are playerone and playertwo teammates?

	if PlayerOne.Neutral == PlayerTwo.Neutral then
		if PlayerOne.Neutral then
			return true
		else
			return PlayerOne.TeamColor.Name == PlayerTwo.TeamColor.Name
		end
	else
		return false
	end
end
lib.IsTeamMate = IsTeamMate
lib.isTeamMate = IsTeamMate

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

local function GetPlayersWithinBlastRadius(PlayerList, Position, Radius, IgnoreList, IgnoreInvisible, IgnoreCollisions, TerrainCellsAreCubes)
	--- Useful for explosions are stuff, although not super useful. Uses raycasting to check out the situation.

	-- @param PlayerList A list of players where CheckCharacter(Player) has returned true
	-- @param Radius the radius to check for. Must be less than 1000
	-- @param Position the position to check at. 
	-- @param IgnoreList The ignore list to use. Probably throw the projectile in that. Since we're using advance raycast, it may add items to this list.
	-- @param [TerrainCellsAreCubes] default = true

	TerrainCellsAreCubes = TerrainCellsAreCubes == nil and true or TerrainCellsAreCubes

	local PlayersFound = {}

	for _, Player in pairs(PlayerList) do
		local TorsoPosition = Player.Character.Torso.Position
		local Direction = (TorsoPosition - Position)
		if Direction.magnitude <= Radius then
			local CastRay = Ray.new(Position, Direction.unit * Radius)
			local Hit, Position = qCFrame.AdvanceRaycast(CastRay, IgnoreList, IgnoreInvisible, IgnoreCollisions, TerrainCellsAreCubes)

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

return lib