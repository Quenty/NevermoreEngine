--[=[
	For each package, track subdependent packages and packages

	@class PackageTracker
]=]

local loader = script.Parent.Parent
local Maid = require(loader.Maid)
local DependencyUtils = require(loader.Dependencies.DependencyUtils)
local ReplicationType = require(loader.Replication.ReplicationType)
local ReplicationTypeUtils = require(loader.Replication.ReplicationTypeUtils)

local PackageTracker = {}
PackageTracker.ClassName = "PackageTracker"
PackageTracker.__index = PackageTracker

function PackageTracker.new(packageTrackerProvider, packageRoot)
	assert(packageTrackerProvider, "No packageTrackerProvider")
	assert(typeof(packageRoot) == "Instance", "Bad packageRoot")

	local self = setmetatable({}, PackageTracker)
	self._maid = Maid.new()

	self._packageTrackerProvider = assert(packageTrackerProvider, "No packageTrackerProvider")
	self._packageRoot = assert(packageRoot, "No packageRoot")

	self._subpackagesMap = {}
	self._subpackagesTrackerList = {}
	self._packageModuleScriptMap = {}

	return self
end

function PackageTracker:StartTracking()
	if self._packageRoot:IsA("ModuleScript") then
		-- Module script children don't get to be observed
		self._maid:GiveTask(self:_trackModuleScript(self._packageRoot, ReplicationType.SHARED))
	else
		self._maid:GiveTask(self:_trackChildren(self._packageRoot, ReplicationType.SHARED))
	end
end

function PackageTracker:ResolveDependency(request, replicationType)
	local packageModuleScript = self:FindPackageModuleScript(request, replicationType)
	if packageModuleScript then
		return packageModuleScript
	end

	local subpackageModuleScript = self:FindSubpackageModuleScript(request, replicationType)
	if subpackageModuleScript then
		return subpackageModuleScript
	end

	local parentModuleScript = self:FindImplicitParentModuleScript(request, replicationType)
	if parentModuleScript then
		return parentModuleScript
	end

	return nil
end

function PackageTracker:FindImplicitParentModuleScript(request, replicationType)
	assert(type(request) == "string", "Bad request")
	assert(ReplicationTypeUtils.isReplicationType(replicationType), "Bad replicationType")

	-- Implicit dependencies
	local packageRootParent = self._packageRoot.Parent
	if not packageRootParent then
		return nil
	end

	local parentProvider = self._packageTrackerProvider:FindPackageTracker(packageRootParent)
	if not parentProvider then
		return nil
	end

	-- Check parent provider for implicit dependency
	local subpackageModuleScript = parentProvider:FindSubpackageModuleScript(request, replicationType)
	if subpackageModuleScript then
		return subpackageModuleScript
	end

	return parentProvider:FindImplicitParentModuleScript(request, replicationType)
end

function PackageTracker:FindPackageModuleScript(moduleScriptName, replicationType)
	assert(type(moduleScriptName) == "string", "Bad moduleScriptName")
	assert(ReplicationTypeUtils.isReplicationType(replicationType), "Bad replicationType")

	local found = self._packageModuleScriptMap[moduleScriptName]

	if found then
		if ReplicationTypeUtils.isAllowed(found.replicationType, replicationType) then
			return found.moduleScript
		else
			return nil
		end
	else
		return nil
	end
end

function PackageTracker:FindSubpackageModuleScript(moduleScriptName, replicationType)
	assert(type(moduleScriptName) == "string", "Bad moduleScriptName")
	assert(ReplicationTypeUtils.isReplicationType(replicationType), "Bad replicationType")

	for _, packageTracker in pairs(self._subpackagesTrackerList) do
		local found = packageTracker._packageModuleScriptMap[moduleScriptName]
		if found then
			if ReplicationTypeUtils.isAllowed(found.replicationType, replicationType) then
				return found.moduleScript
			else
				return nil
			end
		end
	end

	return nil
end

function PackageTracker:_trackChildrenAndReplicationType(parent, ancestorReplicationType)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	local maid = Maid.new()

	local lastReplicationType = ReplicationTypeUtils.getFolderReplicationType(parent.Name, ancestorReplicationType)

	maid:GiveTask(parent:GetPropertyChangedSignal("Name"):Connect(function()
		local newReplicationType = ReplicationTypeUtils.getFolderReplicationType(parent.Name, ancestorReplicationType)
		if newReplicationType ~= lastReplicationType then
			maid._current = self:_trackChildren(parent, newReplicationType)
			lastReplicationType = newReplicationType
		end
	end))

	maid._current = self:_trackChildren(parent, lastReplicationType)

	return maid
end

function PackageTracker:_trackChildren(parent, ancestorReplicationType)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	local maid = Maid.new()

	maid:GiveTask(parent.ChildAdded:Connect(function(child)
		self:_handleChildAdded(maid, child, ancestorReplicationType)
	end))
	maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_handleChildRemoved(maid, child, ancestorReplicationType)
	end))
	for _, child in pairs(parent:GetChildren()) do
		self:_handleChildAdded(maid, child, ancestorReplicationType)
	end

	return maid
end

function PackageTracker:_handleChildAdded(parentMaid, child, ancestorReplicationType)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	if child:IsA("ModuleScript") then
		parentMaid[child] = self:_trackModuleScript(child, ancestorReplicationType)
	elseif child:IsA("Folder") then
		parentMaid[child] = self:_trackFolder(child, ancestorReplicationType)
	end
end

function PackageTracker:_handleChildRemoved(parentMaid, child)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	parentMaid[child] = nil
end


function PackageTracker:_trackFolder(child, ancestorReplicationType)
	assert(typeof(child) == "Instance", "Bad child")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	local maid = Maid.new()

	maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(function()
		if child.Name == "node_modules" then
			maid._current = self:_trackMainNodeModuleFolder(child)
		else
			maid._current = self:_trackChildrenAndReplicationType(child, ancestorReplicationType)
		end
	end))

	if child.Name == "node_modules" then
		maid._current = self:_trackMainNodeModuleFolder(child)
	else
		maid._current = self:_trackChildrenAndReplicationType(child, ancestorReplicationType)
	end

	return maid
end


function PackageTracker:_trackModuleScript(child, ancestorReplicationType)
	assert(typeof(child) == "Instance", "Bad child")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")


	local maid = Maid.new()

	local function update()
		if child.Archivable then
			maid._current = self:_storeModuleScript(child.Name, child, ancestorReplicationType)
		else
			maid._current = nil
		end
	end

	maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(update))
	maid:GiveTask(child:GetPropertyChangedSignal("Archivable"):Connect(update))

	update()

	return maid
end

function PackageTracker:_storeModuleScript(moduleScriptName, child, ancestorReplicationType)
	assert(type(moduleScriptName) == "string", "Bad moduleScriptName")
	assert(typeof(child) == "Instance", "Bad child")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	if self._packageModuleScriptMap[moduleScriptName] then
		warn(string.format("[PackageTracker] - Overwriting moduleScript with name %q", moduleScriptName))
	end

	local data = {
		moduleScript = child;
		replicationType = ancestorReplicationType;
	}
	self._packageModuleScriptMap[moduleScriptName] = data

	return function()
		if self._packageModuleScriptMap[moduleScriptName] == data then
			self._packageModuleScriptMap[moduleScriptName] = nil
		end
	end
end

function PackageTracker:_trackMainNodeModuleFolder(parent)
	local maid = Maid.new()

	maid:GiveTask(parent.ChildAdded:Connect(function(child)
		self:_handleNodeModulesChildAdded(maid, child)
	end))
	maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_handleNodeModulesChildRemoved(maid, child)
	end))
	for _, child in pairs(parent:GetChildren()) do
		self:_handleNodeModulesChildAdded(maid, child)
	end

	return maid
end


function PackageTracker:_handleNodeModulesChildAdded(parentMaid, child)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	if child:IsA("ObjectValue") then
		-- Assume symlinked package
		parentMaid[child] = self:_trackNodeModulesObjectValue(child)
	elseif child:IsA("Folder") then
		parentMaid[child] = self:_trackNodeModulesChildFolder(child)
	elseif child:IsA("ModuleScript") then
		parentMaid[child] = self:_trackAddPackage(child)
	end
end

function PackageTracker:_handleNodeModulesChildRemoved(parentMaid, child)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	parentMaid[child] = nil
end

function PackageTracker:_trackNodeModulesChildFolder(child)
	assert(typeof(child) == "Instance", "Bad child")

	local maid = Maid.new()

	local function update()
		local childName = child.Name

		-- like @quenty
		if DependencyUtils.isPackageGroup(childName) then
			return self:_trackScopedChildFolder(childName, child)
		else
			return self:_tryStorePackage(childName, child)
		end
	end

	maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(function()
		maid._current = update()
	end))

	maid._current = update()

	return maid
end

function PackageTracker:_trackNodeModulesObjectValue(objectValue)
	assert(typeof(objectValue) == "Instance", "Bad objectValue")

	local maid = Maid.new()

	maid:GiveTask(objectValue:GetPropertyChangedSignal("Name"):Connect(function()
		maid._current = self:_tryStorePackage(objectValue.Name, objectValue.Value)
	end))
	maid:GiveTask(objectValue:GetPropertyChangedSignal("Value"):Connect(function()
		maid._current = self:_tryStorePackage(objectValue.Name, objectValue.Value)
	end))

	maid._current = self:_tryStorePackage(objectValue.Name, objectValue.Value)

	return maid
end

function PackageTracker:_trackScopedChildFolder(scopeName, parent)
	assert(type(scopeName) == "string", "Bad scopeName")
	assert(typeof(parent) == "Instance", "Bad parent")

	local maid = Maid.new()

	maid:GiveTask(parent.ChildAdded:Connect(function(child)
		self:_handleScopedModulesChildAdded(scopeName, maid, child)
	end))
	maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_handleScopedModulesChildRemoved(maid, child)
	end))
	for _, child in pairs(parent:GetChildren()) do
		self:_handleScopedModulesChildAdded(scopeName, maid, child)
	end

	return maid
end

function PackageTracker:_handleScopedModulesChildAdded(scopeName, parentMaid, child)
	assert(type(scopeName) == "string", "Bad scopeName")
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	if child:IsA("ObjectValue") then
		parentMaid[child] = self:_trackScopedNodeModulesObjectValue(scopeName, child)
	elseif child:IsA("Folder") or child:IsA("ModuleScript") then
		parentMaid[child] = self:_trackAddScopedPackage(scopeName, child)
	end
end

function PackageTracker:_trackScopedNodeModulesObjectValue(scopeName, objectValue)
	assert(type(scopeName) == "string", "Bad scopeName")
	assert(typeof(objectValue) == "Instance", "Bad objectValue")

	local maid = Maid.new()

	maid:GiveTask(objectValue:GetPropertyChangedSignal("Name"):Connect(function()
		maid._current = self:_tryStorePackage(scopeName .. "/" .. objectValue.Name, objectValue.Value)
	end))
	maid:GiveTask(objectValue:GetPropertyChangedSignal("Value"):Connect(function()
		maid._current = self:_tryStorePackage(scopeName .. "/" .. objectValue.Name, objectValue.Value)
	end))

	maid._current = self:_tryStorePackage(scopeName .. "/" .. objectValue.Name, objectValue.Value)

	return maid
end

function PackageTracker:_handleScopedModulesChildRemoved(parentMaid, child)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	parentMaid[child] = nil
end

function PackageTracker:_trackAddScopedPackage(scopeName, child)
	assert(type(scopeName) == "string", "Bad scopeName")
	assert(typeof(child) == "Instance", "Bad child")

	local maid = Maid.new()

	maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(function()
		maid._current = self:_tryStorePackage(scopeName .. "/" .. child.Name, child)
	end))

	maid._current = self:_tryStorePackage(scopeName .. "/" .. child.Name, child)

	return maid
end

function PackageTracker:_trackAddPackage(child)
	assert(typeof(child) == "Instance", "Bad child")

	local maid = Maid.new()

	maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(function()
		maid._current = self:_tryStorePackage(child.Name, child)
	end))

	maid._current = self:_tryStorePackage(child.Name, child)

	return maid
end

function PackageTracker:_tryStorePackage(fullPackageName, packageInst)
	assert(type(fullPackageName) == "string", "Bad fullPackageName")

	if not packageInst then
		return nil
	end

	self._subpackagesMap[fullPackageName] = packageInst

	local packageTracker = self._packageTrackerProvider:AddPackageRoot(packageInst)
	table.insert(self._subpackagesTrackerList, packageTracker)

	return function()
		local index = table.find(self._subpackagesTrackerList, packageTracker)
		if index then
			table.remove(self._subpackagesTrackerList, index)
		end

		if self._subpackagesMap[fullPackageName] == packageInst then
			self._subpackagesMap[fullPackageName] = nil
		end
	end
end

function PackageTracker:Destroy()
	self._maid:DoCleaning()
end

return PackageTracker