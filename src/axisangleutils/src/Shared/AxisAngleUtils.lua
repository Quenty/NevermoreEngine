--!strict
--[=[
	Utility functions for axis angles.
	@class AxisAngleUtils
]=]

local AxisAngleUtils = {}

--[=[
    Converts an AxisAngle and position to a CFrame

    @param axisAngle Vector3
    @param position Vector3
    @return CFrame
]=]
function AxisAngleUtils.toCFrame(axisAngle: Vector3, position: Vector3?): CFrame
	local angle = axisAngle.Magnitude
	local cframe = CFrame.fromAxisAngle(axisAngle, angle)

	if cframe ~= cframe then
		-- warn("[AxisAngleUtils.toCFrame] - cframe is NAN")
		if position then
			return CFrame.new(position)
		else
			return CFrame.new()
		end
	end

	if position then
		cframe = cframe + position
	end

	return cframe
end

--[=[
    Converts a CFrame to an AxisAngle and position
    @param cframe CFrame
    @return Vector3 -- AxisAngle
    @return Vector3 -- position
]=]
function AxisAngleUtils.fromCFrame(cframe: CFrame): (Vector3, Vector3)
    local axis, angle = cframe:ToAxisAngle()
    local axisAngle = angle*axis

    if axisAngle ~= axisAngle then
        -- warn("[AxisAngleUtils.fromCFrame] - axisAngle is NAN")
        return Vector3.zero, cframe.Position
    end

    return axisAngle, cframe.Position
end

return AxisAngleUtils