--!strict
--[=[
	Utility to position the sun and to retrieve sun information specific to Roblox.

	Note this is not an accurate guess of where the sun would be on earth, but rather
	the computation to compute where Roblox is rendering the sun given the lighting
	properties set.

	https://raw.githubusercontent.com/iryl1/RBX_DOCUMENTATIONS/c0db57fedf0540db2cd9eb65404ad258c3e21295/lighting.md

	@class SunPositionUtils
]=]

local require = require(script.Parent.loader).load(script)

local Color3Utils = require("Color3Utils")
local ColorSequenceUtils = require("ColorSequenceUtils")

local SunPositionUtils = {}

local EARTH_TILT = 23.5
local NORTH = Vector3.new(0, 0, -1)
local ZAXIS = Vector3.new(0, 0, 1)

--[=[
	Gets the geographical latitude from a vector pointing at the sun.

	@param direction Vector3
	@return number
]=]
function SunPositionUtils.getGeographicalLatitudeFromDirection(direction: Vector3): number
	local x = direction.X
	local y = direction.Y
	local angle = math.atan2(direction.Z, math.sqrt(x * x + y * y))
	return angle / (math.pi * 2) * 360 + EARTH_TILT
end

SunPositionUtils.getGeographicalLatitudeFromMoonDirection = SunPositionUtils.getGeographicalLatitudeFromDirection

--[=[
	Gets the clock time for the given direction.

	@param direction Vector3
	@return number
]=]
function SunPositionUtils.getClockTimeFromDirection(direction: Vector3): number
	local altitude = math.atan2(-direction.Y, -direction.X)

	return (altitude / (math.pi * 2) * 24 - 6) % 24
end

--[=[
	Gets the clock time from the given moon direction.

	@param direction Vector3
	@return number
]=]
function SunPositionUtils.getClockTimeFromMoonDirection(direction: Vector3): number
	local altitude = math.atan2(direction.Y, direction.X)

	return (altitude / (math.pi * 2) * 24 - 6) % 24
end

--[=[
	Gets the direction the sun should be facing given the azimuth and altitude

	@param azimuthRad number
	@param altitudeRad number
	@param north Vector3?
	@return number
]=]
function SunPositionUtils.getDirection(azimuthRad: number, altitudeRad: number, north: Vector3): Vector3
	local cframe: CFrame = (CFrame.Angles(0, azimuthRad, 0) * CFrame.Angles(altitudeRad, 0, 0))
	return cframe:VectorToWorldSpace(north or NORTH)
end

export type SunPositionData = {
	sunPosition: Vector3,
	moonPosition: Vector3,
	clockTime: number,
	geoLatitude: number,
}

function SunPositionUtils.getSunPositionData(clockTime: number, geoLatitude: number): SunPositionData
	local seconds = clockTime * 60 * 60
	local DAY = 24 * 60 * 60
	local YEAR = 365.2564 * DAY
	local HALFYEAR = 182.6282
	local EARTHTILT = math.rad(23.5)

	local modTime = seconds - math.floor(seconds / DAY) * DAY
	local sourceAngle = 2 * math.pi * modTime / DAY
	local sunPosition = Vector3.new(math.sin(sourceAngle), -math.cos(sourceAngle), 0)
	local moonPosition = Vector3.new(math.sin(sourceAngle + math.pi), math.cos(sourceAngle + math.pi), 0)
	local dayOfYearOffset = (seconds - (seconds * math.floor(seconds / YEAR))) / DAY

	local latRad = math.rad(geoLatitude)
	local sunOffset = -EARTHTILT * math.cos(math.pi * (dayOfYearOffset - HALFYEAR) / HALFYEAR) - latRad

	local trueSunPosition = CFrame.fromAxisAngle(ZAXIS:Cross(sunPosition), sunOffset) * sunPosition
	local trueMoonPosition = CFrame.fromAxisAngle(ZAXIS:Cross(moonPosition), sunOffset)
		* moonPosition
		* Vector3.new(1, -1, 1)
	return {
		sunPosition = trueSunPosition,
		moonPosition = trueMoonPosition,
		clockTime = clockTime,
		geoLatitude = geoLatitude,
	}
end

--[=[
	Estimates the sun position given the clockTime and geographical latitude.

	@param clockTime number
	@param geoLatitude number
	@return Vector3 -- Sun position
	@return Vector3 -- Moon position
]=]
function SunPositionUtils.getSunPosition(clockTime: number, geoLatitude: number): (Vector3, Vector3)
	local data = SunPositionUtils.getSunPositionData(clockTime, geoLatitude)
	return data.sunPosition, data.moonPosition
end

--[=[
	A single float in `[0.1, 1.0]` that scales overall scene brightness. peaks at noon (`1.0`), bottoms out at midnight (`0.1`). derived directly from the sun's y position, which is itself just a function of clock time.
]=]
function SunPositionUtils.getLightSourceBrightness(sunPositionData: SunPositionData): number
	return math.clamp(math.map(sunPositionData.sunPosition.Y, -1, 1, 0.1, 1), 0.1, 1)
end

--[=[
	Gets the direction of the active light source (sun or moon). this is what actually tints shadows and direct illumination

	@param sunPositionData SunPositionData
	@return Vector3
]=]
function SunPositionUtils.getLightSourceDirection(sunPositionData: SunPositionData): Vector3
	if sunPositionData.sunPosition.Y > -0.3 then
		return sunPositionData.sunPosition
	else
		return sunPositionData.moonPosition
	end
end

local MIDNIGHT = 0
local SUNRISE = 6
local SUNSET = 18
local HOUR = 1
local DAY = 24
local SUN_RISE_AND_SET_TIME = HOUR / 2

local LIGHT_COLOR_SEQUENCE = ColorSequenceUtils.fromUnscaledTimesAndColors({
	MIDNIGHT,
	SUNRISE - HOUR,
	SUNRISE,
	SUNRISE + SUN_RISE_AND_SET_TIME / 4,
	SUNRISE + SUN_RISE_AND_SET_TIME,
	SUNSET - SUN_RISE_AND_SET_TIME,
	SUNSET - SUN_RISE_AND_SET_TIME / 2,
	SUNSET,
	SUNSET + HOUR / 2,
	DAY,
}, {
	Color3.new(0, 0, 0), -- midnight — black
	Color3.new(0, 0, 0), -- pre-dawn — black
	Color3.new(0.07, 0.07, 0.1), -- late pre-dawn — very dim blue
	Color3.new(0.2, 0.15, 0.01), -- near sunrise — warm amber
	Color3.new(0.2, 0.15, 0.01), -- sunrise — warm amber
	Color3.new(1, 1, 1), -- daytime — full white
	Color3.new(1, 1, 1), -- daytime
	Color3.new(0.4, 0.2, 0.05), -- sunset — orange-brown
	Color3.new(0, 0, 0), -- post-sunset — black
	Color3.new(0, 0, 0), -- midnight
})

local MIN_LIGHT_COLOR = Color3.new(0.35, 0.35, 0.35)

function SunPositionUtils._toScaledClockTime(unscaledTime: number): number
	return math.map(unscaledTime, 0, 24, 0, 1) % 1
end

--[=[
	The color of the active light source (sun or moon). this is what actually tints shadows and direct illumination
]=]
function SunPositionUtils.getLightColor(clockTime: number): Color3
	local color = ColorSequenceUtils.getColor(LIGHT_COLOR_SEQUENCE, SunPositionUtils._toScaledClockTime(clockTime))

	return Color3Utils.max(color, MIN_LIGHT_COLOR)
end

local DIFFUSE_AMBIENT_SEQUENCE = ColorSequenceUtils.fromUnscaledTimesAndColors({
	MIDNIGHT,
	SUNRISE - HOUR,
	SUNRISE,
	SUNRISE + SUN_RISE_AND_SET_TIME / 2,
	SUNRISE + SUN_RISE_AND_SET_TIME,
	SUNSET - SUN_RISE_AND_SET_TIME,
	SUNSET - SUN_RISE_AND_SET_TIME / 2,
	SUNSET,
	SUNSET + HOUR / 2,
	DAY,
}, {
	Color3.new(0.1, 0.1, 0.17), -- midnight — dim blue-grey
	Color3.new(0.05, 0.06, 0.07), -- pre-dawn — near black
	Color3.new(0.08, 0.08, 0.01), -- sunrise start — slight warm tint
	Color3.new(0.75, 0.75, 0.75), -- mid-sunrise — bright (white * 0.75)
	Color3.new(0.75, 0.75, 0.75), -- daytime — full bright
	Color3.new(0.35, 0.35, 0.35), -- late afternoon — dimming
	Color3.new(0.5, 0.2, 0.2), -- pre-sunset — warm pink
	Color3.new(0.05, 0.05, 0.1), -- sunset — dark blue
	Color3.new(0.06, 0.06, 0.07), -- post-sunset — near black
	Color3.new(0.1, 0.1, 0.17), -- back to midnight
})

--[=[
	The diffuse component of ambient — softer than direct light but still contributes to scene brightness. peaks at full white during the day.
]=]
function SunPositionUtils.getDiffuseAmbient(clockTime: number): Color3
	return ColorSequenceUtils.getColor(DIFFUSE_AMBIENT_SEQUENCE, SunPositionUtils._toScaledClockTime(clockTime))
end

--[=[
	The sky's contribution to ambient — this is what gives the sky its color cast on surfaces. ramps up around sunrise, stays on through sunset, then cuts out.

	This is the bottom color
]=]
function SunPositionUtils.getSkyAmbientBottom(clockTime: number, environmentDiffuseScale: number): Color3
	local midnight = 0.2 * environmentDiffuseScale
	local dark = environmentDiffuseScale / 2

	local SKY_AMBIENT_SEQUENCE = ColorSequenceUtils.fromUnscaledTimesAndColors({
		MIDNIGHT,
		SUNRISE - 2 * HOUR,
		SUNRISE - HOUR,
		SUNRISE - HOUR / 2,
		SUNRISE,
		SUNRISE + SUN_RISE_AND_SET_TIME,
		SUNSET - SUN_RISE_AND_SET_TIME,
		SUNSET,
		SUNSET + HOUR / 3,
		DAY,
	}, {
		Color3.new(midnight, midnight, midnight), -- midnight — black
		Color3.new(dark, dark, dark), -- pre-dawn — black
		Color3.new(0.07 + dark, 0.07 + dark, 0.1 + dark), -- late pre-dawn — very dim blue
		Color3.new(0.2 + dark, 0.15 + dark, 0.01 + dark), -- near sunrise — warm amber
		Color3.new(0.2 + dark, 0.15 + dark, 0.01 + dark), -- sunrise — warm amber
		Color3.new(1, 1, 1), -- daytime — full white
		Color3.new(1, 1, 1), -- daytime
		Color3.new(0.4 + dark, 0.2 + dark, 0.05 + dark), -- sunset — orange-brown
		Color3.new(dark, dark, dark), -- post-sunset — black
		Color3.new(midnight, midnight, midnight), -- midnight
	})

	return ColorSequenceUtils.getColor(SKY_AMBIENT_SEQUENCE, SunPositionUtils._toScaledClockTime(clockTime))
end

--[=[
	a second sky ambient spline — this one has a wider ramp and contributes additional sky color. the difference between `skyAmbientBottom` and `skyAmbientTop` gives you the gradient from horizon to zenith.

	This is the top color
]=]
function SunPositionUtils.getSkyAmbientTop(clockTime: number, environmentDiffuseScale: number): Color3
	local moon = 0.2 * environmentDiffuseScale
	local dark = environmentDiffuseScale / 2

	local SKY_AMBIENT_2_SEQUENCE = ColorSequenceUtils.fromUnscaledTimesAndColors({
		MIDNIGHT,
		SUNRISE - 3 * HOUR,
		SUNRISE - 2 * HOUR,
		SUNRISE - HOUR / 2,
		SUNRISE,
		SUNRISE + SUN_RISE_AND_SET_TIME,
		SUNSET - SUN_RISE_AND_SET_TIME,
		SUNSET,
		SUNSET + HOUR / 3,
		SUNSET + 2 * HOUR,
		SUNSET + 3 * HOUR,
		DAY,
	}, {
		Color3.new(dark, dark, dark), -- midnight
		Color3.new(moon, moon, moon), -- early pre-dawn — near black
		Color3.new(0.3 * 0.7, 0.3 * 0.7, 0.4 * 0.7), -- pre-dawn — dim blue-grey
		Color3.new(0.4, 0.3, 0.3), -- near sunrise — muted warm
		Color3.new(0.3, 0.2, 0.3), -- sunrise — muted purple-pink
		Color3.new(1, 1, 1), -- daytime
		Color3.new(1, 1, 1), -- daytime
		Color3.new(0.4, 0.3, 0.2), -- sunset — warm brown
		Color3.new(0.3, 0.2, 0.3), -- post-sunset — muted purple
		Color3.new(0.3, 0.2, 0.3), -- late post-sunset
		Color3.new(moon, moon, moon), -- night fade
		Color3.new(dark, dark, dark), -- midnight
	})

	return ColorSequenceUtils.getColor(SKY_AMBIENT_2_SEQUENCE, SunPositionUtils._toScaledClockTime(clockTime))
end

--[=[
	Gets the sun image brightness
]=]
function SunPositionUtils.getSunImageBrightness(sunPositionData: SunPositionData): number
	local brightness = 0.8 * math.clamp((sunPositionData.sunPosition.Y + 0.1) * 10, 0, 1)

	return brightness
end

--[=[
	Gets the moon image brightness
]=]
function SunPositionUtils.getMoonImageBrightness(
	sunPositionData: SunPositionData,
	environmentDiffuseScale: number
): number
	local skyAmbientBottom = SunPositionUtils.getSkyAmbientBottom(sunPositionData.clockTime, environmentDiffuseScale)
	local brightness = math.min((1 - skyAmbientBottom.R) + 0.1, 1)

	return brightness
end

--[=[
	Gets the sky ambient color sequence, which is a sunset glow during certain times of the day.
]=]
function SunPositionUtils.getSkyboxGradient(clockTime: number, environmentDiffuseScale: number): ColorSequence
	local bottom = SunPositionUtils.getSkyAmbientBottom(clockTime, environmentDiffuseScale)
	local top = SunPositionUtils.getSkyAmbientTop(clockTime, environmentDiffuseScale)

	return ColorSequence.new(bottom, top)
end

return SunPositionUtils
