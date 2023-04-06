--[=[
	Utility methods to build a virtual graph of the existing package information set
	@private
	@class PackageInfoUtils
]=]

local BounceTemplateUtils = require(script.Parent.BounceTemplateUtils)
local LoaderConstants = require(script.Parent.LoaderConstants)
local Queue = require(script.Parent.Queue)
local ScriptInfoUtils = require(script.Parent.ScriptInfoUtils)
local Utils = require(script.Parent.Utils)

local PackageInfoUtils = {}

function PackageInfoUtils.createPackageInfo(packageFolder, explicitDependencySet, scriptInfoLookup, fullName)
	assert(typeof(packageFolder) == "Instance", "Bad packageFolder")
	assert(type(explicitDependencySet) == "table", "Bad explicitDependencySet")
	assert(type(scriptInfoLookup) == "table", "Bad scriptInfoLookup")
	assert(type(fullName) == "string", "Bad fullName")

	return Utils.readonly({
		name = packageFolder.Name;
		fullName = fullName;
		instance = packageFolder;
		explicitDependencySet = explicitDependencySet;
		dependencySet = false; -- will be filled in later, contains ALL expected dependencies
		scriptInfoLookup = scriptInfoLookup;
	})
end

function PackageInfoUtils.createDependencyQueueInfo(packageInfo, implicitDependencySet)
	assert(type(packageInfo) == "table", "Bad packageInfo")
	assert(type(implicitDependencySet) == "table", "Bad implicitDependencySet")

	return Utils.readonly({
		packageInfo = packageInfo;
		implicitDependencySet = implicitDependencySet;
	})
end

function PackageInfoUtils.fillDependencySet(packageInfoList)
	assert(type(packageInfoList) == "table", "Bad packageInfoList")

	local queue = Queue.new()
	local seen = {}

	do
		local topDependencySet = {}
		for _, packageInfo in pairs(packageInfoList) do
			if not seen[packageInfo] then
				topDependencySet[packageInfo] = packageInfo
				seen[packageInfo] = true
				queue:PushRight(PackageInfoUtils.createDependencyQueueInfo(packageInfo, topDependencySet))
			end
		end
	end

	-- Flaw: We can enter this dependency chain from multiple paths (we're a cyclic directed graph, not a tree)
	-- TODO: Determine node_modules behavior and copy it (hopefully any link upwards words)
	-- For now we do breadth first resolution of this to ensure minimal dependencies are accumulated for deep trees
	while not queue:IsEmpty() do
		local queueInfo = queue:PopLeft()
		assert(not queueInfo.packageInfo.dependencySet, "Already wrote dependencySet")

		local dependencySet = PackageInfoUtils
			.computePackageDependencySet(queueInfo.packageInfo, queueInfo.implicitDependencySet)
		queueInfo.packageInfo.dependencySet = dependencySet

		-- Process all explicit dependencies for the next level
		for packageInfo, _ in pairs(queueInfo.packageInfo.explicitDependencySet) do
			if not seen[packageInfo] then
				seen[packageInfo] = true
				queue:PushRight(PackageInfoUtils.createDependencyQueueInfo(packageInfo, dependencySet))
			end
		end
	end
end

function PackageInfoUtils.computePackageDependencySet(packageInfo, implicitDependencySet)
	assert(type(packageInfo) == "table", "Bad packageInfo")
	assert(type(implicitDependencySet) == "table", "Bad implicitDependencySet")

	-- assume folders with the same name are the same module
	local dependencyNameMap = {}

	-- Set implicit dependencies
	if LoaderConstants.INCLUDE_IMPLICIT_DEPENDENCIES then
		for entry, _ in pairs(implicitDependencySet) do
			dependencyNameMap[entry.name] = entry
		end
	end

	-- These override implicit ones
	for entry, _ in pairs(packageInfo.explicitDependencySet) do
		dependencyNameMap[entry.name] = entry
	end

	-- clear ourself as a dependency
	dependencyNameMap[packageInfo.name] = nil

	-- Note we leave conflicting scripts here as unresolved. This will output an error later.
	local dependencySet = {}
	for _, entry in pairs(dependencyNameMap) do
		dependencySet[entry] = true
	end

	return dependencySet
end

function PackageInfoUtils.getOrCreatePackageInfo(packageFolder, packageInfoMap, scope, defaultReplicationType)
	assert(typeof(packageFolder) == "Instance", "Bad packageFolder")
	assert(type(packageInfoMap) == "table", "Bad packageInfoMap")
	assert(type(scope) == "string", "Bad scope")
	assert(defaultReplicationType, "No defaultReplicationType")

	if packageInfoMap[packageFolder] then
		return packageInfoMap[packageFolder]
	end

	local scriptInfoLookup = ScriptInfoUtils.createScriptInfoLookup()
	ScriptInfoUtils.populateScriptInfoLookup(
		packageFolder,
		scriptInfoLookup,
		defaultReplicationType)

	local explicitDependencySet = {}
	local fullName
	if scope == "" then
		fullName = packageFolder.Name
	else
		fullName = scope .. "/" .. packageFolder.Name
	end

	local packageInfo = PackageInfoUtils
		.createPackageInfo(packageFolder, explicitDependencySet, scriptInfoLookup, fullName)
	packageInfoMap[packageFolder] = packageInfo

	-- Fill this after we've registered ourselves, in case we're somehow in a recursive dependency set
	PackageInfoUtils.fillExplicitPackageDependencySet(
		explicitDependencySet,
		packageFolder,
		packageInfoMap,
		defaultReplicationType)

	return packageInfo
end

function PackageInfoUtils.getPackageInfoListFromDependencyFolder(folder, packageInfoMap, defaultReplicationType)
	assert(typeof(folder) == "Instance" and folder:IsA("Folder"), "Bad folder")
	assert(type(packageInfoMap) == "table", "Bad packageInfoMap")
	assert(defaultReplicationType, "No defaultReplicationType")


	local packageInfoList = {}

	-- Assume we are at the dependency level
	for _, instance in pairs(folder:GetChildren()) do
		if instance:IsA("Folder") then
			-- We loop through each "@quenty" or "@blah" and convert to a package
			if instance.Name:sub(1, 1) == "@" then
				local scope = instance.Name
				for _, child in pairs(instance:GetChildren()) do
					PackageInfoUtils.tryLoadPackageFromInstance(packageInfoList, packageInfoMap, child, scope, defaultReplicationType)
				end
			else
				PackageInfoUtils.tryLoadPackageFromInstance(packageInfoList, packageInfoMap, instance, "", defaultReplicationType)
			end
		else
			warn(("Unknown instance in dependencyFolder - %q"):format(instance:GetFullName()))
		end
	end

	return packageInfoList
end

function PackageInfoUtils.tryLoadPackageFromInstance(
	packageInfoList, packageInfoMap, instance, scope, defaultReplicationType)

	assert(type(packageInfoList) == "table", "Bad packageInfoList")
	assert(type(packageInfoMap) == "table", "Bad packageInfoMap")
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(scope) == "string", "Bad scope")
	assert(defaultReplicationType, "No defaultReplicationType")

	if BounceTemplateUtils.isBounceTemplate(instance) then
		return
	end

	if instance:IsA("Folder") or instance:IsA("ModuleScript") then
		table.insert(packageInfoList, PackageInfoUtils.getOrCreatePackageInfo(
			instance, packageInfoMap, scope, defaultReplicationType))
	elseif instance:IsA("ObjectValue") then
		local value = instance.Value
		if value and (value:IsA("Folder") or value:IsA("ModuleScript")) then
			table.insert(packageInfoList, PackageInfoUtils.getOrCreatePackageInfo(
				value, packageInfoMap, scope, defaultReplicationType))
		else
			local message = string.format("Invalid %q ObjectValue in package linking to nothing cannot be resolved into package dependency\n\t-> %s",
				instance.Name,
				instance:GetFullName())
			message = message .. "\n\tTIP: This happens when Rojo fails to clean out an object value. Try disconnecting Rojo and reconnecting"

			error(message)
		end
	end
end

-- Explicit dependencies are dependencies that are are explicitly listed.
-- These dependencies are available to this package and ANY dependent packages below
function PackageInfoUtils.fillExplicitPackageDependencySet(
	explicitDependencySet, packageFolder, packageInfoMap, defaultReplicationType)

	assert(type(explicitDependencySet) == "table", "Bad explicitDependencySet")
	assert(typeof(packageFolder) == "Instance", "Bad packageFolder")
	assert(type(packageInfoMap) == "table", "Bad packageInfoMap")
	assert(defaultReplicationType, "No defaultReplicationType")

	for _, item in pairs(packageFolder:GetChildren()) do
		if (item:IsA("Folder") or item:IsA("Camera")) and item.Name == ScriptInfoUtils.DEPENDENCY_FOLDER_NAME then
			local packageInfoList = PackageInfoUtils.getPackageInfoListFromDependencyFolder(
				item,
				packageInfoMap,
				defaultReplicationType)

			for _, packageInfo in pairs(packageInfoList) do
				explicitDependencySet[packageInfo] = true
			end
		end
	end
end

return PackageInfoUtils