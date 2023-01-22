--[=[
	@private
	@class LoaderUtils
]=]

local loader = script.Parent
local BounceTemplateUtils = require(script.Parent.BounceTemplateUtils)
local GroupInfoUtils = require(script.Parent.GroupInfoUtils)
local PackageInfoUtils = require(script.Parent.PackageInfoUtils)
local ScriptInfoUtils = require(script.Parent.ScriptInfoUtils)
local Utils = require(script.Parent.Utils)

local LoaderUtils = {}
LoaderUtils.Utils = Utils -- TODO: Remove this

LoaderUtils.ContextTypes = Utils.readonly({
	CLIENT = "client";
	SERVER = "server";
})
LoaderUtils.IncludeBehavior = Utils.readonly({
	NO_INCLUDE = "noInclude";
	INCLUDE_ONLY = "includeOnly";
	INCLUDE_SHARED = "includeShared";
})

function LoaderUtils.toWallyFormat(instance, isPlugin)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(isPlugin) == "boolean", "Bad isPlugin")

	local topLevelPackages = {}
	LoaderUtils.discoverTopLevelPackages(topLevelPackages, instance)
	LoaderUtils.injectLoader(topLevelPackages)

	local packageInfoList = {}
	local packageInfoMap = {}
	local defaultReplicationType = isPlugin
		and ScriptInfoUtils.ModuleReplicationTypes.PLUGIN
		or ScriptInfoUtils.ModuleReplicationTypes.SHARED

	for _, folder in pairs(topLevelPackages) do
		local packageInfo = PackageInfoUtils.getOrCreatePackageInfo(folder, packageInfoMap, "", defaultReplicationType)
		table.insert(packageInfoList, packageInfo)
	end

	PackageInfoUtils.fillDependencySet(packageInfoList)

	if isPlugin then
		local pluginGroup = GroupInfoUtils.groupPackageInfos(packageInfoList,
			ScriptInfoUtils.ModuleReplicationTypes.PLUGIN)

		local publishSet = LoaderUtils.getPublishPackageInfoSet(packageInfoList)

		local pluginFolder = Instance.new("Folder")
		pluginFolder.Name = "PluginPackages"

		LoaderUtils.reifyGroupList(pluginGroup, publishSet, pluginFolder, ScriptInfoUtils.ModuleReplicationTypes.PLUGIN)

		return pluginFolder
	else
		local clientGroupList = GroupInfoUtils.groupPackageInfos(packageInfoList,
			ScriptInfoUtils.ModuleReplicationTypes.CLIENT)
		local serverGroupList = GroupInfoUtils.groupPackageInfos(packageInfoList,
			ScriptInfoUtils.ModuleReplicationTypes.SERVER)
		local sharedGroupList = GroupInfoUtils.groupPackageInfos(packageInfoList,
			ScriptInfoUtils.ModuleReplicationTypes.SHARED)

		local publishSet = LoaderUtils.getPublishPackageInfoSet(packageInfoList)

		local clientFolder = Instance.new("Folder")
		clientFolder.Name = "Packages"

		local sharedFolder = Instance.new("Folder")
		sharedFolder.Name = "SharedPackages"

		local serverFolder = Instance.new("Folder")
		serverFolder.Name = "Packages"

		LoaderUtils.reifyGroupList(clientGroupList, publishSet, clientFolder, ScriptInfoUtils.ModuleReplicationTypes.CLIENT)
		LoaderUtils.reifyGroupList(serverGroupList, publishSet, serverFolder, ScriptInfoUtils.ModuleReplicationTypes.SERVER)
		LoaderUtils.reifyGroupList(sharedGroupList, publishSet, sharedFolder, ScriptInfoUtils.ModuleReplicationTypes.SHARED)

		return clientFolder, serverFolder, sharedFolder
	end
end

function LoaderUtils.isPackage(folder)
	assert(typeof(folder) == "Instance", "Bad instance")

	for _, item in pairs(folder:GetChildren()) do
		if item:IsA("Folder") or item:IsA("Camera") then
			if item.Name == "Server"
				or item.Name == "Client"
				or item.Name == "Shared"
				or item.Name == ScriptInfoUtils.DEPENDENCY_FOLDER_NAME then
				return true
			end
		end
	 end

	 return false
end

function LoaderUtils.injectLoader(topLevelPackages)
	for _, item in pairs(topLevelPackages) do
		-- If we're underneath the hierachy or if we're in the actual item...
		if item == loader or loader:IsDescendantOf(item) then
			return
		end
	end

	-- We need the loader injected!
	table.insert(topLevelPackages, loader)
end

function LoaderUtils.discoverTopLevelPackages(packages, instance)
	assert(type(packages) == "table", "Bad packages")
	assert(typeof(instance) == "Instance", "Bad instance")

	if LoaderUtils.isPackage(instance) then
		table.insert(packages, instance)
	elseif instance:IsA("ObjectValue") then
		local linkedValue = instance.Value
		if linkedValue and LoaderUtils.isPackage(linkedValue) then
			table.insert(packages, linkedValue)
		end
	else
		-- Loop through all folders
		for _, item in pairs(instance:GetChildren()) do
			if item:IsA("Folder") or item:IsA("Camera") then
				LoaderUtils.discoverTopLevelPackages(packages, item)
			elseif item:IsA("ObjectValue") then
				local linkedValue = item.Value
				if linkedValue and LoaderUtils.isPackage(linkedValue) then
					table.insert(packages, linkedValue)
				end
			elseif item:IsA("ModuleScript") then
				table.insert(packages, item)
			end
		end
	end
end

function LoaderUtils.reifyGroupList(groupInfoList, publishSet, parent, replicationMode)
	assert(type(groupInfoList) == "table", "Bad groupInfoList")
	assert(type(publishSet) == "table", "Bad publishSet")
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(replicationMode) == "string", "Bad replicationMode")

	local folder = Instance.new("Folder")
	folder.Name = "_Index"

	for _, groupInfo in pairs(groupInfoList) do
		if LoaderUtils.needToReify(groupInfo, replicationMode) then
			LoaderUtils.reifyGroup(groupInfo, folder, replicationMode)
		end
	end

	-- Publish
	for packageInfo, _ in pairs(publishSet) do
		for scriptName, scriptInfo in pairs(packageInfo.scriptInfoLookup[replicationMode]) do
			local link = BounceTemplateUtils.create(scriptInfo.instance, scriptName)
			link.Parent = parent
		end
	end

	folder.Parent = parent
end

function LoaderUtils.getPublishPackageInfoSet(packageInfoList)
	local packageInfoSet = {}
	for _, packageInfo in pairs(packageInfoList) do
		packageInfoSet[packageInfo] = true
		-- First level declared dependencies too (assuming we're importing just one item)
		for dependentPackageInfo, _ in pairs(packageInfo.explicitDependencySet) do
			packageInfoSet[dependentPackageInfo] = true
		end
	end
	return packageInfoSet
end

function LoaderUtils.needToReify(groupInfo, replicationMode)
	for _, scriptInfo in pairs(groupInfo.packageScriptInfoMap) do
		if scriptInfo.replicationMode == replicationMode then
			return true
		end
	end

	return false
end

function LoaderUtils.reifyGroup(groupInfo, parent, replicationMode)
	assert(type(groupInfo) == "table", "Bad groupInfo")
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(replicationMode) == "string", "Bad replicationMode")

	local folder = Instance.new("Folder")
	folder.Name = assert(next(groupInfo.packageSet).fullName, "Bad package fullName")

	for scriptName, scriptInfo in pairs(groupInfo.packageScriptInfoMap) do
		assert(scriptInfo.name == scriptName, "Bad scriptInfo.name")

		if scriptInfo.replicationMode == replicationMode then
			if scriptInfo.instance == loader and loader.Parent == game:GetService("ReplicatedStorage") then
				-- Hack to prevent reparenting of loader in legacy mode
				local link = BounceTemplateUtils.create(scriptInfo.instance, scriptName)
				link.Parent = folder
			else
				scriptInfo.instance.Name = scriptName
				scriptInfo.instance.Parent = folder
			end
		else
			if scriptInfo.instance == loader then
				local link = BounceTemplateUtils.create(scriptInfo.instance, scriptName)
				link.Parent = folder
			else
				-- Turns out creating these links are a LOT faster than cloning a module script
				local link = BounceTemplateUtils.createLink(scriptInfo.instance, scriptName)
				link.Parent = folder
			end
		end
	end

	-- Link all of the other dependencies
	for scriptName, scriptInfo in pairs(groupInfo.scriptInfoMap) do
		assert(scriptInfo.name == scriptName, "Bad scriptInfo.name")

		if not groupInfo.packageScriptInfoMap[scriptName] then
			if scriptInfo.instance == loader then
				local link = BounceTemplateUtils.create(scriptInfo.instance, scriptName)
				link.Parent = folder
			else
				-- Turns out creating these links are a LOT faster than cloning a module script
				local link = BounceTemplateUtils.createLink(scriptInfo.instance, scriptName)
				link.Parent = folder
			end
		end
	end

	folder.Parent = parent
end

return LoaderUtils