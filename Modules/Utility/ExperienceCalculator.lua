local ExperienceCalculator = {}
local ExperienceFactor = 200

function ExperienceCalculator.GetLevelFromExperience(Experience)
	-- http://stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp
	
	return math.floor((ExperienceFactor + math.sqrt(ExperienceFactor * ExperienceFactor - 4 * ExperienceFactor * (-Experience)))/ (2 * ExperienceFactor))
end

function ExperienceCalculator.GetExperienceForNextLevel(CurrentExperience)
	if CurrentExperience - 1 == CurrentExperience then -- Math.huge
		return 0
	end
	
	local CurrentLevel = ExperienceCalculator.GetLevelFromExperience(CurrentExperience)
	local ExperienceRequired = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))
	--local ExperienceRequiredForCurrentLevel = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))

	local ExperienceLeft = ExperienceRequired - CurrentExperience
	
	return ExperienceLeft
end

function ExperienceCalculator.GetExperienceRequiredForLevel(Level)
	Level = Level - 1 -- Because normally this formula calculates experience required for next level.
	return ExperienceFactor*(Level*(1+Level))
end

function ExperienceCalculator.GetSubExperience(CurrentExperience)
	-- @return Achieved of next level, Total required for next level, Percent
	
	if CurrentExperience - 1 == CurrentExperience then -- Math.huge
		return 1,1,1
	end
	
	local CurrentLevel = ExperienceCalculator.GetLevelFromExperience(CurrentExperience)
	local LastLevel = CurrentLevel-1
	
	local ExperienceRequiredForCurrentLevel = ExperienceFactor*(LastLevel*(1+LastLevel))
	local ExperienceRequired = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))
	
	--[[print("CurrentExperience", CurrentExperience)
	print("CurrentLevel", CurrentLevel)
	print("ExperienceRequiredForCurrentLevel", ExperienceRequiredForCurrentLevel)
	
	print("ExperienceRequired", ExperienceRequired)--]]
	
	local AchievedOfNext = CurrentExperience - ExperienceRequiredForCurrentLevel 
	local SubTotalRequired = ExperienceRequired - ExperienceRequiredForCurrentLevel
	local Percent = AchievedOfNext/SubTotalRequired
	
	return AchievedOfNext, SubTotalRequired, Percent
end

return ExperienceCalculator
