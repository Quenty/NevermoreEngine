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
	Computes the angle between 2 vectors
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

return Vector3Utils