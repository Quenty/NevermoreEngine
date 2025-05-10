--!strict
--[=[
	Very inefficient search utility function to find dependencies
	organized in node_modules structure.

	@class DependencyUtils
]=]

local loader = script.Parent.Parent
local ReplicationType = require(loader.Replication.ReplicationType)
local ReplicationTypeUtils = require(loader.Replication.ReplicationTypeUtils)

local DependencyUtils = {}

--[=[
	Iteratively searches for a dependency based upon packages and current modules using the node_modules
	dependency resolution algorithm.

	@param requester Instance
	@param moduleName string
	@param requestedReplicationType ReplicationType
	@return ModuleScript?
]=]
function DependencyUtils.findDependency(
	requester,
	moduleName: string,
	requestedReplicationType: ReplicationType.ReplicationType
): ModuleScript?
	assert(typeof(requester) == "Instance", "Bad requester")
	assert(type(moduleName) == "string", "Bad moduleName")
	assert(ReplicationTypeUtils.isReplicationType(requestedReplicationType), "Bad requestedReplicationType")

	for packageInst in DependencyUtils.iterPackages(requester) do
		for module: ModuleScript, replicationType: ReplicationType.ReplicationType in
			DependencyUtils.iterModules(packageInst, ReplicationType.SHARED)
		do
			if module.Name == moduleName then
				if ReplicationTypeUtils.isAllowed(replicationType, requestedReplicationType) then
					return module
				else
					error(
						string.format(
							"[DependencyUtils] - %q is not allowed in %q",
							moduleName,
							requestedReplicationType
						)
					)
				end
			end
		end
	end

	return nil
end

function DependencyUtils.iterModules(
	packageInst: Instance,
	ancestorReplicationType: ReplicationType.ReplicationType
): () -> (ModuleScript, ReplicationType.ReplicationType)
	assert(typeof(packageInst) == "Instance", "Bad packageInst")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	return coroutine.wrap(function(): any
		if packageInst:IsA("ModuleScript") then
			coroutine.yield(packageInst, ancestorReplicationType)
			return
		end

		-- Iterate over the package contents
		for _, item in packageInst:GetChildren() do
			local itemName: string = item.Name
			local itemReplicationType: ReplicationType.ReplicationType =
				ReplicationTypeUtils.getFolderReplicationType(itemName, ancestorReplicationType)

			if itemName ~= "node_modules" then
				for result, resultReplicationType in DependencyUtils.iterModules(item, itemReplicationType) do
					coroutine.yield(result, resultReplicationType)
				end
			end
		end

		return
	end) :: any
end

function DependencyUtils.iterPackages(requester: Instance): () -> Instance
	assert(typeof(requester) == "Instance", "Bad requester")

	return coroutine.wrap(function(): any
		for nodeModules in DependencyUtils.iterNodeModulesUp(requester) do
			coroutine.yield(nodeModules.Parent)

			for packageInst in DependencyUtils.iterPackagesInModuleModules(nodeModules) do
				coroutine.yield(packageInst)
			end
		end

		return
	end)
end

function DependencyUtils.iterNodeModulesUp(module: Instance): () -> Instance
	assert(typeof(module) == "Instance", "Bad module")

	return coroutine.wrap(function(): any
		local found = module:FindFirstChild("node_modules")
		if found and found:IsA("Folder") then
			coroutine.yield(found)
		end

		local current: Instance? = module.Parent
		while current do
			found = current:FindFirstChild("node_modules")
			if found and found:IsA("Folder") then
				coroutine.yield(found)
			end
			current = current.Parent :: Instance?
		end

		return
	end)
end

function DependencyUtils.iterPackagesInModuleModules(nodeModules: Instance): () -> Instance
	return coroutine.wrap(function(): any
		for _, item in nodeModules:GetChildren() do
			if item:IsA("Folder") then
				if DependencyUtils.isPackageGroup(item.Name) then
					for _, child in item:GetChildren() do
						if child:IsA("ModuleScript") or child:IsA("Folder") then
							coroutine.yield(child)
						elseif child:IsA("ObjectValue") then
							local linked = child.Value
							if linked then
								if linked:IsA("ModuleScript") or linked:IsA("Folder") then
									coroutine.yield(linked)
								else
									warn("[DependencyUtils] - Bad link value type")
								end
							else
								warn(string.format("[DependencyUtils] - Nothing linked on %s", child:GetFullName()))
							end
						end
					end
				else
					coroutine.yield(item)
				end
			elseif item:IsA("ModuleScript") then
				coroutine.yield(item)
			elseif item:IsA("ObjectValue") then
				local linked = item.Value
				if linked then
					if linked:IsA("ModuleScript") or linked:IsA("Folder") then
						coroutine.yield(linked)
					else
						warn("[DependencyUtils] - Bad link value type")
					end
				else
					warn(string.format("[DependencyUtils] - Nothing linked on %s", item:GetFullName()))
				end
			end
		end

		return
	end)
end

function DependencyUtils.isPackageGroup(itemName: string): boolean
	return string.sub(itemName, 1, 1) == "@"
end

return DependencyUtils
