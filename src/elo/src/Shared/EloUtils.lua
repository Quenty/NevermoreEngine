--[=[
	Utilities to compute [elo scores](https://en.wikipedia.org/wiki/Elo_rating_system) for players
	@class EloUtils

	```lua
	local config = EloUtils.createConfig()

	local playerRating = 1400
	local opponentRating = 1800

	-- Update rating!
	playerRating, opponentRating = EloUtils.getNewScores(
		config,
		playerRating,
		opponentRating,
		{
			EloUtils.Scores.WIN;
		})

	-- New rankings!
	print(playerRating, opponentRating)
	```
]=]

local EloUtils = {}

EloUtils.Scores = setmetatable({
	WIN = 1;
	DRAW = 0.5;
	LOSS = 0;
}, {
	__index = function()
		error("Bad index onto EloUtils.Scores")
	end;
})

--[=[
	@interface EloConfig
	.factor number
	.kfactor number | function
	.initial number
	.ratingFloor number
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
	}
end

--[=[
	Returns whether an object is an elo config

	@param config any
	@return boolean
]=]
function EloUtils.isEloConfig(config)
	return type(config) == "table"
end

--[=[
	Gets the new score for the player and opponent after a series of matches.

	@param config EloConfig
	@param playerRating number
	@param opponentRating number
	@param matchScores { number } -- 0 for loss, 1 for win, 0.5 for draw.
	@return number -- playerRating
	@return number -- opponentRating
]=]
function EloUtils.getNewScores(config, playerRating, opponentRating, matchScores)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerRating) == "number", "Bad playerRating")
	assert(type(opponentRating) == "number", "Bad opponentRating")
	assert(type(matchScores) == "table", "Bad matchScores")

	return EloUtils.getNewScore(config, playerRating, opponentRating, matchScores),
		EloUtils.getNewScore(config, opponentRating, playerRating, EloUtils.fromOpponentPerspective(matchScores))
end


--[=[
	Gets the new score for the player after a series of matches.

	@param config EloConfig
	@param playerRating number
	@param opponentRating number
	@param matchScores { number } -- 0 for loss, 1 for win, 0.5 for draw.
]=]
function EloUtils.getNewScore(config, playerRating, opponentRating, matchScores)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerRating) == "number", "Bad playerRating")
	assert(type(opponentRating) == "number", "Bad opponentRating")
	assert(type(matchScores) == "table", "Bad matchScores")

	return math.max(config.ratingFloor, playerRating + EloUtils.getScoreAdjustment(config, playerRating, opponentRating, matchScores))
end

--[=[
	Compute expected score for a player vs. player given the rating.

	:::info
	A player's expected score is their probability of winning plus half their probability of drawing. Thus, an expected score of 0.75 could represent a 75% chance of winning, 25% chance of losing, and 0% chance of drawing
	:::

	@param config EloConfig
	@param playerRating number
	@param opponentRating number
	@return number
]=]
function EloUtils.getExpected(config, playerRating, opponentRating)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerRating) == "number", "Bad playerRating")
	assert(type(opponentRating) == "number", "Bad opponentRating")

	local diff = opponentRating - playerRating
	return 1 / (1 + 10 ^ (diff / config.factor))
end

--[=[
	Gets the score adjustment for a given player's base.

	@param config EloConfig
	@param playerRating number
	@param opponentRating number
	@param matchScores { number } -- 0 for loss, 1 for win, 0.5 for draw.
	@return number
]=]
function EloUtils.getScoreAdjustment(config, playerRating, opponentRating, matchScores)
	assert(EloUtils.isEloConfig(config), "Bad config")
	assert(type(playerRating) == "number", "Bad playerRating")
	assert(type(opponentRating) == "number", "Bad opponentRating")
	assert(type(matchScores) == "table", "Bad matchScores")

	local adjustment = 0
	local expected = EloUtils.getExpected(config, playerRating, opponentRating)

	for _, score in pairs(matchScores) do
		adjustment = adjustment + (score - expected)
	end

	local kfactor = EloUtils.extractKFactor(config, playerRating)
	return kfactor*adjustment
end

--[=[
	Flips the scores for the opponent

	@param matchScores { number } -- 0 for loss, 1 for win, 0.5 for draw.
	@return { number }
]=]
function EloUtils.fromOpponentPerspective(matchScores)
	assert(type(matchScores) == "table", "Bad matchScores")

	local newScores = {}

	for index, score in pairs(matchScores) do
		newScores[index] = 1 - score
	end

	return newScores
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
