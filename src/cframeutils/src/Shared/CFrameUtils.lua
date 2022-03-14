--[=[
	Useful utility functions involving CFrame values.
	@class CFrameUtils
]=]

local UP = Vector3.new(0, 1, 0)

local CFrameUtils = {}

--[=[
	Makes a CFrame look at a position and target with bias towards the
	upVector.

	```lua
	-- orient a hypothetical gun such that it's relative to the root part's upVector
	local gunCFrame = CFrameUtils.lookAt(gunPos, gunTarget, rootPart.CFrame.upVector)
	```

	@param position Vector3
	@param target Vector3
	@param upVector Vector3? -- Optional, defaults to (0, 1, 0)
	@return CFrame
]=]
function CFrameUtils.lookAt(position, target, upVector)
	upVector = upVector or UP
	local forwardVector = (position - target).Unit
	local rightVector = forwardVector:Cross(upVector)
	local upVector2 = rightVector:Cross(forwardVector)

	return CFrame.fromMatrix(position, rightVector, upVector2)
end

--[=[
	Returns a CFrame which is minimally rotated from cframe such that
	the following condition is true:

	```
	returnedCFrame:VectorToWorldSpace(localAxis) = worldGoal
	```

	```lua
	-- Redirects an axis from world space up, to a spawn block's up vector
	-- so we could spawn something there.
	cframe = CFrameUtils.redirectLocalAxis(cframe, Vector3.new(0, 1, 0), spawnBlock.CFrame.upVector)
	```

	@param cframe CFrame
	@param localAxis Vector3
	@param worldGoal Vector3
	@return CFrame
]=]
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

--[=[
	Constructs a CFrame from a position, upVector, and rightVector
	even if these upVector and rightVectors are not orthogonal to
	each other.

	:::note
	upVector and rightVector do not need to be orthogonal.
	However, if they are parallel, this function returns
	nil.

	Always check to ensure that the value returned is reasonable
	before continuing.
	:::

	@param position Vector3
	@param upVector Vector3
	@param rightVector Vector3
	@return CFrame?
]=]
function CFrameUtils.fromUpRight(position, upVector, rightVector)
	local forwardVector = rightVector:Cross(upVector)
	if forwardVector.magnitude == 0 then
		return nil
	end

	forwardVector = forwardVector.Unit
	local rightVector2 = forwardVector:Cross(upVector)

	return CFrame.fromMatrix(position, rightVector2, upVector)
end

--[=[
	Scales just the positional part of a CFrame.

	@param cframe CFrame
	@param scale number
	@return CFrame
]=]
function CFrameUtils.scalePosition(cframe, scale)
	if scale == 1 then
		return cframe
	else
		local position = cframe.Position
		return cframe - position + position*scale
	end
end

return CFrameUtils