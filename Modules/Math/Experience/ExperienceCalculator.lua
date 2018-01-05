--- Calculate experience on an exponential curve and perform relevant calculations
-- Uses formulas from stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp
-- @module ExperienceCalculator

local EXPERIENCE_FACTOR = 200

local lib = {}

--- Gets the current level from experience
-- @tparam number experience Current experience
-- @treturn number The level the player should be
function lib.GetLevelFromExperience(experience)
	return math.floor(
		(EXPERIENCE_FACTOR + math.sqrt(EXPERIENCE_FACTOR*EXPERIENCE_FACTOR - 4*EXPERIENCE_FACTOR*(-experience)))
		/(2*EXPERIENCE_FACTOR))
end

--- Given a current level, return the experience required for the next one
-- @tparam number currentLevel The current level the player is
-- @treturn number Experience required for next level
function lib.GetExperienceRequiredForNextLevel(currentLevel)
	return EXPERIENCE_FACTOR*(currentLevel*(1+currentLevel))
end

--- Gets experience required for a current level
-- @tparam number level
-- @treturn number total experience required for a level
function lib.GetExperienceRequiredForLevel(level)
	return lib.GetExperienceRequiredForNextLevel(level - 1)
end

--- Gets experience left to earn required for next level
-- @tparam number currentExperience Current experience of player
-- @treturn number experience Experience points left to earn for the player
function lib.GetExperienceForNextLevel(currentExperience)
	if currentExperience - 1 == currentExperience then -- math.huge
		return 0
	end
	
	local currentLevel = lib.GetLevelFromExperience(currentExperience)
	local experieneRequired = lib.GetExperienceRequiredForNextLevel(currentLevel)

	return experieneRequired - currentExperience
end

--- Calculates subtotal experience
-- @tparam number currentExperience Current experience of player
-- @treturn number Achieved of next level
-- @treturn number Total required for next level
-- @treturn number Percent
function lib.GetSubExperience(currentExperience)
	if currentExperience - 1 == currentExperience then -- math.huge
		return 1, 1, 1
	end
	
	local currentLevel = lib.GetLevelFromExperience(currentExperience)
	local lastLevel = currentLevel-1
	
	local xpForCurrentLevel = EXPERIENCE_FACTOR*(lastLevel*(1+lastLevel))
	local experienceRequired = EXPERIENCE_FACTOR*(currentLevel*(1+currentLevel))
	
	local achievedOfNext = currentExperience - xpForCurrentLevel
	local subTotalRequired = experienceRequired - xpForCurrentLevel
	local percent = achievedOfNext/subTotalRequired
	
	return achievedOfNext, subTotalRequired, percent
end

return lib