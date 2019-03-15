--- Tags and retrieves killer
-- @module HumanoidKillerUtil

local HumanoidKillerUtil = {}

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Debris = game:GetService("Debris")

local CharacterUtil = require("CharacterUtil")

-- For legacy reasons we use creator tag
local TAG_NAME = "creator"
local TAG_LIFETIME = 1

function HumanoidKillerUtil.TagKiller(humanoid, attacker)
	assert(typeof(humanoid) == "Instance")
	assert(typeof(attacker) == "Instance")

	for _, item in pairs(humanoid:GetChildren()) do
		if item.Name == TAG_NAME then
			item:Destroy()
		end
	end

	local creator = Instance.new("ObjectValue")
	creator.Name = TAG_NAME
	creator.Value = attacker
	creator.Parent = humanoid

	Debris:Add(creator, TAG_LIFETIME)

	return creator
end

function HumanoidKillerUtil.GetKillerOfPlayer(player)
	assert(typeof(player) == "Instance")

	local humanoid = CharacterUtil.GetPlayerHumanoid(player)
	if not humanoid then
		return nil
	end

	return HumanoidKillerUtil.GetKillerOfHumanoid(humanoid)
end

function HumanoidKillerUtil.GetKillerOfHumanoid(humanoid)
	assert(typeof(humanoid) == "Instance")

	local creator = humanoid:FindFirstChild("creator")
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

return HumanoidKillerUtil