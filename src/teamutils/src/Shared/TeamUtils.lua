--[=[
	Team utility methods
	@class TeamUtils
]=]

local TeamUtils = {}

function TeamUtils.areTeamMates(playerA, playerB)
	local teamA = TeamUtils.getTeam(playerA)
	local teamB = TeamUtils.getTeam(playerB)
	if not teamA or not teamB then
		return false
	end

	return teamA == teamB
end

function TeamUtils.getTeam(player)
	if player.Neutral then
		return nil
	end

	return player.Team
end

return TeamUtils