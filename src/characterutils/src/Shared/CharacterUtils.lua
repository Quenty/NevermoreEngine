--- General character utility code.
-- @module CharacterUtils

local Players = game:GetService("Players")

local CharacterUtils = {}

function CharacterUtils.getPlayerHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function CharacterUtils.getAlivePlayerHumanoid(player)
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

function CharacterUtils.getAlivePlayerRootPart(player)
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid.RootPart
end

function CharacterUtils.getPlayerRootPart(player)
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if not humanoid then
		return nil
	end

	return humanoid.RootPart
end

function CharacterUtils.unequipTools(player)
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if humanoid then
		humanoid:UnequipTools()
	end
end

--- Returns the Player and Character that a descendent is part of, if it is part of one.
-- @param descendant A child of the potential character.
-- @treturn Player player
-- @treturn Character character
function CharacterUtils.getPlayerFromCharacter(descendant)
	local character = descendant
	local player = Players:GetPlayerFromCharacter(character)

	while not player do
		if character.Parent then
			character = character.Parent
			player = Players:GetPlayerFromCharacter(character)
		else
			return nil
		end
	end

	return player
end

return CharacterUtils