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
function PreferredParentUtils.createPreferredParentRetriever(parent, name, forceCreate)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(name) == "string", "Bad name")

	local cache
	return function()
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
function PreferredParentUtils.getPreferredParent(parent, name, forceCreate)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(name) == "string", "Bad name")

	local found
	for _, item in pairs(parent:GetChildren()) do
		if item.Name == name then
			if not found then
				found = item
			else
				error(("[PreferredParentUtils.getPreferredParent] - Duplicate of %q")
					:format(tostring(item:GetFullName())))
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