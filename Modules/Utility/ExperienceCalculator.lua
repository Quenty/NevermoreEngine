local ExperienceCalculator = {}
local ExperienceFactor = 200

local function GetLevelFromExperience(Experience)
	-- http://stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp
	
	return math.floor((ExperienceFactor + math.sqrt(ExperienceFactor * ExperienceFactor - 4 * ExperienceFactor * (-Experience)))/ (2 * ExperienceFactor))
end
ExperienceCalculator.GetLevelFromExperience = GetLevelFromExperience

local function GetExperienceForNextLevel(CurrentExperience)
	if CurrentExperience - 1 == CurrentExperience then -- Math.huge
		return 0
	end
	
	local NextLevel = GetLevelFromExperience(CurrentExperience)+1
	local ExperienceRequired = ExperienceFactor*(NextLevel*(1+NextLevel))

	return ExperienceRequired - CurrentExperience
end
ExperienceCalculator.GetExperienceForNextLevel = GetExperienceForNextLevel

return ExperienceCalculator