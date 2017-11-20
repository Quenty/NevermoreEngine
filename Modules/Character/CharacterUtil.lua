local Players = game:GetService("Players")

-- Intent: General hierarchy utility code

local lib = {}

---- Retrieves a humanomid from a descendant (Players only).
-- @param Descendant The child you're searching up from. Really, this is for weapon scripts. 
-- @return A humanoid in the parent structure if it can find it. Intended to be used in
--     workspace  only. Useful for weapon scripts, and all that, especially to work on non
--     player targets. Will scan *up* to workspace . If workspace   has a humanoid in it, it
--     won't find it.
-- Will work even if there are non-humanoid objects named "Humanoid" However, only works on
-- objects named "Humanoid" (this is intentional)
local function GetHumanoid(Descendant)
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

--- Returns the Player and Character that a descendent is part of, if it is part of one.
-- @param Descendant A child of the potential character. 
-- @return The character found.
local function GetPlayerFromCharacter(Descendant)
	local Character = Descendant
	local Player   = Players:GetPlayerFromCharacter(Character)

	while not Player do
		if Character.Parent then
			Character = Character.Parent
			Player = Players:GetPlayerFromCharacter(Character)
		else
			return nil
		end
	end

	-- Found the player, character must be true.
	return Player, Character
end
lib.GetPlayerFromCharacter = GetPlayerFromCharacter

return lib