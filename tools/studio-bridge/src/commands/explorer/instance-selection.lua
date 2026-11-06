--!strict
--[=[
	Library that picks out instances by name, class and tag, shared by the
	`findInstances` and `sampleInstances` actions so both match the same way.

	- `names` match case-insensitively anywhere in the instance's name, or the
	  whole name with `exactName`. Any one of them matching is enough.
	- `className` matches with IsA, so `BasePart` finds every part.
	- Without `root`, searches every service the plugin can read, other than
	  Studio's own (CoreGui and the like).

	Pushed like an action, but registers no handlers: it puts itself on
	`router._libraries` for the actions to look up when a request arrives.

	@class InstanceSelection
]=]

-- Studio's own instances, which the place does not contain
local ENGINE_SERVICES = table.freeze({
	CoreGui = true,
	CorePackages = true,
	RobloxReplicatedStorage = true,
})

local InstanceSelection = {}

export type Selection = {
	root: string?,
	names: { string }?,
	-- A single name, from callers before `names`
	name: string?,
	exactName: boolean?,
	className: string?,
	tag: string?,
}

--[=[
	Makes the library available to actions as `router._libraries["instance-selection"]`.
]=]
function InstanceSelection.register(router: any)
	router._libraries = router._libraries or {}
	router._libraries["instance-selection"] = InstanceSelection
end

--[=[
	Returns the instance to search under: game without a `root`, or nil and an
	error message when `root` does not resolve.
]=]
function InstanceSelection.resolveRoot(root: string?): (Instance?, string?)
	if type(root) ~= "string" then
		return game, nil
	end

	local instance = InstanceSelection.resolveInstance(root)
	if not instance then
		return nil, `Instance not found at path: {root}`
	end
	return instance, nil
end

--[=[
	Returns whether a selection names anything to match on, since an empty one
	matches every instance.
]=]
function InstanceSelection.hasCriteria(selection: Selection): boolean
	return #InstanceSelection._getNames(selection) > 0
		or type(selection.className) == "string"
		or type(selection.tag) == "string"
end

--[=[
	Returns a predicate for the selection's names, class and tag.
]=]
function InstanceSelection.createMatcher(selection: Selection): (Instance) -> boolean
	local names = InstanceSelection._getNames(selection)
	local exactName = selection.exactName == true
	local className = if type(selection.className) == "string" then selection.className else nil
	local tag = if type(selection.tag) == "string" then selection.tag else nil

	local function matchesName(instance: Instance): boolean
		if #names == 0 then
			return true
		end

		local instanceName = string.lower(instance.Name)
		for _, name in names do
			if exactName then
				if instanceName == name then
					return true
				end
			elseif string.find(instanceName, name, 1, true) then
				return true
			end
		end
		return false
	end

	return function(instance: Instance): boolean
		if not matchesName(instance) then
			return false
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

--[=[
	Returns up to `limit` matching descendants of `root`, how many were looked
	at, and whether it stopped at the limit. With `yieldEvery`, waits a frame
	after that many instances so a large place does not stall Studio.
]=]
function InstanceSelection.find(
	root: Instance,
	matches: (Instance) -> boolean,
	limit: number,
	yieldEvery: number?
): ({ Instance }, number, boolean)
	local found: { Instance } = {}
	local searched = 0
	for _, instance in InstanceSelection.getSearchable(root) do
		searched += 1
		if yieldEvery and searched % yieldEvery == 0 then
			task.wait()
		end

		if matches(instance) then
			if #found >= limit then
				return found, searched, true
			end
			table.insert(found, instance)
		end
	end
	return found, searched, false
end

--[=[
	Returns the descendants of `root`. For game, that is the descendants of
	each place service the plugin may read, since some refuse access.
]=]
function InstanceSelection.getSearchable(root: Instance): { Instance }
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

--[=[
	Walks `path` down from game, falling back to GetService for top-level names
	that are not children by that name. A leading "game" is optional.
]=]
function InstanceSelection.resolveInstance(path: string): Instance?
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

function InstanceSelection._getNames(selection: Selection): { string }
	local names: { string } = {}
	local function add(name: any)
		if type(name) == "string" and name ~= "" then
			table.insert(names, string.lower(name))
		end
	end

	if type(selection.names) == "table" then
		for _, name in selection.names do
			add(name)
		end
	end
	add(selection.name)

	return names
end

return InstanceSelection
