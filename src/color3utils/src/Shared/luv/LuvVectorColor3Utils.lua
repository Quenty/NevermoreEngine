--!strict
--[=[
	@class LuvVectorColor3Utils
]=]

local require = require(script.Parent.loader).load(script)

local LuvUtils = require("LuvUtils")

local LuvVectorColor3Utils = {}

--[=[
	Converts the Color3 to a Vector3 which can be interpolated by something
	like a spring.
	@param color3 Color3
	@return Vector3
]=]
function LuvVectorColor3Utils.fromColor3(color3: Color3): Vector3
	local hsl = LuvUtils.rgb_to_hsluv({ color3.R, color3.G, color3.B })

	-- Transform from -100% to 100% into 0 to 1 space
	return Vector3.new(hsl[1] / 200 + 0.5, hsl[2] / 200 + 0.5, hsl[3] / 200 + 0.5)
end

--[=[
	Converts the Vector3 to a Color3 assuming it is the interpolated version.
	@param luvV3 Vector3
	@return Color3
]=]
function LuvVectorColor3Utils.toColor3(luvV3: Vector3): Color3
	-- Transform out of this space
	return Color3.new(unpack(LuvUtils.hsluv_to_rgb({
		(luvV3.X - 0.5) * 200,
		(luvV3.Y - 0.5) * 200,
		(luvV3.Z - 0.5) * 200,
	})))
end

return LuvVectorColor3Utils
