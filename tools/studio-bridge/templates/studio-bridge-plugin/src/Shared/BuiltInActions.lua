--!strict
--[=[
	The two handlers the plugin ships with. Everything else is pushed by the
	bridge over the wire through them.

	- `registerAction` installs action source, skipping it when the same content
	  hash is already installed.
	- `syncActions` reports which actions the bridge needs to push, by comparing
	  its content hashes against the installed ones.

	@class BuiltInActions
]=]

local StudioBridgeLogUtils = require(script.Parent.StudioBridgeLogUtils)

local BuiltInActions = {}

type ActionRouter = any

--[=[
	Registers both built-in handlers. `sendMessage` and `logBuffer` are handed on
	to every action installed through `registerAction`.
]=]
function BuiltInActions.register(router: ActionRouter, sendMessage: (message: { [string]: any }) -> (), logBuffer: any)
	router:register("registerAction", function(payload)
		return BuiltInActions._registerAction(router, payload, sendMessage, logBuffer)
	end)
	router:setResponseType("registerAction", "registerActionResult")

	router:register("syncActions", function(payload)
		return BuiltInActions._syncActions(router, payload)
	end)
	router:setResponseType("syncActions", "syncActionsResult")
end

function BuiltInActions._registerAction(
	router: ActionRouter,
	payload: { [string]: any },
	sendMessage: (message: { [string]: any }) -> (),
	logBuffer: any
): { [string]: any }
	local name = payload.name
	local source = payload.source
	local hash = if type(payload.hash) == "string" then payload.hash else nil

	if type(name) ~= "string" or type(source) ~= "string" then
		return {
			name = if type(name) == "string" then name else "unknown",
			success = false,
			error = "Invalid registerAction payload: name and source are required strings",
		}
	end

	if hash and router:GetInstalledActions()[name] == hash then
		return {
			name = name,
			success = true,
			skipped = true,
			hash = hash,
			handlers = router:GetActionHandlerNames(name),
		}
	end

	local success, err = router:RegisterAction(name, source, sendMessage, logBuffer, payload.responseType, hash)

	return {
		name = name,
		success = success,
		skipped = false,
		hash = hash,
		handlers = success and router:GetActionHandlerNames(name) or {},
		error = err,
	}
end

function BuiltInActions._syncActions(router: ActionRouter, payload: { [string]: any }): { [string]: any }
	StudioBridgeLogUtils.setVerbose(payload.verbose == true)

	local installed = router:GetInstalledActions()

	local needed: { string } = {}
	for name, bridgeHash in payload.actions or {} do
		if installed[name] ~= bridgeHash then
			table.insert(needed, name)
		end
	end

	return {
		needed = needed,
		installed = installed,
	}
end

return BuiltInActions
