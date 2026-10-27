--!strict
--[=[
	Action that answers `queryState` with Studio's run mode and the open place.

	Request: `{ type: "queryState", payload: {} }`
	Response: `{ type: "stateResult", payload: { state, placeName, placeId, gameId, viewportSize? } }`

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
			viewportSize = QueryStateAction._getViewportSize(),
		}
	end)
end

--[[
	The camera's viewport in pixels, or nil when the DataModel has no camera.
]]
function QueryStateAction._getViewportSize(): { number }?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	return { camera.ViewportSize.X, camera.ViewportSize.Y }
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
