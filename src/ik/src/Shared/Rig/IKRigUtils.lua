--[=[
	@class IKRigUtils
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")
local Math = require("Math")

local IKRigUtils = {}

function IKRigUtils.getTimeBeforeNextUpdate(distance: number): number
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

function IKRigUtils.getPlayerIKRig(binder, player: Player)
	assert(binder, "Bad binder")

	local humanoid = CharacterUtils.getPlayerHumanoid(player)
	if not humanoid then
		return nil
	end

	return binder:Get(humanoid)
end

return IKRigUtils
