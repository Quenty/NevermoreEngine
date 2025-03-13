--!strict
--[=[
	Calculate experience on an exponential curve and perform relevant calculations.

	Uses formulas from https://stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp

	```lua
	local config = ExperienceUtils.createExperienceConfig({
		factor = 200;
	})

	local totalExperience = 2000
	local level = ExperienceUtils.getLevel(config, totalExperience)
	local percentDone = ExperienceUtils.percentLevelComplete(config, totalExperience)
	```
	@class ExperienceUtils
]=]

local ExperienceUtils = {}

export type ExperienceConfig = {
	factor: number,
	maxLevel: number,
}

--[=[
	Creates a new experience configuration to be used

	@param options ExperienceConfig
	@return ExperienceConfig
]=]
function ExperienceUtils.createExperienceConfig(options: ExperienceConfig): ExperienceConfig
	assert(type(options) == "table", "Bad options")

	return {
		factor = options.factor or 200,
		maxLevel = options.maxLevel or math.huge,
	}
end

--[=[
	Returns whether a value is an experience config

	@param value any
	@return boolean
]=]
function ExperienceUtils.isExperienceConfig(value: any): boolean
	return type(value) == "table" and type(value.factor) == "number"
end

--[=[
	Gets the current level from experience.

	@param config ExperienceConfig
	@param totalExperience number
	@return number -- Level
]=]
function ExperienceUtils.getLevel(config: ExperienceConfig, totalExperience: number): number
	assert(ExperienceUtils.isExperienceConfig(config), "Bad experience config")
	assert(type(totalExperience) == "number", "Bad totalExperience")

	local factor = config.factor
	local level = math.floor((factor + math.sqrt(factor * factor - 4 * factor * -totalExperience)) / (2 * factor))
	if level >= config.maxLevel then
		return config.maxLevel
	else
		return level
	end
end

--[=[
	Gets experience required for a current level. Once the experience is
	equal to this threshold, or greater, then the level is considered
	earned.

	@param config ExperienceConfig
	@param level number
	@return number -- Total experience required for a level
]=]
function ExperienceUtils.experienceFromLevel(config: ExperienceConfig, level: number): number
	assert(ExperienceUtils.isExperienceConfig(config), "Bad experience config")
	assert(type(level) == "number", "Bad level")

	return config.factor * level * (level - 1)
end

--[=[
	For this level only, how much experience is earned.

	@param config ExperienceConfig
	@param totalExperience number
	@return number
]=]
function ExperienceUtils.levelExperienceEarned(config: ExperienceConfig, totalExperience: number): number
	assert(ExperienceUtils.isExperienceConfig(config), "Bad experience config")
	assert(type(totalExperience) == "number", "Bad totalExperience")

	if totalExperience ~= totalExperience then -- math.huge
		return 0
	end

	local currentLevel = ExperienceUtils.getLevel(config, totalExperience)
	if currentLevel >= config.maxLevel then
		return 0
	end

	local levelExperience = ExperienceUtils.experienceFromLevel(config, currentLevel)

	return totalExperience - levelExperience
end

--[=[
	For this level only, how much experience is left to earn.

	@param config ExperienceConfig
	@param totalExperience number
	@return number
]=]
function ExperienceUtils.levelExperienceLeft(config: ExperienceConfig, totalExperience: number): number
	assert(ExperienceUtils.isExperienceConfig(config), "Bad experience config")
	assert(type(totalExperience) == "number", "Bad totalExperience")

	if totalExperience ~= totalExperience then -- math.huge
		return 0
	end

	local currentLevel = ExperienceUtils.getLevel(config, totalExperience)
	if currentLevel >= config.maxLevel then
		return 0
	end

	local experienceRequired = ExperienceUtils.experienceFromLevel(config, currentLevel + 1)

	return experienceRequired - totalExperience
end

--[=[
	For this level only, how much experience is required

	@param config ExperienceConfig
	@param totalExperience number -- Current experience of player
	@return number -- Total required for next level
]=]
function ExperienceUtils.levelExperienceRequired(config: ExperienceConfig, totalExperience: number): number
	assert(ExperienceUtils.isExperienceConfig(config), "Bad experience config")
	assert(type(totalExperience) == "number", "Bad totalExperience")

	if totalExperience ~= totalExperience then -- math.huge
		return 0
	end

	local currentLevel = ExperienceUtils.getLevel(config, totalExperience)
	if currentLevel >= config.maxLevel then
		return 0
	end

	local thisLevelExperience = ExperienceUtils.experienceFromLevel(config, currentLevel)
	local nextLevelExperience = ExperienceUtils.experienceFromLevel(config, currentLevel + 1)
	return nextLevelExperience - thisLevelExperience
end

--[=[
	Returns the percent of the level complete

	@param config ExperienceConfig
	@param totalExperience number
	@return number
]=]
function ExperienceUtils.percentLevelComplete(config: ExperienceConfig, totalExperience: number): number
	assert(ExperienceUtils.isExperienceConfig(config), "Bad experience config")
	assert(type(totalExperience) == "number", "Bad totalExperience")

	if totalExperience ~= totalExperience then -- math.huge
		return 0
	end

	local earned = ExperienceUtils.levelExperienceEarned(config, totalExperience)
	local required = ExperienceUtils.levelExperienceRequired(config, totalExperience)

	if required == 0 then
		return 0
	end

	return earned/required
end

return ExperienceUtils
