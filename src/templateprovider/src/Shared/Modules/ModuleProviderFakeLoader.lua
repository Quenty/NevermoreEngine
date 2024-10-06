--[=[
	Creates a service that provides modules from a parent module, either by name, or by list!
	@class ModuleProviderFakeLoader
]=]

local function load(script)
	local moduleProvider = script:FindFirstAncestorWhichIsA("ModuleScript")
	assert(moduleProvider, "No moduleProvider")

	local loader = require(moduleProvider.Parent.loader)
	return loader.load(moduleProvider)
end

return {
	load = load
}