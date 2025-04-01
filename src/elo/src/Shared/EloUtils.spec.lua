--[[
	Tests for elo utils
	@class EloUtils.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local EloMatchResult = require("EloMatchResult")
local EloUtils = require("EloUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("EloUtils.getNewElo", function()
	local config = EloUtils.createConfig()

	local playerRating = 1400
	local opponentRating = 1800

	local newPlayerWinRating, newOpponentWinRating
	local newPlayerLossRating, newOpponentLossRating
	local newPlayerDrawRating, newOpponentDrawRating

	it("should change on win", function()
		newPlayerWinRating, newOpponentWinRating = EloUtils.getNewElo(
			config,
			playerRating,
			opponentRating,
			{
				EloMatchResult.PLAYER_ONE_WIN;
			})

		expect(newPlayerWinRating > playerRating).toBe(true)
		expect(newOpponentWinRating < opponentRating).toBe(true)
	end)

	it("should change on a loss", function()
		newPlayerLossRating, newOpponentLossRating = EloUtils.getNewElo(
			config,
			playerRating,
			opponentRating,
			{
				EloMatchResult.PLAYER_TWO_WIN;
			})

		expect(newPlayerLossRating < playerRating).toBe(true)
		expect(newOpponentLossRating > opponentRating).toBe(true)
	end)

	it("should change on a draw", function()
		newPlayerDrawRating, newOpponentDrawRating = EloUtils.getNewElo(
			config,
			playerRating,
			opponentRating,
			{
				EloMatchResult.DRAW;
			})

		expect(newPlayerDrawRating > playerRating).toBe(true)
		expect(newOpponentDrawRating < opponentRating).toBe(true)
	end)

	it("should change more on an unexpected win then a loss", function()
		local winChange = math.abs(playerRating - newPlayerWinRating)
		local drawChange = math.abs(playerRating - newPlayerDrawRating)
		local lossChange = math.abs(playerRating - newPlayerLossRating)

		expect(winChange > lossChange).toBe(true)
		expect(winChange > drawChange ).toBe(true)
		expect(drawChange > lossChange).toBe(true)
	end)

	it("should compute percentile as 0.5", function()
		local percentile = EloUtils.getPercentile(config, 1400)

		expect(percentile).toBeCloseTo(0.5, 5)
	end)
end)