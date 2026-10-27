--!strict
--[=[
	Action that ends the playtest the session belongs to, answering with the
	playtest id studio-bridge started it under and the mode it runs in, so the
	playtest can be restarted the same way.

	StudioTestService only allows `EndTest` in the server DataModel of a running
	playtest, so this must target the server session. The playtest stops after
	the reply is sent, since stopping tears down the DataModel answering.

	Request: `{ type: "endPlaytest", payload: {} }`
	Response: `{ type: "endPlaytestResult", payload: { playtestId?, mode, players? } }`

	@class EndPlaytestAction
]=]

local EndPlaytestAction = {}

--[=[
	Registers the `endPlaytest` handler.
]=]
function EndPlaytestAction.register(router: any)
	router:setResponseType("endPlaytest", "endPlaytestResult")
	router:register("endPlaytest", function(_payload: { [string]: any }, _requestId: string, _sessionId: string)
		local runService = game:GetService("RunService")
		if not (runService:IsRunning() and runService:IsServer()) then
			error("Only the server session of a running playtest can end it")
		end

		local studioTestService = game:GetService("StudioTestService") :: any
		local testArgs = studioTestService:GetTestArgs()

		-- EndTest rejects nil; the value goes unused, since the bridge reads results through execute
		task.defer(function()
			studioTestService:EndTest(true)
		end)

		local isStudioBridgeTest = type(testArgs) == "table"
		return {
			playtestId = if isStudioBridgeTest then testArgs.studioBridgePlaytestId else nil,
			mode = if runService:IsRunMode() then "run" else "play",
			players = if isStudioBridgeTest then testArgs.studioBridgePlayers else nil,
		}
	end)
end

return EndPlaytestAction
