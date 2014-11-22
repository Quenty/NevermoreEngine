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
	
	local CurrentLevel = GetLevelFromExperience(CurrentExperience)
	local ExperienceRequired = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))
	--local ExperienceRequiredForCurrentLevel = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))

	local ExperienceLeft = ExperienceRequired - CurrentExperience
	
	return ExperienceLeft
end
ExperienceCalculator.GetExperienceForNextLevel = GetExperienceForNextLevel

local function GetSubExperience(CurrentExperience)
	-- @return Achieved of next level, Total required for next level, Percent
	
	if CurrentExperience - 1 == CurrentExperience then -- Math.huge
		return 1,1,1
	end
	
	local CurrentLevel = GetLevelFromExperience(CurrentExperience)
	local LastLevel = CurrentLevel-1
	
	local ExperienceRequiredForCurrentLevel = ExperienceFactor*(LastLevel*(1+LastLevel))
	local ExperienceRequired = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))
	
	--[[print("CurrentExperience", CurrentExperience)
	print("CurrentLevel", CurrentLevel)
	print("ExperienceRequiredForCurrentLevel", ExperienceRequiredForCurrentLevel)
	
	print("ExperienceRequired", ExperienceRequired)--]]
	
	local AchievedOfNext = CurrentExperience - ExperienceRequiredForCurrentLevel 
	local TotalRequired = ExperienceRequired - ExperienceRequiredForCurrentLevel
	local Percent = AchievedOfNext/ExperienceRequired
	
	return AchievedOfNext, TotalRequired, Percent
end
ExperienceCalculator.GetSubExperience = GetSubExperience

return ExperienceCalculator