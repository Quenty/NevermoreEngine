--!strict
--[=[
	Handles color manipulation in the HpLuv space.

	https://www.hsluv.org/comparison/

	@class LuvColor3Utils
]=]

local require = require(script.Parent.loader).load(script)

local LuvUtils = require("LuvUtils")
local Math = require("Math")

export type LUVColor3 = { number }

local LuvColor3Utils = {}

--[=[
	Interpolates in LUV space.
	@param color0 Color3
	@param color1 Color3
	@param t number
	@return Color3
]=]
function LuvColor3Utils.lerp(color0: Color3, color1: Color3, t: number): Color3
	assert(typeof(color0) == "Color3", "Bad color0")
	assert(typeof(color1) == "Color3", "Bad color0")
	assert(type(t) == "number", "Bad t")

	if t == 0 then
		return color0
	elseif t == 1 then
		return color1
	else
		local l0, u0, v0 = unpack(LuvColor3Utils.fromColor3(color0))
		local l1, u1, v1 = unpack(LuvColor3Utils.fromColor3(color1))

		local shortest_angle = ((((l1 - l0) % 360) + 540) % 360) - 180
		local l = l0 + shortest_angle * t
		local u = Math.lerp(u0, u1, t)
		local v = Math.lerp(v0, v1, t)

		return LuvColor3Utils.toColor3({ l, u, v })
	end
end

function LuvColor3Utils.desaturate(color0: Color3, proportion: number): Color3
	local l0, u0, v0 = unpack(LuvColor3Utils.fromColor3(color0))
	return LuvColor3Utils.toColor3({ l0, u0 * math.clamp(1 - proportion, 0, 1), v0 })
end

function LuvColor3Utils.darken(color0: Color3, proportion: number): Color3
	local l0, u0, v0 = unpack(LuvColor3Utils.fromColor3(color0))
	return LuvColor3Utils.toColor3({ l0, u0, v0 * math.clamp(1 - proportion, 0, 1) })
end

--[=[
	Converts from Color3 to LUV
	@param color3 Color3
	@return { number, number, number }
]=]
function LuvColor3Utils.fromColor3(color3: Color3): LUVColor3
	assert(typeof(color3) == "Color3", "Bad color3")

	return LuvUtils.rgb_to_hsluv({ color3.R, color3.G, color3.B })
end

--[=[
	Converts from LUV to Color3
	@param luv { number, number, number }
	@return Color3
]=]
function LuvColor3Utils.toColor3(luv: LUVColor3)
	assert(type(luv) == "table", "Bad luv")

	local r, g, b = unpack(LuvUtils.hsluv_to_rgb(luv))
	-- deal with floating point numbers
	return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

return LuvColor3Utils