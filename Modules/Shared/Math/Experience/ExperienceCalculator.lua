--- Calculate experience on an exponential curve and perform relevant calculations
-- Uses formulas from stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp
-- @module ExperienceCalculator

local lib = {}
lib._experienceFactor = 200

function lib.SetExperienceFactor(factor)
	lib._experienceFactor = factor
end

--- Gets the current level from experience
-- @tparam number experience Current experience
-- @treturn number The level the player should be
function lib.GetLevel(experience)
	return math.floor(
		(lib._experienceFactor + math.sqrt(lib._experienceFactor*lib._experienceFactor - 4*lib._experienceFactor*(-experience)))
		/(2*lib._experienceFactor))
end

--- Given a current level, return the experience required for the next one
-- @tparam number currentLevel The current level the player is
-- @treturn number Experience required for next level
function lib.GetExperienceRequiredForNextLevel(currentLevel)
	return lib._experienceFactor*(currentLevel*(1+currentLevel))
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

	local currentLevel = lib.GetLevel(currentExperience)
	local experienceRequired = lib.GetExperienceRequiredForNextLevel(currentLevel)

	return experienceRequired - currentExperience
end

--- Calculates subtotal experience
-- @tparam number currentExperience Current experience of player
-- @treturn number Achieved of next level
-- @treturn number Total required for next level
function lib.GetSubExperience(currentExperience)
	if currentExperience - 1 == currentExperience then -- math.huge
		return 1, 1, 1
	end

	local currentLevel = lib.GetLevel(currentExperience)
	local lastLevel = currentLevel-1

	local xpForCurrentLevel = lib._experienceFactor*(lastLevel*(1+lastLevel))
	local experienceRequired = lib._experienceFactor*(currentLevel*(1+currentLevel))

	local achievedOfNext = currentExperience - xpForCurrentLevel
	local subTotalRequired = experienceRequired - xpForCurrentLevel

	return achievedOfNext, subTotalRequired
end

return lib
