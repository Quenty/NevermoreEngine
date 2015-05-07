-- http://www.roblox.com/Rotatable-Region3-item?id=227509468


-- Problem: We only want the boat editor UI to be visible when the player is within a
-- certain area. We want other area-based effects too. 

-- Solution: A region fence which activates or deactivates based upon player distance.
-- @author Quenty

local EffectFence = {}
EffectFence.__index = EffectFence
EffectFence.ClassName = "EffectFence"

function EffectFence.new(Region)
	local self = {}
	setmetatable(self, EffectFence)

	self.Region = Region or error("No region")

	return self
end

return EffectFence