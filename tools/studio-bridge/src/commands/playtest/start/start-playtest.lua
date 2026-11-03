--!strict
--[=[
	Action that starts a Studio playtest through StudioTestService, answering with
	`playtestEnded` once the playtest is over.

	- ExecutePlayModeAsync and ExecuteRunModeAsync yield until the playtest ends,
	  so the reply comes at the end, not the start. The bridge learns the
	  playtest started from its server session connecting.
	- A playtest already in progress fails the call only after it yields, so a
	  refusal also arrives as a `playtestEnded` reply, with `success = false`.
	- With `players`, it starts a multiplayer test instead: a server and a
	  client per player, each in its own Studio process.
	- The playtest id, bridge port and edit instance id ride along as the test
	  args. The playtest's DataModels cannot make the HTTP requests port
	  discovery needs, so the plugin in each connects straight to that port,
	  registers under the edit session's instance, and answers with the
	  playtest id when asked which playtest it belongs to.

	Request: `{ type: "startPlaytest", payload: { mode: "play" | "run", playtestId, bridgePort, instanceId, players? } }`
	Response: `{ type: "playtestEnded", payload: { playtestId, success, error? } }`

	@class StartPlaytestAction
]=]

local StartPlaytestAction = {}

type SendMessage = (message: { [string]: any }) -> ()

--[=[
	Registers the `startPlaytest` handler. The reply waits for the playtest to
	end, so it needs `sendMessage`.
]=]
function StartPlaytestAction.register(router: any, sendMessage: SendMessage?)
	router:setResponseType("startPlaytest", "playtestEnded")
	router:register(
		"startPlaytest",
		function(payload: { [string]: any }, requestId: string, sessionId: string): { [string]: any }?
			local mode = payload.mode
			if mode ~= "play" and mode ~= "run" then
				error(`Unknown playtest mode: {tostring(mode)}`)
			end

			local playtestId = payload.playtestId
			local bridgePort = payload.bridgePort
			local instanceId = payload.instanceId
			if type(playtestId) ~= "string" or type(bridgePort) ~= "number" or type(instanceId) ~= "string" then
				error("Missing playtestId, bridgePort or instanceId in startPlaytest request")
			end

			if not sendMessage then
				error("Starting a playtest requires a sendMessage callback")
			end

			local players = payload.players
			if players ~= nil and (type(players) ~= "number" or players < 1) then
				error(`Invalid player count: {tostring(players)}`)
			end

			local testArgs = {
				studioBridgePlaytestId = playtestId,
				studioBridgePort = bridgePort,
				studioBridgeInstanceId = instanceId,
				studioBridgePlayers = players,
			}
			task.spawn(StartPlaytestAction._runAsync, sendMessage, mode, testArgs, requestId, sessionId)

			-- Replied through sendMessage, so the router must not reply as well
			return nil
		end
	)
end

function StartPlaytestAction._runAsync(
	sendMessage: SendMessage,
	mode: string,
	testArgs: {
		studioBridgePlaytestId: string,
		studioBridgePort: number,
		studioBridgeInstanceId: string,
		studioBridgePlayers: number?,
	},
	requestId: string,
	sessionId: string
)
	local ok, err = pcall(function()
		local studioTestService = game:GetService("StudioTestService") :: any
		if testArgs.studioBridgePlayers then
			studioTestService:ExecuteMultiplayerTestAsync(testArgs.studioBridgePlayers, testArgs)
		elseif mode == "play" then
			studioTestService:ExecutePlayModeAsync(testArgs)
		else
			studioTestService:ExecuteRunModeAsync(testArgs)
		end
	end)

	sendMessage({
		type = "playtestEnded",
		sessionId = sessionId,
		requestId = if requestId ~= "" then requestId else nil,
		payload = {
			playtestId = testArgs.studioBridgePlaytestId,
			success = ok,
			error = if ok then nil else tostring(err),
		},
	})
end

return StartPlaytestAction
