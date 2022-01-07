--[=[
	Nevermore loader utility library
	@private
	@class GroupInfoUtils
]=]

local Utils = require(script.Parent.Utils)
local Queue = require(script.Parent.Queue)
local LoaderConstants = require(script.Parent.LoaderConstants)

local GroupInfoUtils = {}

function GroupInfoUtils.createGroupInfo()
	return Utils.readonly({
		scriptInfoMap = {}; -- [name] = scriptInfo (required link packages)
		packageScriptInfoMap = {};
		packageSet = {}; -- [packageInfo] = true (actually included packages)
	})
end

function GroupInfoUtils.groupPackageInfos(packageInfoList, replicationMode)
	assert(type(packageInfoList) == "table", "Bad packageInfoList")
	assert(type(replicationMode) == "string", "Bad replicationMode")

	local queue = Queue.new()
	local seen = {}

	for _, packageInfo in pairs(packageInfoList) do
		if not seen[packageInfo] then
			seen[packageInfo] = true
			queue:PushRight(packageInfo)
		end
	end

	local built = {}
	local current = GroupInfoUtils.createGroupInfo()
	while not queue:IsEmpty() do
		local packageInfo = queue:PopLeft()
		if GroupInfoUtils.hasAnythingToReplicate(packageInfo, replicationMode) then
			if GroupInfoUtils.canAddPackageInfoToGroup(current, packageInfo, replicationMode) then
				GroupInfoUtils.addPackageInfoToGroup(current, packageInfo, replicationMode)

				if LoaderConstants.GROUP_EACH_PACKAGE_INDIVIDUALLY then
					table.insert(built, current)
					current = GroupInfoUtils.createGroupInfo()
				end
			elseif LoaderConstants.ALLOW_MULTIPLE_GROUPS then
				-- Create a new group
				table.insert(built, current)
				current = GroupInfoUtils.createGroupInfo()
				GroupInfoUtils.addPackageInfoToGroup(current, packageInfo, replicationMode)
			else
				-- Force generate error
				GroupInfoUtils.addPackageInfoToGroup(current, packageInfo, replicationMode)

				error("Cannot add package to group")
			end
		end

		for dependentPackageInfo, _ in pairs(packageInfo.dependencySet) do
			if not seen[dependentPackageInfo] then
				seen[dependentPackageInfo] = true
				queue:PushRight(dependentPackageInfo)
			end
		end
	end

	if next(current.packageSet) then
		table.insert(built, current)
	end

	return built
end

function GroupInfoUtils.hasAnythingToReplicate(packageInfo, replicationMode)
	return next(packageInfo.scriptInfoLookup[replicationMode]) ~= nil
end

function GroupInfoUtils.canAddScriptInfoToGroup(groupInfo, scriptInfo, scriptName, tempScriptInfoMap)
	assert(type(groupInfo) == "table", "Bad groupInfo")
	assert(type(scriptInfo) == "table", "Bad scriptInfo")
	assert(type(scriptName) == "string", "Bad scriptName")
	assert(type(tempScriptInfoMap) == "table", "Bad tempScriptInfoMap")

	local wouldHaveInfo = tempScriptInfoMap[scriptName]
	if wouldHaveInfo and wouldHaveInfo ~= scriptInfo then
		return false
	end

	local currentScriptInfo = groupInfo.scriptInfoMap[scriptName]
	if currentScriptInfo and currentScriptInfo ~= scriptInfo then
		return false
	end

	return true
end

function GroupInfoUtils.canAddPackageInfoToGroup(groupInfo, packageInfo, replicationMode)
	assert(type(groupInfo) == "table", "Bad groupInfo")
	assert(type(packageInfo) == "table", "Bad packageInfo")
	assert(type(replicationMode) == "string", "Bad replicationMode")

	local tempScriptInfoMap = {}

	-- Existing scripts must be added
	for scriptName, scriptInfo in pairs(packageInfo.scriptInfoLookup[replicationMode]) do
		if GroupInfoUtils.canAddScriptInfoToGroup(groupInfo, scriptInfo, scriptName, tempScriptInfoMap) then
			tempScriptInfoMap[scriptName] = scriptInfo
		else
			return false
		end
	end

	-- Dependencies are expected at parent level
	for dependencyPackageInfo, _ in pairs(packageInfo.dependencySet) do
		if not groupInfo.packageSet[dependencyPackageInfo] then
			-- Lookup dependencies and try to merge them
			-- O(p*d*s)
			for scriptName, scriptInfo in pairs(dependencyPackageInfo.scriptInfoLookup[replicationMode]) do
				if GroupInfoUtils.canAddScriptInfoToGroup(groupInfo, scriptInfo, scriptName, tempScriptInfoMap) then
					tempScriptInfoMap[scriptName] = scriptInfo
				else
					return false
				end
			end
		end
	end

	return true
end

function GroupInfoUtils.addScriptToGroup(groupInfo, scriptName, scriptInfo)
	assert(type(groupInfo) == "table", "Bad groupInfo")
	assert(type(scriptInfo) == "table", "Bad scriptInfo")
	assert(type(scriptName) == "string", "Bad scriptName")

	local currentScriptInfo = groupInfo.scriptInfoMap[scriptName]
	if currentScriptInfo and currentScriptInfo ~= scriptInfo then
		error(("Cannot add to package group, conflicting scriptInfo for %q already there")
			:format(scriptName))
	end

	groupInfo.scriptInfoMap[scriptName] = scriptInfo
end

function GroupInfoUtils.addPackageInfoToGroup(groupInfo, packageInfo, replicationMode)
	groupInfo.packageSet[packageInfo] = true

	-- Existing scripts must be added
	for scriptName, scriptInfo in pairs(packageInfo.scriptInfoLookup[replicationMode]) do
		GroupInfoUtils.addScriptToGroup(groupInfo, scriptName, scriptInfo)
		groupInfo.packageScriptInfoMap[scriptName] = scriptInfo
	end

	-- Dependencies are expected at parent level
	for dependencyPackageInfo, _ in pairs(packageInfo.dependencySet) do
		if not groupInfo.packageSet[dependencyPackageInfo] then
			-- Lookup dependencies and try to merge them
			-- O(p*d*s)
			for scriptName, scriptInfo in pairs(dependencyPackageInfo.scriptInfoLookup[replicationMode]) do
				GroupInfoUtils.addScriptToGroup(groupInfo, scriptName, scriptInfo)
			end
		end
	end
end

return GroupInfoUtils