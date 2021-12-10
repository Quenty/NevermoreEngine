--- Utility functions for axis angles.
-- @module AxisAngleUtils

local AxisAngleUtils = {}

function AxisAngleUtils.toCFrame(axisAngle, position)
    local angle = axisAngle.Magnitude
    local cframe = CFrame.fromAxisAngle(axisAngle, angle)

    if cframe ~= cframe then
        -- warn("[AxisAngleUtils.toCFrame] - cframe is NAN")
        if position then
            return CFrame.new(position)
        else
            return CFrame.identity
        end
    end

    if position then
        cframe = cframe + position
    end

    return cframe
end

function AxisAngleUtils.fromCFrame(cframe)
    local axis, angle = cframe:ToAxisAngle()
    local axisAngle = angle*axis

    if axisAngle ~= axisAngle then
        -- warn("[AxisAngleUtils.fromCFrame] - axisAngle is NAN")
        return Vector3.zero, cframe.Position
    end

    return axisAngle, cframe.Position
end

return AxisAngleUtils