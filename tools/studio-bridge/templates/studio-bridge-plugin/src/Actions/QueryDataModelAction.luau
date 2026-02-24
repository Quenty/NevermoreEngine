--[[
	QueryDataModel action handler for the studio-bridge plugin.

	Resolves a dot-separated path to a Roblox Instance and serializes it
	into a DataModelInstance response with optional properties, attributes,
	and children up to a specified depth.

	Protocol:
	  Request:  { type: "queryDataModel", path: "Workspace.SpawnLocation", depth: 1, properties: [], includeAttributes: true }
	  Response: { type: "dataModelResult", payload: { instance: DataModelInstance } }
]]

local QueryDataModelAction = {}

-- ---------------------------------------------------------------------------
-- Property serialization
-- ---------------------------------------------------------------------------

local SKIP_PROPERTIES = {
	Parent = true,
}

local function serializeValue(value: any): any
	local t = typeof(value)

	if t == "string" or t == "number" or t == "boolean" then
		return value
	elseif t == "nil" then
		return nil
	elseif t == "Vector3" then
		return { type = "Vector3", value = { value.X, value.Y, value.Z } }
	elseif t == "Vector2" then
		return { type = "Vector2", value = { value.X, value.Y } }
	elseif t == "CFrame" then
		return { type = "CFrame", value = { value:GetComponents() } }
	elseif t == "Color3" then
		return { type = "Color3", value = { value.R, value.G, value.B } }
	elseif t == "UDim2" then
		return { type = "UDim2", value = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset } }
	elseif t == "UDim" then
		return { type = "UDim", value = { value.Scale, value.Offset } }
	elseif t == "BrickColor" then
		return { type = "BrickColor", name = value.Name, value = value.Number }
	elseif t == "EnumItem" then
		return { type = "EnumItem", enum = tostring(value.EnumType), name = value.Name, value = value.Value }
	elseif t == "Instance" then
		return { type = "Instance", className = value.ClassName, path = value:GetFullName() }
	else
		return { type = "Unsupported", typeName = t, toString = tostring(value) }
	end
end

local function serializeProperties(instance: Instance, propertyFilter: { string }?): { [string]: any }
	local result = {}

	-- If a filter is provided and empty, return no properties
	if propertyFilter and #propertyFilter == 0 then
		return result
	end

	-- Use API dump approach: read common properties via pcall
	-- Since Roblox doesn't expose a property list, we read known safe properties
	-- and any specifically requested ones
	if propertyFilter then
		for _, propName in propertyFilter do
			if not SKIP_PROPERTIES[propName] then
				local ok, value = pcall(function()
					return (instance :: any)[propName]
				end)
				if ok then
					result[propName] = serializeValue(value)
				end
			end
		end
	else
		-- No filter: read common properties
		local commonProps = { "Name", "ClassName" }
		for _, propName in commonProps do
			local ok, value = pcall(function()
				return (instance :: any)[propName]
			end)
			if ok then
				result[propName] = serializeValue(value)
			end
		end
	end

	return result
end

local function serializeAttributes(instance: Instance): { [string]: any }
	local result = {}
	local ok, attrs = pcall(function()
		return instance:GetAttributes()
	end)
	if ok and attrs then
		for key, value in attrs do
			result[key] = serializeValue(value)
		end
	end
	return result
end

-- ---------------------------------------------------------------------------
-- Instance serialization
-- ---------------------------------------------------------------------------

local function serializeInstance(
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
		properties = serializeProperties(instance, propertyFilter),
		attributes = if includeAttributes then serializeAttributes(instance) else {},
		childCount = #children,
	}

	if depth > 0 then
		local serializedChildren = {}
		for _, child in children do
			table.insert(serializedChildren, serializeInstance(child, depth - 1, propertyFilter, includeAttributes))
		end
		node.children = serializedChildren
	end

	return node
end

-- ---------------------------------------------------------------------------
-- Path resolution
-- ---------------------------------------------------------------------------

local function resolveInstance(path: string): Instance?
	-- Split path by dots, resolve from game
	local parts = string.split(path, ".")
	local startIndex = 1

	-- Skip leading "game" since we start from game
	if parts[1] == "game" then
		startIndex = 2
	end

	local current: any = game
	for i = startIndex, #parts do
		local part = parts[i]
		-- Try as a service first (e.g. "Workspace", "ReplicatedStorage")
		local ok, child = pcall(function()
			return current:FindFirstChild(part)
		end)
		if not ok or not child then
			-- Try GetService for top-level services
			if current == game then
				local serviceOk, service = pcall(function()
					return game:GetService(part)
				end)
				if serviceOk and service then
					current = service
					continue
				end
			end
			return nil
		end
		current = child
	end

	return current
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function QueryDataModelAction.register(router: any)
	router:register("queryDataModel", function(payload: { [string]: any }, _requestId: string, _sessionId: string)
		local path = payload.path
		if not path or type(path) ~= "string" then
			return nil -- ActionRouter will return UNKNOWN_REQUEST for nil
		end

		local depth = payload.depth or 0
		local propertyFilter = payload.properties -- nil means common props, {} means none
		local includeAttributes = payload.includeAttributes == true

		local instance = resolveInstance(path)
		if not instance then
			return {
				success = false,
				code = "INSTANCE_NOT_FOUND",
				message = `Instance not found at path: {path}`,
			}
		end

		return {
			instance = serializeInstance(instance, depth, propertyFilter, includeAttributes),
		}
	end)
end

return QueryDataModelAction
