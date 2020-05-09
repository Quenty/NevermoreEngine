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

function CFrameUtils.fromUpRight(position, upVector, rightVector)
    local forwardVector = rightVector:Cross(upVector).Unit
    local rightVector2 = forwardVector:Cross(upVector)

    return CFrame.fromMatrix(position, rightVector2, upVector)
end

return CFrameUtils