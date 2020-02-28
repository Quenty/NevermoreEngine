---
-- @module IKRigUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CharacterUtil = require("CharacterUtil")
local Math = require("Math")

local IKRigUtils = {}

function IKRigUtils.getTimeBeforeNextUpdate(distance)
	local updateRate
	if distance < 128 then
		updateRate = 0
	elseif distance < 256 then
		updateRate = 0.5 * Math.map(distance, 128, 256, 0, 1)
	else
		updateRate = 0.5
	end
	return updateRate
end

function IKRigUtils.getPlayerIKRig(binder, player)
	local humanoid = CharacterUtil.GetPlayerHumanoid(player)
	if not humanoid then
		return nil
	end

	return binder:Get(humanoid)
end

return IKRigUtils