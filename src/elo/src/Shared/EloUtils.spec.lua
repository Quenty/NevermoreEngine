--[[
	Tests for elo utils
	@class EloUtils.spec.lua
]]

local EloUtils = require(script.Parent.EloUtils)

return function()
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
					EloUtils.MatchResult.PLAYER_ONE_WIN;
				})

			expect(newPlayerWinRating > playerRating).to.equal(true)
			expect(newOpponentWinRating < opponentRating).to.equal(true)
		end)

		it("should change on a loss", function()
			newPlayerLossRating, newOpponentLossRating = EloUtils.getNewElo(
				config,
				playerRating,
				opponentRating,
				{
					EloUtils.MatchResult.PLAYER_TWO_WIN;
				})

			expect(newPlayerLossRating < playerRating).to.equal(true)
			expect(newOpponentLossRating > opponentRating).to.equal(true)
		end)

		it("should change on a draw", function()
			newPlayerDrawRating, newOpponentDrawRating = EloUtils.getNewElo(
				config,
				playerRating,
				opponentRating,
				{
					EloUtils.MatchResult.DRAW;
				})

			expect(newPlayerDrawRating > playerRating).to.equal(true)
			expect(newOpponentDrawRating < opponentRating).to.equal(true)
		end)

		it("should change more on an unexpected win then a loss", function()
			local winChange = math.abs(playerRating - newPlayerWinRating)
			local drawChange = math.abs(playerRating - newPlayerDrawRating)
			local lossChange = math.abs(playerRating - newPlayerLossRating)

			expect(winChange > lossChange).to.equal(true)
			expect(winChange > drawChange ).to.equal(true)
			expect(drawChange > lossChange).to.equal(true)
		end)

		it("should compute percentile as 0.5", function()
			local percentile = EloUtils.getPercentile(config, 1400)

			expect(percentile).to.equal(0.5)
		end)
	end)
end
