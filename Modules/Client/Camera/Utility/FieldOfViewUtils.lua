---
-- @module FieldOfViewUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Math = require("Math")


local FieldOfViewUtils = {}

function FieldOfViewUtils.fovToHeight(fov)
    return 2*math.tan(math.rad(fov)/2)
end

function FieldOfViewUtils.heightToFov(height)
    return 2*math.deg(math.atan(height/2))
end


function FieldOfViewUtils.safeLog(height, linearAt)
	if height < linearAt then
		local slope = 1/linearAt
		return slope*(height - linearAt) + math.log(linearAt)
	else
		return math.log(height)
	end
end

function FieldOfViewUtils.safeExp(logHeight, linearAt)
	local transitionAt = math.log(linearAt)

	if logHeight <= transitionAt then
		return linearAt*(logHeight - transitionAt) + linearAt
	else
		return math.exp(logHeight)
	end
end

function FieldOfViewUtils.lerpInHeightSpace(fov0, fov1, percent)
	local height0 = FieldOfViewUtils.fovToHeight(fov0)
	local height1 = FieldOfViewUtils.fovToHeight(fov1)

	local linearAt = FieldOfViewUtils.fovToHeight(1)

	local logHeight0 = FieldOfViewUtils.safeLog(height0, linearAt)
	local logHeight1 = FieldOfViewUtils.safeLog(height1, linearAt)

	local newLogHeight = Math.lerp(logHeight0, logHeight1, percent)

	return FieldOfViewUtils.heightToFov(FieldOfViewUtils.safeExp(newLogHeight, linearAt))
end

return FieldOfViewUtils