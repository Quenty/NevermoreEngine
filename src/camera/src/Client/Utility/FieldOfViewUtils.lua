--!strict
--[=[
	Utility functions involving field of view.
	@class FieldOfViewUtils
]=]

local require = require(script.Parent.loader).load(script)

local Math = require("Math")

local FieldOfViewUtils = {}

--[=[
	Converts field of view to height
	@param fov number
	@return number
]=]
function FieldOfViewUtils.fovToHeight(fov: number): number
	return 2 * math.tan(math.rad(fov) / 2)
end

--[=[
	Converts height to field of view
	@param height number
	@return number
]=]
function FieldOfViewUtils.heightToFov(height: number): number
	return 2 * math.deg(math.atan(height / 2))
end

--[=[
	Linear way to log a value so we don't get floating point errors or infinite values
	@param height number
	@param linearAt number
	@return number
]=]
function FieldOfViewUtils.safeLog(height: number, linearAt: number): number
	if height < linearAt then
		local slope = 1 / linearAt
		return slope * (height - linearAt) + math.log(linearAt)
	else
		return math.log(height)
	end
end

--[=[
	Linear way to exponentiate field of view so we don't get floating point errors or
	infinite values.
	@param logHeight number
	@param linearAt number
	@return number
]=]
function FieldOfViewUtils.safeExp(logHeight: number, linearAt: number): number
	local transitionAt = math.log(linearAt)

	if logHeight <= transitionAt then
		return linearAt * (logHeight - transitionAt) + linearAt
	else
		return math.exp(logHeight)
	end
end

--[=[
	Interpolates field of view in height space, instead of degrees.
	@param fov0 number
	@param fov1 number
	@param percent number
	@return number -- Fov in degrees
]=]
function FieldOfViewUtils.lerpInHeightSpace(fov0: number, fov1: number, percent: number): number
	local height0 = FieldOfViewUtils.fovToHeight(fov0)
	local height1 = FieldOfViewUtils.fovToHeight(fov1)

	local linearAt = FieldOfViewUtils.fovToHeight(1)

	local logHeight0 = FieldOfViewUtils.safeLog(height0, linearAt)
	local logHeight1 = FieldOfViewUtils.safeLog(height1, linearAt)

	local newLogHeight = Math.lerp(logHeight0, logHeight1, percent)

	return FieldOfViewUtils.heightToFov(FieldOfViewUtils.safeExp(newLogHeight, linearAt))
end

return FieldOfViewUtils
