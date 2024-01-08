--[=[
	Utilities involving Vector3 objects in Roblox.
	@class Vector3Utils
]=]

local require = require(script.Parent.loader).load(script)

local Math = require("Math")

local Vector3Utils = {}

--[=[
	Creates a Vector3 from a Vector2 in the XY plane

	@param vector2 Vector2
	@return Vector3
]=]
function Vector3Utils.fromVector2XY(vector2: Vector2): Vector3
	return Vector3.new(vector2.x, vector2.y, 0)
end

--[=[
	Creates a Vector3 from a Vector2 in the XZ plane

	@param vector2 Vector2
	@return Vector3
]=]
function Vector3Utils.fromVector2XZ(vector2: Vector2): Vector3
	return Vector3.new(vector2.x, 0, vector2.y)
end

--[=[
	Computes the angle between 2 vectors in radians

	@param a Vector3
	@param b Vector3
	@return number?
]=]
function Vector3Utils.getAngleRad(a: Vector3, b: Vector3): number
	if a.magnitude == 0 then
		return nil
	end

	return math.acos(a:Dot(b))
end

--[=[
	Reflects a vector over a unit normal

	@param vector Vector3
	@param unitNormal Vector3
	@return Vector3
]=]
function Vector3Utils.reflect(vector: Vector3, unitNormal: Vector3): Vector3
	return vector - 2*(unitNormal*vector:Dot(unitNormal))
end

--[=[
	Computes the angle between 2 vectors in radians

	@param a Vector3
	@param b Vector3
	@return number
]=]
function Vector3Utils.angleBetweenVectors(a: Vector3, b: Vector3): number
	local u = b.magnitude*a
	local v = a.magnitude*b
	return 2*math.atan2((v - u).magnitude, (u + v).magnitude)
end

--[=[
	Spherically lerps between start and finish

	@param start Vector3
	@param finish Vector3
	@param t number -- Amount to slerp. 0 is start, 1 is finish. beyond that is extended as expected.
	@return Vector3
]=]
function Vector3Utils.slerp(start: Vector3, finish: Vector3, t: number)
	local dot = math.clamp(start:Dot(finish), -1, 1)

	local theta = math.acos(dot)*t
	local relVec = (finish - start*dot).unit
	return ((start*math.cos(theta)) + (relVec*math.sin(theta)))
end

--[=[
	Constrains a Vector3 into a cone.

	@param direction Vector3 -- The vector direction to constrain
	@param coneDirection Vector3 -- The direction of the cone.
	@param coneAngleRad -- Angle of the cone
	@return Vector3 -- Constrained angle
]=]
function Vector3Utils.constrainToCone(direction: Vector3, coneDirection: Vector3, coneAngleRad: number): Vector3
	local angle = Vector3Utils.angleBetweenVectors(direction, coneDirection)
	local coneHalfAngle = 0.5*coneAngleRad

	if angle > coneHalfAngle then
		local proportion = coneHalfAngle / angle
		return Vector3Utils.slerp(coneDirection.unit, direction.unit, proportion) * direction.magnitude
	end

	return direction
end

--[=[
	Rounds the vector to the nearest number

	```lua
	-- Snaps to a grid!
	local snapped = Vector3Utils.round(position, 4)
	```

	@param vector3 Vector3
	@param amount number
	@return Vector3
]=]
function Vector3Utils.round(vector3: Vector3, amount: number): number
	return Vector3.new(Math.round(vector3.x, amount), Math.round(vector3.y, amount), Math.round(vector3.z, amount))
end

--[=[
	Checks if 2 Vector3 values are clsoe to each other

	@param a Vector3
	@param b Vector3
	@param epsilon number
	@return boolean
]=]
function Vector3Utils.areClose(a, b, epsilon)
	assert(type(epsilon) == "number", "Bad epsilon")

	return math.abs(a.x - b.x) <= epsilon
		and math.abs(a.y - b.y) <= epsilon
		and math.abs(a.z - b.z) <= epsilon
end

return Vector3Utils