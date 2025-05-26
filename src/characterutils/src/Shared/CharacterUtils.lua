--!strict
--[=[
	General character utility code.
	@class CharacterUtils
]=]

local Players = game:GetService("Players")

local CharacterUtils = {}

--[=[
	Gets a player's humanoid, if it exists
	@param player Player
	@return Humanoid? -- Nil if not found
]=]
function CharacterUtils.getPlayerHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

--[=[
	Gets a player's humanoid, and ensures it is alive, otherwise returns nil
	@param player Player
	@return Humanoid? -- Nil if not found
]=]
function CharacterUtils.getAlivePlayerHumanoid(player: Player): Humanoid?
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

--[=[
	Gets a player's humanoid's rootPart, and ensures the humanoid is alive, otherwise
	returns nil
	@param player Player
	@return BasePart? -- Nil if not found
]=]
function CharacterUtils.getAlivePlayerRootPart(player: Player): BasePart?
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid.RootPart
end

--[=[
	Gets a player's humanoid's rootPart otherwise returns nil
	@param player Player
	@return BasePart? -- Nil if not found
]=]
function CharacterUtils.getPlayerRootPart(player: Player): BasePart?
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if not humanoid then
		return nil
	end

	return humanoid.RootPart
end

--[=[
	Unequips all tools for a give player's humanomid, if the humanoid
	exists

	```lua
	local Players = game:GetService("Players")

	for _, player in Players:GetPlayers() do
		CharacterUtils.unequipTools(player)
	end
	```

	@param player Player
]=]
function CharacterUtils.unequipTools(player: Player)
	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if humanoid then
		humanoid:UnequipTools()
	end
end

--[=[
	Returns the player that a descendent is part of, if it is part of one.

	```lua
	script.Parent.Touched:Connect(function(inst)
		local player = CharacterUtils.getPlayerFromCharacter(inst)
		if player then
			-- activate button!
		end
	end)
	```

	:::tip
	This method is useful in a ton of different situations. For example, you can
	use it on classes bound to a humanoid, to determine the player. You can also
	use it to determine, upon touched events, if a part is part of a character.
	:::

	@param descendant Instance -- A child of the potential character.
	@return Player? -- Nil if not found
]=]
function CharacterUtils.getPlayerFromCharacter(descendant: Instance): Player?
	local character = descendant
	-- TODO: Only use models
	local player = Players:GetPlayerFromCharacter(character :: any)

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
