local lib = {}
local ExperienceFactor = 200

-- Intent: Calculate experience on an exponential curve and perform relevant calculations
-- See: stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp

local function GetLevelFromExperience(Experience)	
	return math.floor((ExperienceFactor + math.sqrt(ExperienceFactor * ExperienceFactor - 4 * ExperienceFactor * (-Experience)))/ (2 * ExperienceFactor))
end
lib.GetLevelFromExperience = GetLevelFromExperience

local function GetExperienceForNextLevel(CurrentExperience)
	if CurrentExperience - 1 == CurrentExperience then -- Math.huge
		return 0
	end
	
	local CurrentLevel = GetLevelFromExperience(CurrentExperience)
	local ExperienceRequired = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))

	local ExperienceLeft = ExperienceRequired - CurrentExperience
	
	return ExperienceLeft
end
lib.GetExperienceForNextLevel = GetExperienceForNextLevel

local function GetExperienceRequiredForLevel(Level)
	Level = Level - 1 -- Because normally this formula calculates experience required for next level.
	return ExperienceFactor*(Level*(1+Level))
end
lib.GetExperienceRequiredForLevel = GetExperienceRequiredForLevel

local function GetSubExperience(CurrentExperience)
	-- @return Achieved of next level, Total required for next level, Percent
	
	if CurrentExperience - 1 == CurrentExperience then -- Math.huge
		return 1,1,1
	end
	
	local CurrentLevel = GetLevelFromExperience(CurrentExperience)
	local LastLevel = CurrentLevel-1
	
	local ExperienceRequiredForCurrentLevel = ExperienceFactor*(LastLevel*(1+LastLevel))
	local ExperienceRequired = ExperienceFactor*(CurrentLevel*(1+CurrentLevel))
	
	local AchievedOfNext = CurrentExperience - ExperienceRequiredForCurrentLevel 
	local SubTotalRequired = ExperienceRequired - ExperienceRequiredForCurrentLevel
	local Percent = AchievedOfNext/SubTotalRequired
	
	return AchievedOfNext, SubTotalRequired, Percent
end
lib.GetSubExperience = GetSubExperience

return lib