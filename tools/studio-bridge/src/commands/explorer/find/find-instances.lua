--!strict
--[=[
	Action that searches the DataModel for instances by name, class and tag,
	answering with the first `limit` matches.

	- `name` matches case-insensitively anywhere in the instance's name, or the
	  whole name with `exactName`.
	- `className` matches with IsA, so `BasePart` finds every part.
	- Without `root`, searches every service the plugin can read, other than
	  Studio's own (CoreGui and the like).

	Request: `{ type: "findInstances", payload: { root?, name?, exactName?, className?, tag?, limit? } }`
	Response: `{ type: "findInstancesResult", payload: { instances, searched, truncated } }`

	@class FindInstancesAction
]=]

local DEFAULT_LIMIT = 200
local YIELD_EVERY = 5000
-- Studio's own instances, which the place does not contain
local ENGINE_SERVICES = table.freeze({
	CoreGui = true,
	CorePackages = true,
	RobloxReplicatedStorage = true,
})

local FindInstancesAction = {}

type FoundInstance = {
	path: string,
	name: string,
	className: string,
}

--[=[
	Registers the `findInstances` handler.
]=]
function FindInstancesAction.register(router: any)
	router:setResponseType("findInstances", "findInstancesResult")
	router:register(
		"findInstances",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			local root: Instance? = game
			if type(payload.root) == "string" then
				root = FindInstancesAction._resolveInstance(payload.root)
				if not root then
					return {
						success = false,
						code = "INSTANCE_NOT_FOUND",
						message = `Instance not found at path: {payload.root}`,
					}
				end
			end

			local matches = FindInstancesAction._createMatcher(payload)
			local limit = if type(payload.limit) == "number" then payload.limit else DEFAULT_LIMIT

			local found: { FoundInstance } = {}
			local searched = 0
			local truncated = false
			for _, instance in FindInstancesAction._getSearchable(root :: Instance) do
				searched += 1
				if searched % YIELD_EVERY == 0 then
					task.wait()
				end

				if matches(instance) then
					if #found >= limit then
						truncated = true
						break
					end
					table.insert(found, {
						path = instance:GetFullName(),
						name = instance.Name,
						className = instance.ClassName,
					})
				end
			end

			return {
				instances = found,
				searched = searched,
				truncated = truncated,
			}
		end
	)
end

function FindInstancesAction._createMatcher(payload: { [string]: any }): (Instance) -> boolean
	local name = if type(payload.name) == "string" and payload.name ~= "" then string.lower(payload.name) else nil
	local exactName = payload.exactName == true
	local className = if type(payload.className) == "string" then payload.className else nil
	local tag = if type(payload.tag) == "string" then payload.tag else nil

	return function(instance: Instance): boolean
		if name then
			local instanceName = string.lower(instance.Name)
			if exactName then
				if instanceName ~= name then
					return false
				end
			elseif not string.find(instanceName, name, 1, true) then
				return false
			end
		end

		if className and not instance:IsA(className) then
			return false
		end

		if tag and not instance:HasTag(tag) then
			return false
		end

		return true
	end
end

--[[
	Returns the descendants of `root`. For game, that is the descendants of
	each place service the plugin may read, since some refuse access.
]]
function FindInstancesAction._getSearchable(root: Instance): { Instance }
	if root ~= game then
		return root:GetDescendants()
	end

	local searchable = {}
	for _, service in game:GetChildren() do
		if ENGINE_SERVICES[service.ClassName] then
			continue
		end
		local ok, descendants = pcall(service.GetDescendants, service)
		if ok then
			table.insert(searchable, service)
			table.move(descendants, 1, #descendants, #searchable + 1, searchable)
		end
	end
	return searchable
end

--[[
	Walks `path` down from game, falling back to GetService for top-level names
	that are not children by that name. A leading "game" is optional.
]]
function FindInstancesAction._resolveInstance(path: string): Instance?
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

return FindInstancesAction
