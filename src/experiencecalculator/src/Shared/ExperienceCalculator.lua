--[=[
	Calculate experience on an exponential curve and perform relevant calculations.

	Uses formulas from https://stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp

	@class ExperienceCalculator
]=]

local ExperienceCalculator = {}
ExperienceCalculator._experienceFactor = 200

--[=[
	Sets the global experience factor to be used across this library.

	:::tip
	This API is global, poorly designed and will be refactored at some point.
	:::

	@param factor number
]=]
function ExperienceCalculator.setExperienceFactor(factor)
	ExperienceCalculator._experienceFactor = factor
end

--[=[
	Gets the current level from experience.
	@param experience number -- Current experience
	@return number -- The level the player should be
]=]
function ExperienceCalculator.getLevel(experience)
	local factor = ExperienceCalculator._experienceFactor
	return math.floor(
		(factor
			+ math.sqrt(factor*factor - 4*factor*(-experience)))
		/(2*factor))
end

--[=[
	Given a current level, return the experience required for the next one.
	@param currentLevel number -- The current level the player is
	@return number -- Experience required for next level
]=]
function ExperienceCalculator.getExperienceRequiredForNextLevel(currentLevel)
	return ExperienceCalculator._experienceFactor*(currentLevel*(1+currentLevel))
end

--[=[
	Gets experience required for a current level.
	@param level number
	@return number -- Total experience required for a level
]=]
function ExperienceCalculator.getExperienceRequiredForLevel(level)
	return ExperienceCalculator.getExperienceRequiredForNextLevel(level - 1)
end

--[=[
	Gets experience left to earn required for next level.
	@param currentExperience number -- Current experience of player
	@return number -- Experience points left to earn for the player
]=]
function ExperienceCalculator.getExperienceForNextLevel(currentExperience)
	if currentExperience - 1 == currentExperience then -- math.huge
		return 0
	end

	local currentLevel = ExperienceCalculator.getLevel(currentExperience)
	local experienceRequired = ExperienceCalculator.getExperienceRequiredForNextLevel(currentLevel)

	return experienceRequired - currentExperience
end

--[=[
	Calculates subtotal experience.
	@param currentExperience number -- Current experience of player
	@return number -- Achieved of next level
	@return number -- Total required for next level
]=]
function ExperienceCalculator.getSubExperience(currentExperience)
	if currentExperience - 1 == currentExperience then -- math.huge
		return 1, 1
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
