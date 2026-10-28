--!strict
--[=[
	Action that serializes the instances at the given paths into one binary
	model (.rbxm) with SerializationService and answers with it as base64.

	Request: `{ type: "exportInstances", payload: { paths: { string } } }`
	Response: `{ type: "exportInstancesResult", payload: { data, paths } }`

	@class ExportInstancesAction
]=]

local ExportInstancesAction = {}

--[=[
	Registers the `exportInstances` handler.
]=]
function ExportInstancesAction.register(router: any)
	router:setResponseType("exportInstances", "exportInstancesResult")
	router:register(
		"exportInstances",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			local paths = payload.paths
			if type(paths) ~= "table" or #paths == 0 then
				return {
					success = false,
					code = "INVALID_PAYLOAD",
					message = "exportInstances needs at least one path",
				}
			end

			local instances = {}
			local fullNames = {}
			for _, path in paths do
				local instance = ExportInstancesAction._resolveInstance(path)
				if not instance then
					return {
						success = false,
						code = "INSTANCE_NOT_FOUND",
						message = `Instance not found at path: {path}`,
					}
				end
				table.insert(instances, instance)
				table.insert(fullNames, instance:GetFullName())
			end

			local serializeOk, serialized = pcall(function()
				return game:GetService("SerializationService"):SerializeInstancesAsync(instances)
			end)
			if not serializeOk then
				return {
					success = false,
					code = "SERIALIZE_FAILED",
					message = `Failed to serialize instances: {serialized}`,
				}
			end

			local encodeOk, encoded = pcall(function()
				return buffer.tostring(game:GetService("EncodingService"):Base64Encode(serialized))
			end)
			if not encodeOk then
				return {
					success = false,
					code = "ENCODE_FAILED",
					message = `Failed to base64 encode data: {encoded}`,
				}
			end

			return {
				data = encoded,
				paths = fullNames,
			}
		end
	)
end

--[[
	Walks `path` down from game, falling back to GetService for top-level names
	that are not children by that name. A leading "game" is optional.
]]
function ExportInstancesAction._resolveInstance(path: string): Instance?
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

return ExportInstancesAction
