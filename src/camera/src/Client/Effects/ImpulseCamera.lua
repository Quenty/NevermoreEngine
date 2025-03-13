--[=[
	Add another layer of effects over any other camera by allowing an "impulse"
	to be applied. Good for shockwaves, camera shake, and recoil.

	@class ImpulseCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraState = require("CameraState")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")
local SummedCamera = require("SummedCamera")

local EPSILON = 1e-6

local ImpulseCamera = {}
ImpulseCamera.ClassName = "ImpulseCamera"

function ImpulseCamera.new()
	local self = setmetatable({
		_springs = {};
		_defaultSpring = Spring.new(Vector3.zero);
	}, ImpulseCamera)

	self._defaultSpring.Damper = 0.5
	self._defaultSpring.Speed = 20

	return self
end

--[=[
	Applies an impulse to the camera, shaking it!
	@param velocity Vector3
	@param speed number -- Optional
	@param damper number -- Optional
]=]
function ImpulseCamera:Impulse(velocity, speed, damper)
	assert(typeof(velocity) == "Vector3", "Bad velocity")
	assert(type(speed) == "number" or speed == nil, "Bad speed")
	assert(type(damper) == "number" or damper == nil, "Bad damper")

	local spring = self:_getSpring(speed, damper)
	spring:Impulse(velocity)
end

--[=[
	Applies a random impulse

	@param velocity Vector3
	@param speed number -- Optional
	@param damper number -- Optional
]=]
function ImpulseCamera:ImpulseRandom(velocity, speed, damper)
	assert(typeof(velocity) == "Vector3", "Bad velocity")
	assert(type(speed) == "number" or speed == nil, "Bad speed")
	assert(type(damper) == "number" or damper == nil, "Bad damper")

	local randomVector = Vector3.new(
		2*(math.random() - 0.5),
		2*(math.random() - 0.5),
		2*(math.random() - 0.5)
	)

	return self:Impulse(velocity*randomVector, speed, damper)
end

function ImpulseCamera:_getSpring(speed, damper)
	if (not speed) and (not damper) then
		return self._defaultSpring
	end

	speed = speed or self._defaultSpring.Speed
	damper = damper or self._defaultSpring.Damper

	for _, spring in self._springs do
		if math.abs(spring.Speed - speed) <= EPSILON and math.abs(spring.Damper - damper) <= EPSILON then
			return spring
		end
	end

	local newSpring = Spring.new(Vector3.zero)
	newSpring.Speed = speed
	newSpring.Damper = damper

	table.insert(self._springs, newSpring)

	if #self._springs >= 50 then
		warn(string.format("[ImpulseCamera] - Leaking springs. Have %d springs", #self._springs))
	end

	return newSpring
end

function ImpulseCamera:_aggregateSprings()
	local position = self._defaultSpring.Position

	for i=#self._springs, 1, -1 do
		local spring = self._springs[i]
		local animating, springPosition = SpringUtils.animating(spring, EPSILON)

		position = position + springPosition
		if not animating then
			table.remove(self._springs, i)
		end
	end

	return position
end

function ImpulseCamera:__add(other)
	return SummedCamera.new(self, other)
end

function ImpulseCamera:__newindex(index, value)
	if index == "Damper" then
		assert(type(value) == "number", "Bad value")
		self._defaultSpring.Damper = value
	elseif index == "Speed" then
		assert(type(value) == "number", "Bad value")
		self._defaultSpring.Speed = value
	else
		error(string.format("%q is not a valid member of impulse camera", tostring(index)))
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within ImpulseCamera
]=]
function ImpulseCamera:__index(index)
	if index == "CameraState" then
		local newState = CameraState.new()

		local position = self:_aggregateSprings()
		newState.CFrame = CFrame.Angles(0, position.y, 0)
			* CFrame.Angles(position.x, 0, 0)
			* CFrame.Angles(0, 0, position.z)

		return newState
	elseif index == "Damper" then
		return self._defaultSpring.Damper
	elseif index == "Speed" then
		return self._defaultSpring.Speed
	elseif index == "Spring" then
		return self._defaultSpring
	else
		return ImpulseCamera[index]
	end
end

return ImpulseCamera