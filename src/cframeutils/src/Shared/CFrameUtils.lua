---
-- @module CFrameUtils
-- @author Quenty

local UP = Vector3.new(0, 1, 0)

local CFrameUtils = {}

function CFrameUtils.lookAt(position, target, upVector)
    upVector = upVector or UP
    local forwardVector = (position - target).Unit
    local rightVector = forwardVector:Cross(upVector)
    local upVector2 = rightVector:Cross(forwardVector)

    return CFrame.fromMatrix(position, rightVector, upVector2)
end

--returns a CFrame which is minimally rotated from cframe such that
-- returnedCFrame:VectorToWorldSpace(localAxis) = worldGoal
function CFrameUtils.redirectLocalAxis(cframe, localAxis, worldGoal)
    local localGoal = cframe:VectorToObjectSpace(worldGoal)
    local m = localAxis.magnitude*localGoal.magnitude
    local d = localAxis:Dot(localGoal)
    local c = localAxis:Cross(localGoal)
    local R = CFrame.new(0, 0, 0, c.x, c.y, c.z, d + m)

    if R == R then
        return cframe*R
    else
        return cframe
    end
end


function CFrameUtils.fromUpRight(position, upVector, rightVector)
    local forwardVector = rightVector:Cross(upVector)
    if forwardVector.magnitude == 0 then
		return nil
    end

    forwardVector = forwardVector.Unit
    local rightVector2 = forwardVector:Cross(upVector)

    return CFrame.fromMatrix(position, rightVector2, upVector)
end

function CFrameUtils.scalePosition(cframe, scale)
    if scale == 1 then
        return cframe
    else
        local position = cframe.p
        return cframe - position + position*scale
    end
end

return CFrameUtils