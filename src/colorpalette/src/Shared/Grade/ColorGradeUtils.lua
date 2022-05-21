--[=[
	@class ColorGradeUtils
]=]

local require = require(script.Parent.loader).load(script)

local LuvColor3Utils = require("LuvColor3Utils")

local ColorGradeUtils = {}

function ColorGradeUtils.addGrade(grade, difference)
	local finalGrade = grade + difference

	if finalGrade > 100 or finalGrade < 0 then
		local otherFinalGrade = grade - difference

		-- Ensure enough contrast so go in the other direction...
		local dist = math.abs(math.clamp(finalGrade, 0, 100) - grade)
		local newDist = math.abs(math.clamp(otherFinalGrade, 0, 100) - grade)

		if newDist > dist then
			finalGrade = otherFinalGrade
		end
	end

	return finalGrade
end

function ColorGradeUtils.getGradedColor(baseColor, colorGrade, vividness)
	assert(typeof(baseColor) == "Color3", "Bad baseColor")
	assert(type(vividness) == "number" or vividness == nil, "Bad vividness")
	assert(type(colorGrade) == "number", "Bad colorGrade")

	local l, u, v = unpack(LuvColor3Utils.fromColor3(baseColor))

	colorGrade = math.clamp(colorGrade, 0, 100)

	if vividness then
		-- -- Desaturate as if we're mixing in black/white
		-- local towardsOffset = (colorGrade - v)/100
		-- local scaleTowards = math.clamp(math.abs(towardsOffset), 0, 1)^vividness
		-- u = math.clamp(Math.map(scaleTowards, 0, 1, u, 0), 0, 100)
		u = math.clamp(vividness*u, 0, 100)
	end

	v = 100 - colorGrade

	return LuvColor3Utils.toColor3({l, u, v})
end

return ColorGradeUtils