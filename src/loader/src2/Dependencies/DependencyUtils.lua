--[=[
	Very inefficient search utility function to find dependencies
	organized in node_modules structure.

	@class DependencyUtils
]=]

local DependencyUtils = {}

--[=[
	Iteratively searches for a dependency based upon packages and current modules using the node_modules
	dependency resolution algorithm.

	@param requester Instance
	@param moduleName string
	@return ModuleScript?
]=]
function DependencyUtils.findDependency(requester, moduleName)
	assert(typeof(requester) == "Instance", "Bad requester")
	assert(type(moduleName) == "string", "Bad moduleName")

	for packageInst in DependencyUtils.iterPackages(requester) do
		for module in DependencyUtils.iterModules(packageInst) do
			if module.Name == moduleName then
				return module
			end
		end
	end

	return nil
end

function DependencyUtils.iterModules(packageInst)
	assert(typeof(packageInst) == "Instance", "Bad packageInst")

	return coroutine.wrap(function()
		if packageInst:IsA("ModuleScript") then
			coroutine.yield(packageInst)
			return
		end

		-- Iterate over the package contents
		for _, item in pairs(packageInst:GetChildren()) do
			if item.Name ~= "node_modules" then
				for result in DependencyUtils.iterModules(item) do
					coroutine.yield(result)
				end
			end
		end
	end)
end

function DependencyUtils.iterPackages(requester)
	assert(typeof(requester) == "Instance", "Bad requester")

	return coroutine.wrap(function()
		for nodeModules in DependencyUtils.iterNodeModules(requester) do
			coroutine.yield(nodeModules.Parent)

			for packageInst in DependencyUtils.iterPackagesInModuleModules(nodeModules) do
				coroutine.yield(packageInst)
			end
		end
	end)
end

function DependencyUtils.iterNodeModules(module)
	assert(typeof(module) == "Instance", "Bad module")

	return coroutine.wrap(function()
		local found = module:FindFirstChild("node_modules")
		if found and found:IsA("Folder") then
			coroutine.yield(found)
		end

		local current = module.Parent
		while current do
			found = current:FindFirstChild("node_modules")
			if found and found:IsA("Folder") then
				coroutine.yield(found)
			end
			current = current.Parent
		end
	end)
end

function DependencyUtils.iterPackagesInModuleModules(nodeModules)
	return coroutine.wrap(function()
		for _, item in pairs(nodeModules:GetChildren()) do
			if item:IsA("Folder") then
				if DependencyUtils.isPackageGroup(item.Name) then
					for _, child in pairs(item:GetChildren()) do
						if child:IsA("ModuleScript") or child:IsA("Folder") then
							coroutine.yield(child)
						elseif child:IsA("ObjectValue") then
							local linked = child.Value
							if linked then
								if linked:IsA("ModuleScript") or linked:IsA("Folder") then
									coroutine.yield(linked)
								else
									warn("Bad link value type")
								end
							else
								warn("Nothing linked")
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
						warn("Bad link value type")
					end
				else
					warn("Nothing linked")
				end
			end
		end
	end)
end

function DependencyUtils.isPackageGroup(itemName)
	return itemName:sub(1, 1) == "@"
end

return DependencyUtils