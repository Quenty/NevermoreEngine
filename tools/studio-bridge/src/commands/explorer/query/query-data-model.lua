--!strict
--[=[
	Action that resolves a dot-separated path to an Instance and answers with it
	serialized, along with its properties, attributes, and children down to
	`depth`.

	Request: `{ type: "queryDataModel", payload: { path, depth?, properties?, includeAttributes? } }`
	Response: `{ type: "dataModelResult", payload: { instance: DataModelInstance } }`

	@class QueryDataModelAction
]=]

local COMMON_PROPERTIES = { "Name", "ClassName" }
local SKIP_PROPERTIES = {
	Parent = true,
}

local QueryDataModelAction = {}

--[=[
	Registers the `queryDataModel` handler.
]=]
function QueryDataModelAction.register(router: any)
	router:setResponseType("queryDataModel", "dataModelResult")
	router:register(
		"queryDataModel",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			local path = payload.path
			if type(path) ~= "string" then
				return nil
			end

			local instance = QueryDataModelAction._resolveInstance(path)
			if not instance then
				return {
					success = false,
					code = "INSTANCE_NOT_FOUND",
					message = `Instance not found at path: {path}`,
				}
			end

			return {
				instance = QueryDataModelAction._serializeInstance(
					instance,
					payload.depth or 0,
					payload.properties,
					payload.includeAttributes == true
				),
			}
		end
	)
end

--[[
	Walks `path` down from game, falling back to GetService for top-level names
	that are not children by that name. A leading "game" is optional.
]]
function QueryDataModelAction._resolveInstance(path: string): Instance?
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

--[[
	A nil filter reads the common properties, an empty one reads none.
]]
function QueryDataModelAction._serializeInstance(
	instance: Instance,
	depth: number,
	propertyFilter: { string }?,
	includeAttributes: boolean
): { [string]: any }
	local children = instance:GetChildren()
	local node: { [string]: any } = {
		name = instance.Name,
		className = instance.ClassName,
		path = instance:GetFullName(),
		properties = QueryDataModelAction._serializeProperties(instance, propertyFilter or COMMON_PROPERTIES),
		attributes = if includeAttributes then QueryDataModelAction._serializeAttributes(instance) else {},
		childCount = #children,
	}

	if depth > 0 then
		local serializedChildren = {}
		for _, child in children do
			table.insert(
				serializedChildren,
				QueryDataModelAction._serializeInstance(child, depth - 1, propertyFilter, includeAttributes)
			)
		end
		node.children = serializedChildren
	end

	return node
end

function QueryDataModelAction._serializeProperties(instance: Instance, propertyNames: { string }): { [string]: any }
	local result = {}
	for _, propertyName in propertyNames do
		if SKIP_PROPERTIES[propertyName] then
			continue
		end

		-- Roblox exposes no property list, so read each name and skip the ones that throw
		local ok, value = pcall(function()
			return (instance :: any)[propertyName]
		end)
		if ok then
			result[propertyName] = QueryDataModelAction._serializeValue(value)
		end
	end
	return result
end

function QueryDataModelAction._serializeAttributes(instance: Instance): { [string]: any }
	local result = {}
	local ok, attributes = pcall(instance.GetAttributes, instance)
	if not ok then
		return result
	end

	for key, value in attributes do
		result[key] = QueryDataModelAction._serializeValue(value)
	end
	return result
end

function QueryDataModelAction._serializeValue(value: any): any
	local valueType = typeof(value)

	if valueType == "nil" or valueType == "string" or valueType == "number" or valueType == "boolean" then
		return value
	elseif valueType == "Vector3" then
		return { type = "Vector3", value = { value.X, value.Y, value.Z } }
	elseif valueType == "Vector2" then
		return { type = "Vector2", value = { value.X, value.Y } }
	elseif valueType == "CFrame" then
		return { type = "CFrame", value = { value:GetComponents() } }
	elseif valueType == "Color3" then
		return { type = "Color3", value = { value.R, value.G, value.B } }
	elseif valueType == "UDim2" then
		return { type = "UDim2", value = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset } }
	elseif valueType == "UDim" then
		return { type = "UDim", value = { value.Scale, value.Offset } }
	elseif valueType == "BrickColor" then
		return { type = "BrickColor", name = value.Name, value = value.Number }
	elseif valueType == "EnumItem" then
		return { type = "EnumItem", enum = tostring(value.EnumType), name = value.Name, value = value.Value }
	elseif valueType == "Instance" then
		return { type = "Instance", className = value.ClassName, path = value:GetFullName() }
	else
		return { type = "Unsupported", typeName = valueType, toString = tostring(value) }
	end
end

return QueryDataModelAction
