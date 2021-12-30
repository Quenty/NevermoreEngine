--[=[
	Tags and retrieves killer. This is the old API surface to register KOs
	in Roblox, and many legacy systems still use the creator tag. The contract
	is that an object value pointing to the killer will be put in the humanoid, and
	if it exists when the humanoid dies, then the killer is registered.

	@class HumanoidKillerUtils
]=]

local HumanoidKillerUtils = {}

local Debris = game:GetService("Debris")

-- For legacy reasons we use creator tag
local TAG_NAME = "creator"
local TAG_LIFETIME = 1

--[=[
	Removes all killer tags
	@param humanoid Humanoid
]=]
function HumanoidKillerUtils.untagKiller(humanoid)
	for _, item in pairs(humanoid:GetChildren()) do
		if item:IsA("ObjectValue") and item.Name == TAG_NAME then
			item:Destroy()
		end
	end
end

--[=[
	Tags the killer with a source.

	:::tip
	Be sure to tag the killer before applying damage.
	:::

	@param humanoid Humanoid
	@param attacker Player
]=]
function HumanoidKillerUtils.tagKiller(humanoid, attacker)
	assert(typeof(humanoid) == "Instance", "Bad humanoid")
	assert(typeof(attacker) == "Instance", "Bad attacker")

	HumanoidKillerUtils.untagKiller(humanoid)

	local creator = Instance.new("ObjectValue")
	creator.Name = TAG_NAME
	creator.Value = attacker
	creator.Parent = humanoid

	Debris:AddItem(creator, TAG_LIFETIME)

	return creator
end

--[=[
	Killer must be a player

	@param humanoid Humanoid
	@return Player?
]=]
function HumanoidKillerUtils.getKillerOfHumanoid(humanoid)
	assert(typeof(humanoid) == "Instance", "Bad humanoid")

	local creator = humanoid:FindFirstChild(TAG_NAME)
	if not creator then
		return nil
	end

	if not creator:IsA("ObjectValue") then
		return nil
	end

	local killer = creator.Value
	if not killer then
		return nil
	end

	if not killer:IsA("Player") then
		return nil
	end

	if not killer:IsDescendantOf(game) then
		return nil
	end

	return killer
end

return HumanoidKillerUtils