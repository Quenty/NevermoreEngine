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
	- With `bridge`, it first plants a copy of the plugin's script tree as a
	  Script in ServerScriptService, for when Studio does not load user plugins
	  into playtests, and with `bridge.client` as a LocalScript in
	  StarterPlayerScripts. The copy cannot compile code, so it carries the
	  action modules installed here and the scripts in `bridge.precompiled`.
	  The plants are removed once the playtest ends.

	Request: `{ type: "startPlaytest", payload: { mode: "play" | "run", playtestId, bridgePort, instanceId, players?, bridge? } }`
	`bridge`: `{ precompiled: { source }, client: boolean? }`
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
			local planted = {}
			if payload.bridge ~= nil then
				local plantOk, plantedOrError = pcall(StartPlaytestAction._plant, router, payload.bridge, playtestId)
				if not plantOk then
					return { success = false, code = "SCRIPT_LOAD_ERROR", message = tostring(plantedOrError) }
				end
				planted = plantedOrError
			end
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

function StartPlaytestAction._plant(router: any, bridge: any, playtestId: string): { Instance }
	if type(bridge) ~= "table" or type(bridge.precompiled) ~= "table" then
		error("Invalid bridge in startPlaytest request")
	end

	local template = if type(router.GetPlaytestBridgeTemplate) == "function"
		then router:GetPlaytestBridgeTemplate()
		else nil
	local moduleFolder = if type(router.GetModuleFolder) == "function" then router:GetModuleFolder() else nil
	if not (template and moduleFolder) then
		error(
			"The studio-bridge plugin is too old to start a playtest with \"Load user plugins on playtest\" off. Run 'studio-bridge plugin install'.",
			0
		)
	end

	for _, source in bridge.precompiled do
		local fn, compileErr
		if type(router.Compile) == "function" then
			fn, compileErr = router:Compile(source, "=exec")
		else
			fn, compileErr = (loadstring :: any)(source, "=exec")
		end
		if not fn then
			error(
				`The code to run in the playtest doesn't compile: {compileErr or "no reason given"}. Fix it, then run the command again.`,
				0
			)
		end
	end

	local entry = template:Clone()
	entry.Name = "StudioBridgePlaytest"
	entry:SetAttribute("PlaytestId", playtestId)

	local plantedModules = Instance.new("Folder")
	plantedModules.Name = moduleFolder.Name
	for _, child in moduleFolder:GetChildren() do
		if child:IsA("ModuleScript") and child:GetAttribute("Hash") ~= nil then
			child:Clone().Parent = plantedModules
		end
	end
	local entryModules = entry:WaitForChild("modules")
	local templateModules = entryModules:FindFirstChild(moduleFolder.Name)
	if templateModules then
		templateModules:Destroy()
	end
	plantedModules.Parent = entryModules

	local precompiled = Instance.new("Folder")
	precompiled.Name = "Precompiled"
	for index, source in bridge.precompiled do
		local moduleScript = Instance.new("ModuleScript")
		moduleScript.Name = tostring(index)
		moduleScript.Source = source
		moduleScript.Parent = precompiled
	end
	precompiled.Parent = entry

	local planted = { entry }
	local clientEntry: LocalScript? = nil
	if bridge.client == true then
		clientEntry = Instance.new("LocalScript")
		local client = clientEntry :: LocalScript
		client.Name = "StudioBridgePlaytestClient"
		client.Source = entry.Source
		client:SetAttribute("PlaytestId", playtestId)
		for _, child in entry:GetChildren() do
			child:Clone().Parent = client
		end
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
