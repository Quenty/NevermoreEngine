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
	  discovery needs, so the plugin in each connects straight to that port and
	  registers under the edit session's instance and the playtest id.
	- With `bridge`, it first plants the studio-bridge client as a Script in
	  ServerScriptService, for when Studio does not load user plugins into
	  playtests. The playtest copies the edit DataModel, so the client starts in
	  its server and connects as its server session. With
	  `bridge.clientEntrySource` it also plants a LocalScript in
	  StarterPlayerScripts, which every player's client runs and connects as its
	  client session. The plants are removed once the playtest ends.

	Request: `{ type: "startPlaytest", payload: { mode: "play" | "run", playtestId, bridgePort, instanceId, players?, bridge? } }`
	`bridge`: `{ entrySource, clientEntrySource?, modules: { [name]: source }, precompiled: { source } }`
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
			local planted = if payload.bridge ~= nil
				then StartPlaytestAction._plant(router, payload.bridge, playtestId)
				else {}
			task.spawn(StartPlaytestAction._runAsync, sendMessage, mode, testArgs, requestId, sessionId, planted)

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
	sessionId: string,
	planted: { Instance }
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

	for _, instance in planted do
		instance:Destroy()
	end

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

--[[
	Plants the studio-bridge client for the playtest `playtestId` and returns it.
	Errors on a malformed `bridge`, or a precompiled source that does not
	compile, before anything is planted: the planted client skips a source that
	fails to load, which would hide the compile error.
]]
function StartPlaytestAction._plant(router: any, bridge: any, playtestId: string): { Instance }
	if
		type(bridge) ~= "table"
		or type(bridge.entrySource) ~= "string"
		or type(bridge.modules) ~= "table"
		or type(bridge.precompiled) ~= "table"
	then
		error("Invalid bridge in startPlaytest request")
	end

	for _, source in bridge.precompiled do
		local fn, compileErr
		if type(router.Compile) == "function" then
			fn, compileErr = router:Compile(source, "=exec")
		else
			fn, compileErr = (loadstring :: any)(source, "=exec")
		end
		if not fn then
			error(`Script does not compile: {compileErr or "unknown error"}`, 0)
		end
	end

	local entry = Instance.new("Script")
	entry.Name = "StudioBridgePlaytest"
	entry.Source = bridge.entrySource
	entry:SetAttribute("PlaytestId", playtestId)

	local shared = Instance.new("Folder")
	shared.Name = "Shared"
	shared.Parent = entry
	for name, source in bridge.modules do
		local moduleScript = Instance.new("ModuleScript")
		moduleScript.Name = name
		moduleScript.Source = source
		moduleScript.Parent = shared
	end

	local precompiled = Instance.new("Folder")
	precompiled.Name = "Precompiled"
	precompiled.Parent = entry
	for index, source in bridge.precompiled do
		local moduleScript = Instance.new("ModuleScript")
		moduleScript.Name = tostring(index)
		moduleScript.Source = source
		moduleScript.Parent = precompiled
	end

	local planted = { entry }
	local clientEntry: LocalScript? = nil
	if type(bridge.clientEntrySource) == "string" then
		clientEntry = Instance.new("LocalScript")
		local client = clientEntry :: LocalScript
		client.Name = "StudioBridgePlaytestClient"
		client.Source = bridge.clientEntrySource
		client:SetAttribute("PlaytestId", playtestId)
		shared:Clone().Parent = client
		precompiled:Clone().Parent = client
		table.insert(planted, client)
	end

	-- A bridge left from an earlier playtest would stand in for this one's
	local serverScriptService = game:GetService("ServerScriptService")
	local starterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	for _, container in { serverScriptService, starterPlayerScripts } do
		for _, child in container:GetChildren() do
			if child.Name == entry.Name or child.Name == "StudioBridgePlaytestClient" then
				child:Destroy()
			end
		end
	end

	entry.Parent = serverScriptService
	if clientEntry then
		clientEntry.Parent = starterPlayerScripts
	end
	return planted
end

return StartPlaytestAction
