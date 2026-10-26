--!strict
--[=[
	Action that answers `queryState` with Studio's run mode and the open place.

	Request: `{ type: "queryState", payload: {} }`
	Response: `{ type: "stateResult", payload: { state, placeName, placeId, gameId } }`

	@class QueryStateAction
]=]

local RunService = game:GetService("RunService")

local QueryStateAction = {}

--[=[
	Registers the `queryState` handler.
]=]
function QueryStateAction.register(router: any)
	router:setResponseType("queryState", "stateResult")
	router:register("queryState", function(_payload: { [string]: any }, _requestId: string, _sessionId: string)
		return {
			state = QueryStateAction._getState(),
			placeName = game.Name or "Unknown",
			placeId = game.PlaceId,
			gameId = game.GameId,
		}
	end)
end

function QueryStateAction._getState(): string
	if not RunService:IsRunning() then
		return "Edit"
	end

	local isClient = RunService:IsClient()
	local isServer = RunService:IsServer()
	if isClient and not isServer then
		return "Client"
	elseif isServer and not isClient then
		return "Server"
	else
		return "Play"
	end
end

return QueryStateAction
