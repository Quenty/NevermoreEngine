--!strict
--[=[
	Action that ends the playtest the session belongs to, answering with the
	playtest id studio-bridge started it under.

	StudioTestService only allows `EndTest` in the server DataModel of a running
	playtest, so this must target the server session. The playtest stops after
	the reply is sent, since stopping tears down the DataModel answering.

	Request: `{ type: "endPlaytest", payload: {} }`
	Response: `{ type: "endPlaytestResult", payload: { playtestId? } }`

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

		return {
			playtestId = if type(testArgs) == "table" then testArgs.studioBridgePlaytestId else nil,
		}
	end)
end

return EndPlaytestAction
