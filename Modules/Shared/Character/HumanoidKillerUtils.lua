--- Tags and retrieves killer
-- @module HumanoidKillerUtils

local HumanoidKillerUtils = {}

local Debris = game:GetService("Debris")

-- For legacy reasons we use creator tag
local TAG_NAME = "creator"
local TAG_LIFETIME = 1

function HumanoidKillerUtils.untagKiller(humanoid)
	for _, item in pairs(humanoid:GetChildren()) do
		if item:IsA("ObjectValue") and item.Name == TAG_NAME then
			item:Destroy()
		end
	end
end

function HumanoidKillerUtils.tagKiller(humanoid, attacker)
	assert(typeof(humanoid) == "Instance")
	assert(typeof(attacker) == "Instance")

	HumanoidKillerUtils.untagKiller(humanoid)

	local creator = Instance.new("ObjectValue")
	creator.Name = TAG_NAME
	creator.Value = attacker
	creator.Parent = humanoid

	Debris:AddItem(creator, TAG_LIFETIME)

	return creator
end

-- killer must be a player
function HumanoidKillerUtils.getKillerOfHumanoid(humanoid)
	assert(typeof(humanoid) == "Instance")

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