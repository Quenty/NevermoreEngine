--- Team utility methods
-- @module Team

local lib = {}

function lib.AreTeamMates(playerA, playerB)
	if playerA.Neutral or playerB.Neutral then
		return false
	end
	if not playerA.Team or not playerB.Team then
		return false
	end
	return playerA.Team == playerB.Team
end

return lib