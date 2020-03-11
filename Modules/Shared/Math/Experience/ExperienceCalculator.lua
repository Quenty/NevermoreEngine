--- Calculate experience on an exponential curve and perform relevant calculations
-- Uses formulas from stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp
-- @module ExperienceCalculator

local ExperienceCalculator = {}
ExperienceCalculator._experienceFactor = 200

function ExperienceCalculator.setExperienceFactor(factor)
	ExperienceCalculator._experienceFactor = factor
end

--- Gets the current level from experience
-- @tparam number experience Current experience
-- @treturn number The level the player should be
function ExperienceCalculator.getLevel(experience)
	local factor = ExperienceCalculator._experienceFactor
	return math.floor(
		(factor
			+ math.sqrt(factor*factor - 4*factor*(-experience)))
		/(2*factor))
end

--- Given a current level, return the experience required for the next one
-- @tparam number currentLevel The current level the player is
-- @treturn number Experience required for next level
function ExperienceCalculator.getExperienceRequiredForNextLevel(currentLevel)
	return ExperienceCalculator._experienceFactor*(currentLevel*(1+currentLevel))
end

--- Gets experience required for a current level
-- @tparam number level
-- @treturn number total experience required for a level
function ExperienceCalculator.getExperienceRequiredForLevel(level)
	return ExperienceCalculator.getExperienceRequiredForNextLevel(level - 1)
end

--- Gets experience left to earn required for next level
-- @tparam number currentExperience Current experience of player
-- @treturn number experience Experience points left to earn for the player
function ExperienceCalculator.getExperienceForNextLevel(currentExperience)
	if currentExperience - 1 == currentExperience then -- math.huge
		return 0
	end

	local currentLevel = ExperienceCalculator.getLevel(currentExperience)
	local experienceRequired = ExperienceCalculator.getExperienceRequiredForNextLevel(currentLevel)

	return experienceRequired - currentExperience
end

--- Calculates subtotal experience
-- @tparam number currentExperience Current experience of player
-- @treturn number Achieved of next level
-- @treturn number Total required for next level
function ExperienceCalculator.getSubExperience(currentExperience)
	if currentExperience - 1 == currentExperience then -- math.huge
		return 1, 1, 1
	end

	local currentLevel = ExperienceCalculator.getLevel(currentExperience)
	local lastLevel = currentLevel-1

	local xpForCurrentLevel = ExperienceCalculator._experienceFactor*(lastLevel*(1+lastLevel))
	local experienceRequired = ExperienceCalculator._experienceFactor*(currentLevel*(1+currentLevel))

	local achievedOfNext = currentExperience - xpForCurrentLevel
	local subTotalRequired = experienceRequired - xpForCurrentLevel

	return achievedOfNext, subTotalRequired
end

return ExperienceCalculator
