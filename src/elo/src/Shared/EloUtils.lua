--[=[
	Utilities to compute elo scores for players
	@class EloUtils

	```lua
	local config = EloUtils.createConfig()

	local playerOneRating = 1400
	local playerTwoRating = 1800

	-- Update rating!
	playerOneRating, playerTwoRating = EloUtils.getNewElo(
		config,
		playerOneRating,
		playerTwoRating,
		{
			EloMatchResult.PLAYER_ONE_WIN;
		})

	-- New rankings!
	print(playerOneRating, playerTwoRating)
	```
]=]

local require = require(script.Parent.loader).load(script)

local EloMatchResult = require("EloMatchResult")
local EloMatchResultUtils = require("EloMatchResultUtils")
local Probability = require("Probability")

local EloUtils = {}

--[=[
	@interface EloConfig
	.factor number
	.kfactor number | function
	.initial number
	.ratingFloor number
	.groupMultipleResultAsOne boolean
	@within EloUtils
]=]

--[=[
	Creates a new elo config.
	@param config table? -- Optional table with defaults
	@return EloConfig
]=]
function EloUtils.createConfig(config)
	config = config or {}

	return {
		factor = config.factor or 400;
		kfactor = config.kfactor or EloUtils.standardKFactorFormula;
		initial = config.initial or 1400;
		ratingFloor = config.ratingFloor or 100;
		groupMultipleResultAsOne = false;
	}
end

--[=[
	Returns whether an object is an elo config

	@param config any
	@return boolean
]=]
function EloUtils.isEloConfig(config)
	return type(config) == "table"
		and type(config.factor) == "number"
		and (type(config.kfactor) == "number" or type(config.kfactor) == "function")
		and type(config.initial) == "number"
		and type(config.ratingFloor) == "number"
		and type(config.groupMultipleResultAsOne) == "boolean"
end

--[=[
	Gets the standard deviation of the elo curve

	@param eloConfig EloConfig
	@return number
]=]
function EloUtils.getStandardDeviation(eloConfig)
	assert(EloUtils.isEloConfig(eloConfig), "Bad eloConfig")

	return 0.5*eloConfig.factor*math.sqrt(2)
end

--[=[
	Gets the standard deviation of the elo curve from 0 to 1

	@param eloConfig EloConfig
	@return number
]=]
function EloUtils.getPercentile(eloConfig, elo)
	assert(EloUtils.isEloConfig(eloConfig), "Bad eloConfig")

	local standardDeviation = EloUtils.getStandardDeviation(eloConfig)
	local mean = eloConfig.initial

	local zScore = (elo - mean)/standardDeviation
	return Probability.cdf(zScore)
end

--[=[
	Gets the standard deviation of the elo curve from 0 to 1

	@param eloConfig EloConfig
	@return number
]=]
function EloUtils.percentileToElo(eloConfig, percentile)
	assert(EloUtils.isEloConfig(eloConfig), "Bad eloConfig")

	local standardDeviation = EloUtils.getStandardDeviation(eloConfig)
	local mean = eloConfig.initial

	local zScore = Probability.percentileToZScore(percentile)
	return mean + zScore*standardDeviation
end

--[=[
	Gets the new score for the player and opponent after a series of matches.

	@param config EloConfig
	@param playerOneRating number
	@param playerTwoRating number
	@param eloMatchResultList { EloMatchResult }
	@return number -- playerOneRating
	@return number -- playerTwoRating
]=]
function EloUtils.getNewElo(config, playerOneRating, playerTwoRating, eloMatchResultList)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerOneRating) == "number", "Bad playerOneRating")
	assert(type(playerTwoRating) == "number", "Bad playerTwoRating")
	assert(EloMatchResultUtils.isEloMatchResultList(eloMatchResultList), "Bad eloMatchResultList")

	local newPlayerOneRating = EloUtils.getNewPlayerOneScore(config, playerOneRating, playerTwoRating, eloMatchResultList)
	local newPlayerTwoRating = EloUtils.getNewPlayerOneScore(config, playerTwoRating, playerOneRating, EloUtils.fromOpponentPerspective(eloMatchResultList))
	return newPlayerOneRating, newPlayerTwoRating
end

--[=[
	Gets the change in elo for the given players and the results

	@param config EloConfig
	@param playerOneRating number
	@param playerTwoRating number
	@param eloMatchResultList { EloMatchResult }
	@return number -- playerOneRating
	@return number -- playerTwoRating
]=]
function EloUtils.getEloChange(config, playerOneRating, playerTwoRating, eloMatchResultList)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerOneRating) == "number", "Bad playerOneRating")
	assert(type(playerTwoRating) == "number", "Bad playerTwoRating")
	assert(EloMatchResultUtils.isEloMatchResultList(eloMatchResultList), "Bad eloMatchResultList")

	local newPlayerOneRating, newPlayerTwoRating = EloUtils.getNewElo(config, playerOneRating, playerTwoRating, eloMatchResultList)
	local playerOneChange = newPlayerOneRating - playerOneRating
	local playerTwoChange = newPlayerTwoRating - playerTwoRating
	return playerOneChange, playerTwoChange
end

--[=[
	Gets the new score for the player after a series of matches.

	@param config EloConfig
	@param playerOneRating number
	@param playerTwoRating number
	@param eloMatchResultList { EloMatchResult }
]=]
function EloUtils.getNewPlayerOneScore(config, playerOneRating, playerTwoRating, eloMatchResultList)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerOneRating) == "number", "Bad playerOneRating")
	assert(type(playerTwoRating) == "number", "Bad playerTwoRating")
	assert(EloMatchResultUtils.isEloMatchResultList(eloMatchResultList), "Bad eloMatchResultList")

	return math.max(config.ratingFloor, playerOneRating + EloUtils.getPlayerOneScoreAdjustment(config, playerOneRating, playerTwoRating, eloMatchResultList))
end

--[=[
	Compute expected score for a player vs. player given the rating.

	:::info
	A player's expected score is their probability of winning plus half their probability of drawing. Thus, an expected score of 0.75 could represent a 75% chance of winning, 25% chance of losing, and 0% chance of drawing
	:::

	@param config EloConfig
	@param playerOneRating number
	@param playerTwoRating number
	@return number
]=]
function EloUtils.getPlayerOneExpected(config, playerOneRating, playerTwoRating)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerOneRating) == "number", "Bad playerOneRating")
	assert(type(playerTwoRating) == "number", "Bad playerTwoRating")

	local diff = playerTwoRating - playerOneRating
	return 1 / (1 + 10 ^ (diff / config.factor))
end

--[=[
	Gets the score adjustment for a given player's base.

	@param config EloConfig
	@param playerOneRating number
	@param playerTwoRating number
	@param eloMatchResultList { EloMatchResult }
	@return number
]=]
function EloUtils.getPlayerOneScoreAdjustment(config, playerOneRating, playerTwoRating, eloMatchResultList)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerOneRating) == "number", "Bad playerOneRating")
	assert(type(playerTwoRating) == "number", "Bad playerTwoRating")
	assert(EloMatchResultUtils.isEloMatchResultList(eloMatchResultList), "Bad eloMatchResultList")

	local adjustment = 0
	local expected = EloUtils.getPlayerOneExpected(config, playerOneRating, playerTwoRating)

	if config.groupMultipleResultAsOne then
		local wins = EloUtils.countPlayerOneWins(eloMatchResultList)
		local losses = EloUtils.countPlayerTwoWins(eloMatchResultList)
		local score = wins > losses and 1 or 0
		local multiplier = 1

		if wins > losses then
			multiplier = wins
		else
			multiplier = losses
		end

		adjustment = multiplier*(score - expected)
	else
		for _, score in pairs(eloMatchResultList) do
			adjustment = adjustment + (score - expected)
		end
	end

	local kfactor = EloUtils.extractKFactor(config, playerOneRating)
	return kfactor*adjustment
end

--[=[
	Flips the scores for the opponent

	@param eloMatchResultList { EloMatchResult }
	@return { number }
]=]
function EloUtils.fromOpponentPerspective(eloMatchResultList)
	assert(EloMatchResultUtils.isEloMatchResultList(eloMatchResultList), "Bad eloMatchResultList")

	local newScores = {}

	for index, score in pairs(eloMatchResultList) do
		newScores[index] = 1 - score
	end

	return newScores
end

--[=[
	Counts the number of wins for player one

	@param eloMatchResultList { EloMatchResult }
	@return { number }
]=]
function EloUtils.countPlayerOneWins(eloMatchResultList)
	assert(EloMatchResultUtils.isEloMatchResultList(eloMatchResultList), "Bad eloMatchResultList")

	local count = 0
	for _, score in pairs(eloMatchResultList) do
		if score == EloMatchResult.PLAYER_ONE_WIN then
			count = count + 1
		end
	end
	return count
end

--[=[
	Counts the number of wins for player two

	@param eloMatchResultList { EloMatchResult }
	@return { number }
]=]
function EloUtils.countPlayerTwoWins(eloMatchResultList)
	assert(EloMatchResultUtils.isEloMatchResultList(eloMatchResultList), "Bad eloMatchResultList")

	local count = 0
	for _, score in pairs(eloMatchResultList) do
		if score == EloMatchResult.PLAYER_TWO_WIN then
			count = count + 1
		end
	end
	return count
end

--[=[
	Standard kfactor formula for use in the elo config.

	@param rating number
	@return number
]=]
function EloUtils.standardKFactorFormula(rating)
	if rating >= 2400 then
		return 16
	elseif rating >= 2100 then
		return 24
	else
		return 32
	end
end

--[=[
	Computes the kfactor for the given player from the rating

	@param config EloConfig
	@param rating number
	@return number
]=]
function EloUtils.extractKFactor(config, rating)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(rating) == "number", "Bad rating")

	if type(config.kfactor) == "function" then
		return config.kfactor(rating)
	elseif type(config.kfactor) == "number" then
		return config.kfactor
	else
		error("Bad kfactor")
	end
end

return EloUtils