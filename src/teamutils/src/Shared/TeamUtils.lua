--!strict
--[=[
	Team utility methods
	@class TeamUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerMock = require("PlayerMock")

local TeamUtils = {}

--[=[
	Returns whether the two players are on the same team
]=]
function TeamUtils.areTeamMates(playerA: Player, playerB: Player): boolean
	local teamA = TeamUtils.getTeam(playerA)
	local teamB = TeamUtils.getTeam(playerB)
	if not teamA or not teamB then
		return false
	end

	return teamA == teamB
end

--[=[
	Returns the team of the player, or nil if the player is neutral
]=]
function TeamUtils.getTeam(player: Player): Team?
	if PlayerMock.isMock(player) then
		if PlayerMock.read(player, "Neutral") then
			return nil
		end

		return PlayerMock.read(player, "Team")
	end

	if player.Neutral then
		return nil
	end

	return player.Team
end

return TeamUtils
