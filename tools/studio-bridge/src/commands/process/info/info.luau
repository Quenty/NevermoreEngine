--[[
	QueryState action handler for the studio-bridge plugin.

	Returns the current Studio run mode, place name, place ID, and game ID.

	Protocol:
	  Request:  { type: "queryState", payload: {} }
	  Response: { type: "stateResult", payload: { state, placeName, placeId, gameId } }
]]

local RunService = game:GetService("RunService")

local QueryStateAction = {}

-- ---------------------------------------------------------------------------
-- State detection
-- ---------------------------------------------------------------------------

local function detectState(): string
	if RunService:IsRunning() then
		if RunService:IsClient() and not RunService:IsServer() then
			return "Client"
		elseif RunService:IsServer() and not RunService:IsClient() then
			return "Server"
		else
			return "Play"
		end
	end
	return "Edit"
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function QueryStateAction.register(router: any)
	router:register("queryState", function(_payload: { [string]: any }, _requestId: string, _sessionId: string)
		return {
			state = detectState(),
			placeName = game.Name or "Unknown",
			placeId = game.PlaceId,
			gameId = game.GameId,
		}
	end)
end

return QueryStateAction
