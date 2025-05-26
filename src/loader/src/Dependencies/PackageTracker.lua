--!strict
--[=[
	For each package, track subdependent packages and packages

	@class PackageTracker
]=]

local loader = script.Parent.Parent
local DependencyUtils = require(loader.Dependencies.DependencyUtils)
local Maid = require(loader.Maid)
local ReplicationType = require(loader.Replication.ReplicationType)
local ReplicationTypeUtils = require(loader.Replication.ReplicationTypeUtils)

local PackageTracker = {}
PackageTracker.ClassName = "PackageTracker"
PackageTracker.__index = PackageTracker

export type ModuleScriptInfo = {
	moduleScript: ModuleScript,
	replicationType: ReplicationType.ReplicationType,
}

export type PackageTrackerProvider = {
	FindPackageTracker: (self: PackageTrackerProvider, instance: Instance) -> PackageTracker?,
	AddPackageRoot: (self: PackageTrackerProvider, instance: Instance) -> PackageTracker,
}

export type PackageTracker = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_packageTrackerProvider: PackageTrackerProvider,
		_packageRoot: Instance,
		_subpackagesMap: { [string]: Instance },
		_subpackagesTrackerList: { PackageTracker },
		_packageModuleScriptMap: { [string]: ModuleScriptInfo },
	},
	{} :: typeof({ __index = PackageTracker })
))

function PackageTracker.new(packageTrackerProvider: PackageTrackerProvider, packageRoot: Instance): PackageTracker
	assert(packageTrackerProvider, "No packageTrackerProvider")
	assert(typeof(packageRoot) == "Instance", "Bad packageRoot")

	local self = setmetatable({}, PackageTracker)
	self._maid = Maid.new()

	self._packageTrackerProvider = assert(packageTrackerProvider, "No packageTrackerProvider")
	self._packageRoot = assert(packageRoot, "No packageRoot")

	self._subpackagesMap = {} :: { [string]: Instance }
	self._subpackagesTrackerList = {} :: { PackageTracker }
	self._packageModuleScriptMap = {} :: { [string]: ModuleScriptInfo }

	return self
end

function PackageTracker.StartTracking(self: PackageTracker)
	local moduleScript: ModuleScript? = nil
	if self._packageRoot:IsA("ModuleScript") then
		moduleScript = self._packageRoot
	end

	if moduleScript ~= nil then
		-- Module script children don't get to be observed
		self._maid:GiveTask(self:_trackModuleScript(moduleScript, ReplicationType.SHARED))
	else
		local root = self._packageRoot :: Instance
		self._maid:GiveTask(self:_trackChildren(root, ReplicationType.SHARED))
	end
end

function PackageTracker.ResolveDependency(
	self: PackageTracker,
	request: string,
	replicationType: ReplicationType.ReplicationType
): ModuleScript?
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

function PackageTracker.FindImplicitParentModuleScript(
	self: PackageTracker,
	request: string,
	replicationType: ReplicationType.ReplicationType
): ModuleScript?
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

	return parentProvider:FindImplicitParentModuleScript(request, replicationType) :: ModuleScript?
end

function PackageTracker.FindPackageModuleScript(
	self: PackageTracker,
	moduleScriptName: string,
	replicationType: ReplicationType.ReplicationType
): ModuleScript?
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

function PackageTracker.FindSubpackageModuleScript(
	self: PackageTracker,
	moduleScriptName: string,
	replicationType: ReplicationType.ReplicationType
): ModuleScript?
	assert(type(moduleScriptName) == "string", "Bad moduleScriptName")
	assert(ReplicationTypeUtils.isReplicationType(replicationType), "Bad replicationType")

	for _, packageTracker in self._subpackagesTrackerList do
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

function PackageTracker._trackChildrenAndReplicationType(
	self: PackageTracker,
	parent: Instance,
	ancestorReplicationType: ReplicationType.ReplicationType
)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	local maid = Maid.new()

	local lastReplicationType: ReplicationType.ReplicationType =
		ReplicationTypeUtils.getFolderReplicationType(parent.Name, ancestorReplicationType)

	maid:GiveTask(parent:GetPropertyChangedSignal("Name"):Connect(function()
		local newReplicationType: ReplicationType.ReplicationType =
			ReplicationTypeUtils.getFolderReplicationType(parent.Name, ancestorReplicationType)
		if newReplicationType ~= lastReplicationType then
			maid._current = self:_trackChildren(parent, newReplicationType)
			lastReplicationType = newReplicationType
		end
	end))

	maid._current = self:_trackChildren(parent, lastReplicationType)

	return maid
end

function PackageTracker._trackChildren(
	self: PackageTracker,
	parent: Instance,
	ancestorReplicationType: ReplicationType.ReplicationType
): Maid.Maid
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	local maid = Maid.new()

	maid:GiveTask(parent.ChildAdded:Connect(function(child)
		self:_handleChildAdded(maid, child, ancestorReplicationType)
	end))
	maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_handleChildRemoved(maid, child)
	end))
	for _, child in parent:GetChildren() do
		self:_handleChildAdded(maid, child, ancestorReplicationType)
	end

	return maid
end

function PackageTracker._handleChildAdded(
	self: PackageTracker,
	parentMaid: Maid.Maid,
	child: Instance,
	ancestorReplicationType: ReplicationType.ReplicationType
)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	if child:IsA("ModuleScript") then
		parentMaid[child] = self:_trackModuleScript(child, ancestorReplicationType)
	elseif child:IsA("Folder") then
		parentMaid[child] = self:_trackFolder(child, ancestorReplicationType)
	end
end

function PackageTracker._handleChildRemoved(_self: PackageTracker, parentMaid: Maid.Maid, child: Instance)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	parentMaid[child] = nil
end

function PackageTracker._trackFolder(
	self: PackageTracker,
	child: Instance,
	ancestorReplicationType: ReplicationType.ReplicationType
)
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

function PackageTracker._trackModuleScript(
	self: PackageTracker,
	child: ModuleScript,
	ancestorReplicationType: ReplicationType.ReplicationType
): Maid.Maid
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

function PackageTracker._storeModuleScript(
	self: PackageTracker,
	moduleScriptName: string,
	child: ModuleScript,
	ancestorReplicationType: ReplicationType.ReplicationType
): () -> ()
	assert(type(moduleScriptName) == "string", "Bad moduleScriptName")
	assert(typeof(child) == "Instance", "Bad child")
	assert(ReplicationTypeUtils.isReplicationType(ancestorReplicationType), "Bad ancestorReplicationType")

	if self._packageModuleScriptMap[moduleScriptName] then
		warn(string.format("[PackageTracker] - Overwriting moduleScript with name %q", moduleScriptName))
	end

	local data: ModuleScriptInfo = {
		moduleScript = child,
		replicationType = ancestorReplicationType,
	}
	self._packageModuleScriptMap[moduleScriptName] = data

	return function()
		if self._packageModuleScriptMap[moduleScriptName] == data then
			self._packageModuleScriptMap[moduleScriptName] = nil
		end
	end
end

function PackageTracker._trackMainNodeModuleFolder(self: PackageTracker, parent: Instance): Maid.Maid
	local maid = Maid.new()

	maid:GiveTask(parent.ChildAdded:Connect(function(child)
		self:_handleNodeModulesChildAdded(maid, child)
	end))
	maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_handleNodeModulesChildRemoved(maid, child)
	end))
	for _, child in parent:GetChildren() do
		self:_handleNodeModulesChildAdded(maid, child)
	end

	return maid
end

function PackageTracker._handleNodeModulesChildAdded(self: PackageTracker, parentMaid: Maid.Maid, child: Instance)
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

function PackageTracker._handleNodeModulesChildRemoved(_self: PackageTracker, parentMaid: Maid.Maid, child: Instance)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	parentMaid[child] = nil
end

function PackageTracker._trackNodeModulesChildFolder(self: PackageTracker, child: Instance): Maid.Maid
	assert(typeof(child) == "Instance", "Bad child")

	local maid = Maid.new()

	local function update(): Maid.MaidTask
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

function PackageTracker._trackNodeModulesObjectValue(self: PackageTracker, objectValue: ObjectValue): Maid.Maid
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

function PackageTracker._trackScopedChildFolder(self: PackageTracker, scopeName: string, parent: Instance): Maid.Maid
	assert(type(scopeName) == "string", "Bad scopeName")
	assert(typeof(parent) == "Instance", "Bad parent")

	local maid = Maid.new()

	maid:GiveTask(parent.ChildAdded:Connect(function(child)
		self:_handleScopedModulesChildAdded(scopeName, maid, child)
	end))
	maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_handleScopedModulesChildRemoved(maid, child)
	end))
	for _, child in parent:GetChildren() do
		self:_handleScopedModulesChildAdded(scopeName, maid, child)
	end

	return maid
end

function PackageTracker._handleScopedModulesChildAdded(
	self: PackageTracker,
	scopeName: string,
	parentMaid: Maid.Maid,
	child: Instance
)
	assert(type(scopeName) == "string", "Bad scopeName")
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	if child:IsA("ObjectValue") then
		parentMaid[child] = self:_trackScopedNodeModulesObjectValue(scopeName, child)
	elseif child:IsA("Folder") or child:IsA("ModuleScript") then
		parentMaid[child] = self:_trackAddScopedPackage(scopeName, child)
	end
end

function PackageTracker._trackScopedNodeModulesObjectValue(
	self: PackageTracker,
	scopeName: string,
	objectValue: ObjectValue
)
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

function PackageTracker._handleScopedModulesChildRemoved(_self: PackageTracker, parentMaid: Maid.Maid, child: Instance)
	assert(Maid.isMaid(parentMaid), "Bad maid")
	assert(typeof(child) == "Instance", "Bad child")

	parentMaid[child] = nil
end

function PackageTracker._trackAddScopedPackage(self: PackageTracker, scopeName: string, child: Instance)
	assert(type(scopeName) == "string", "Bad scopeName")
	assert(typeof(child) == "Instance", "Bad child")

	local maid = Maid.new()

	maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(function()
		maid._current = self:_tryStorePackage(scopeName .. "/" .. child.Name, child)
	end))

	maid._current = self:_tryStorePackage(scopeName .. "/" .. child.Name, child)

	return maid
end

function PackageTracker._trackAddPackage(self: PackageTracker, child: Instance)
	assert(typeof(child) == "Instance", "Bad child")

	local maid = Maid.new()

	maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(function()
		maid._current = self:_tryStorePackage(child.Name, child)
	end))

	maid._current = self:_tryStorePackage(child.Name, child)

	return maid
end

function PackageTracker._tryStorePackage(
	self: PackageTracker,
	fullPackageName: string,
	packageInst: Instance?
): (() -> ())?
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

function PackageTracker.Destroy(self: PackageTracker)
	self._maid:DoCleaning()
end

return PackageTracker
