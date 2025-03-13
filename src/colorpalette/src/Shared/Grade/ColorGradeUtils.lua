--!strict
--[=[
	Helps with color grades, which is the concept where the darkness of the color
	goes from 0 to 100, with a grade of 100 being white, and a grade of 0 being
	black.

	Grades ensure a human-readable contrast value which means a grade contrast
	of 70 will always meet accessibility standards.

	@class ColorGradeUtils
]=]

local require = require(script.Parent.loader).load(script)

local LuvColor3Utils = require("LuvColor3Utils")

local ColorGradeUtils = {}

--[=[
	Adds to the grade and picks the direction to ensure the best amount of contrast.
	May consider using [ColorGradeUtils.ensureGradeContrast] for a more background
	aware contrast picker.

	@param grade number
	@param difference number
	@return number
]=]
function ColorGradeUtils.addGrade(grade: number, difference: number): number
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

function ColorGradeUtils.addGradeToColor(color: Color3, difference: number): Color3
	local grade = ColorGradeUtils.getGrade(color)
	return ColorGradeUtils.getGradedColor(color, ColorGradeUtils.addGrade(grade, difference))
end

--[=[
	Ensures the given contrast between the color and the backing, with
	an adjustment to saturation to keep the UI loking good

	@param color Color3
	@param backing Color3
	@param amount number -- Between 0 and 100
	@return Color3
]=]
function ColorGradeUtils.ensureGradeContrast(color: Color3, backing: Color3, amount: number): Color3
	local l, u, v = unpack(LuvColor3Utils.fromColor3(color))
	local _, _, bv = unpack(LuvColor3Utils.fromColor3(backing))

	local grade = 100 - v
	local backingGrade = 100 - bv

	local rel = grade - backingGrade

	-- Increase
	if math.abs(rel) >= amount then
		return color
	end

	local direction = math.sign(rel) > 0 and 1 or -1
	local newRel = direction * amount

	local newGrade = math.clamp(backingGrade + newRel, 0, 100)
	local otherNewGrade = math.clamp(backingGrade - newRel, 0, 100)

	local finalGrade
	if math.abs(newGrade - backingGrade) > math.abs(otherNewGrade - backingGrade) then
		finalGrade = newGrade
	else
		finalGrade = otherNewGrade
	end

	-- The further away from the original color the more we reduce vividness
	local proportion = math.min(amount, math.abs(finalGrade - grade)) / amount
	u = math.clamp((1 - 0.5 * proportion) * u, 0, 100)

	return LuvColor3Utils.toColor3({ l, u, 100 - finalGrade })
end

--[=[
	Gets the grade for a given color

	@param color Color3
	@return number
]=]
function ColorGradeUtils.getGrade(color: Color3): number
	assert(typeof(color) == "Color3", "Bad color")
	local _, _, v = unpack(LuvColor3Utils.fromColor3(color))

	return 100 - v
end

--[=[
	Converts a color into a graded version of that color.

	@param baseColor Color3
	@param colorGrade number -- 0 to 100
	@param vividness number?
	@return Color3
]=]
function ColorGradeUtils.getGradedColor(baseColor: Color3, colorGrade: number, vividness: number?): Color3
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