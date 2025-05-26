--!strict
--[=[
	Add another layer of effects over any other camera by allowing an "impulse"
	to be applied. Good for shockwaves, camera shake, and recoil.

	@class ImpulseCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")
local SummedCamera = require("SummedCamera")

local EPSILON = 1e-6

local ImpulseCamera = {}
ImpulseCamera.ClassName = "ImpulseCamera"

export type ImpulseCamera = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		Damper: number,
		Speed: number,
		Spring: Spring.Spring<Vector3>,
		_defaultSpring: Spring.Spring<Vector3>,
		_springs: { Spring.Spring<Vector3> },
	},
	{} :: typeof({ __index = ImpulseCamera })
)) & CameraEffectUtils.CameraEffect

function ImpulseCamera.new(): ImpulseCamera
	local self: ImpulseCamera = setmetatable(
		{
			_springs = {},
			_defaultSpring = Spring.new(Vector3.zero),
		} :: any,
		ImpulseCamera
	)

	self._defaultSpring.Damper = 0.5
	self._defaultSpring.Speed = 20

	return self
end

--[=[
	Applies an impulse to the camera, shaking it!
	@param velocity Vector3
	@param speed number? -- Optional
	@param damper number? -- Optional
]=]
function ImpulseCamera.Impulse(self: ImpulseCamera, velocity: Vector3, speed: number?, damper: number?): ()
	assert(typeof(velocity) == "Vector3", "Bad velocity")
	assert(type(speed) == "number" or speed == nil, "Bad speed")
	assert(type(damper) == "number" or damper == nil, "Bad damper")

	local spring = self:_getSpring(speed, damper)
	spring:Impulse(velocity)
end

--[=[
	Applies a random impulse

	@param velocity Vector3
	@param speed number? -- Optional
	@param damper number? -- Optional
]=]
function ImpulseCamera.ImpulseRandom(self: ImpulseCamera, velocity: Vector3, speed: number?, damper: number?): ()
	assert(typeof(velocity) == "Vector3", "Bad velocity")
	assert(type(speed) == "number" or speed == nil, "Bad speed")
	assert(type(damper) == "number" or damper == nil, "Bad damper")

	local randomVector = Vector3.new(2 * (math.random() - 0.5), 2 * (math.random() - 0.5), 2 * (math.random() - 0.5))

	return self:Impulse(velocity * randomVector, speed, damper)
end

function ImpulseCamera._getSpring(self: ImpulseCamera, speed: number?, damper: number?)
	if (not speed) and not damper then
		return self._defaultSpring
	end

	assert(speed ~= nil, "Type checker needs assert")
	assert(damper ~= nil, "Type checker needs assert")

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

function ImpulseCamera._aggregateSprings(self: ImpulseCamera): Vector3
	local position = self._defaultSpring.Position

	for i = #self._springs, 1, -1 do
		local spring = self._springs[i]
		local animating, springPosition = SpringUtils.animating(spring, EPSILON)

		position = position + springPosition
		if not animating then
			table.remove(self._springs, i)
		end
	end

	return position
end

function ImpulseCamera.__add(self: ImpulseCamera, other)
	return SummedCamera.new(self, other)
end

function ImpulseCamera.__newindex(self: ImpulseCamera, index, value)
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
function ImpulseCamera.__index(self: ImpulseCamera, index)
	if index == "CameraState" then
		local newState = CameraState.new()

		local position = self:_aggregateSprings()
		newState.CFrame = CFrame.Angles(0, position.Y, 0)
			* CFrame.Angles(position.X, 0, 0)
			* CFrame.Angles(0, 0, position.Z)

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
