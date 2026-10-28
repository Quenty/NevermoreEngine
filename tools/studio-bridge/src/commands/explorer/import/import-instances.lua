--!strict
--[=[
	Action that decodes a base64 binary model (.rbxm), deserializes it with
	SerializationService, and parents the instances under `parentPath`.

	Request: `{ type: "importInstances", payload: { data, parentPath } }`
	Response: `{ type: "importInstancesResult", payload: { paths } }`

	@class ImportInstancesAction
]=]

local ImportInstancesAction = {}

--[=[
	Registers the `importInstances` handler.
]=]
function ImportInstancesAction.register(router: any)
	router:setResponseType("importInstances", "importInstancesResult")
	router:register(
		"importInstances",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			if type(payload.data) ~= "string" or type(payload.parentPath) ~= "string" then
				return {
					success = false,
					code = "INVALID_PAYLOAD",
					message = "importInstances needs data and parentPath strings",
				}
			end

			local parent = ImportInstancesAction._resolveInstance(payload.parentPath)
			if not parent then
				return {
					success = false,
					code = "INSTANCE_NOT_FOUND",
					message = `Instance not found at path: {payload.parentPath}`,
				}
			end

			local decodeOk, decoded = pcall(function()
				return game:GetService("EncodingService"):Base64Decode(buffer.fromstring(payload.data))
			end)
			if not decodeOk then
				return {
					success = false,
					code = "DECODE_FAILED",
					message = `Failed to base64 decode data: {decoded}`,
				}
			end

			local deserializeOk, instances = pcall(function()
				return game:GetService("SerializationService"):DeserializeInstancesAsync(decoded)
			end)
			if not deserializeOk then
				return {
					success = false,
					code = "DESERIALIZE_FAILED",
					message = `Failed to deserialize instances: {instances}`,
				}
			end

			local paths = {}
			for _, instance in instances do
				instance.Parent = parent
				table.insert(paths, instance:GetFullName())
			end

			return {
				paths = paths,
			}
		end
	)
end

--[[
	Walks `path` down from game, falling back to GetService for top-level names
	that are not children by that name. A leading "game" is optional.
]]
function ImportInstancesAction._resolveInstance(path: string): Instance?
	local parts = string.split(path, ".")
	local startIndex = if parts[1] == "game" then 2 else 1

	local current: Instance = game
	for index = startIndex, #parts do
		local part = parts[index]

		local ok, child = pcall(current.FindFirstChild, current, part)
		if ok and child then
			current = child
			continue
		end

		if current ~= game then
			return nil
		end

		local serviceOk, service = pcall(game.GetService, game, part)
		if not (serviceOk and service) then
			return nil
		end
		current = service
	end

	return current
end

return ImportInstancesAction
