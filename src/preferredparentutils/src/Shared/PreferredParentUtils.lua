--!strict
--[=[
	Handles logic for creating a "preferred" parent container or erroring if
	it already exists.

	@class PreferredParentUtils
]=]
local RunService = game:GetService("RunService")

local PreferredParentUtils = {}

--[=[
	@param parent Instance
	@param name string
	@param forceCreate boolean
	@return () -> Instance
]=]
function PreferredParentUtils.createPreferredParentRetriever(parent: Instance, name: string, forceCreate: boolean)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(name) == "string", "Bad name")

	local cache: Instance?
	return function(): Instance?
		-- Ensure that we don't try to search for duplicates EVERY time.
		if cache and cache.Parent == parent then
			return cache
		end

		cache = PreferredParentUtils.getPreferredParent(parent, name, forceCreate)
		return cache
	end
end

--[=[
	@param parent Instance
	@param name string
	@param forceCreate boolean
	@return Instance
]=]
function PreferredParentUtils.getPreferredParent(parent: Instance, name: string, forceCreate: boolean): Instance?
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(name) == "string", "Bad name")

	local found
	for _, item in parent:GetChildren() do
		if item.Name == name then
			if not found then
				found = item
			else
				error(string.format("[PreferredParentUtils.getPreferredParent] - Duplicate of %q", item:GetFullName()))
			end
		end
	end

	if found then
		return found
	end

	if not RunService:IsRunning() or RunService:IsServer() or forceCreate then
		local newParent = Instance.new("Folder")
		newParent.Name = name
		newParent.Parent = parent

		return newParent
	end

	return nil
end


return PreferredParentUtils