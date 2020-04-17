---
-- @module RandomUtils
-- @author Quenty

local RandomUtils = {}

function RandomUtils.choice(list)
	if #list == 0 then
		return nil
	elseif #list == 1 then
		return list[1]
	else
		return list[math.random(1, #list)]
	end
end
return RandomUtils