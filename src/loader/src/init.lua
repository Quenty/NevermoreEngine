--[=[
	Primary loader which handles bootstrapping different scenarios quickly

	@class loader
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DependencyUtils = require(script.Dependencies.DependencyUtils)
local LoaderLinkCreator = require(script.LoaderLink.LoaderLinkCreator)
local LoaderLinkUtils = require(script.LoaderLink.LoaderLinkUtils)
local Maid = require(script.Maid)
local PackageTrackerProvider = require(script.Dependencies.PackageTrackerProvider)
local ReplicationType = require(script.Replication.ReplicationType)
local ReplicationTypeUtils = require(script.Replication.ReplicationTypeUtils)
local Replicator = require(script.Replication.Replicator)
local ReplicatorReferences = require(script.Replication.ReplicatorReferences)

local GLOBAL_PACKAGE_TRACKER = PackageTrackerProvider.new()
script.Destroying:Connect(function()
	GLOBAL_PACKAGE_TRACKER:Destroy()
end)

local Loader = {}
Loader.__index = Loader
Loader.ClassName = "Loader"

function Loader.new(packages, replicationType)
	assert(typeof(packages) == "Instance", "Bad packages")
	assert(ReplicationTypeUtils.isReplicationType(replicationType), "Bad replicationType")

	local self = setmetatable({}, Loader)

	self._maid = Maid.new()

	self._replicationType = assert(replicationType, "No replicationType")
	self._packages = assert(packages, "No packages")

	return self
end

function Loader.bootstrapGame(packages)
	assert(typeof(packages) == "Instance", "Bad packages")

	local self = Loader.new(packages, ReplicationTypeUtils.inferReplicationType())

	if self._replicationType == ReplicationType.SERVER then
		self:_setupLoaderPopulation(self._packages)

		-- Trade off security for performance
		if RunService:IsStudio() then
			packages.Parent = ReplicatedStorage
		else
			self:_setupClientReplication()
		end
	end

	GLOBAL_PACKAGE_TRACKER:AddPackageRoot(packages)

	return self
end

function Loader.bootstrapPlugin(packages)
	assert(typeof(packages) == "Instance", "Bad packages")

	local self = Loader.new(packages, ReplicationType.PLUGIN)

	self:_setupLoaderPopulation(self._packages)

	GLOBAL_PACKAGE_TRACKER:AddPackageRoot(packages)

	return self
end

function Loader.bootstrapStory(storyScript)
	assert(typeof(storyScript) == "Instance", "Bad storyScript")

	-- Prepopulate global package roots
	local topNodeModules = storyScript
	for node_modules in DependencyUtils.iterNodeModulesUp(storyScript) do
		topNodeModules = node_modules
	end

	local self = Loader.new(storyScript, ReplicationType.PLUGIN)

	local root = topNodeModules.Parent

	self:_setupLoaderPopulation(root)

	-- Track the package root
	GLOBAL_PACKAGE_TRACKER:AddPackageRoot(root)

	return self
end

function Loader.load(packagesOrModuleScript)
	assert(typeof(packagesOrModuleScript) == "Instance", "Bad packagesOrModuleScript")

	local self = Loader.new(packagesOrModuleScript, ReplicationTypeUtils.inferReplicationType())

	return self
end

function Loader:__index(request)
	if Loader[request] then
		return Loader[request]
	end

	return self:_findDependency(request)
end

function Loader:__call(request)
	if type(request) == "string" then
		local module = self:_findDependency(request)
		return require(module)
	else
		return require(request)
	end
end

function Loader:_findDependency(request: string)
	assert(type(request) == "string", "Bad request")

	local packageTracker = GLOBAL_PACKAGE_TRACKER:FindPackageTracker(self._packages)
	if packageTracker then
		local foundDependency = packageTracker:ResolveDependency(request, self._replicationType)
		if foundDependency then
			return foundDependency
		end

		-- Otherwise let's fail with an error acknowledging that the module exists
		if self._replicationType == ReplicationType.SERVER or self._replicationType == ReplicationType.SHARED then
			local foundClientDependency = packageTracker:ResolveDependency(request, ReplicationType.CLIENT)
			if foundClientDependency then
				error(string.format("[Loader] - %q is only available on the client", foundClientDependency.Name))
			end
		end

		if self._replicationType == ReplicationType.CLIENT or self._replicationType == ReplicationType.SHARED then
			local foundServerDependency = packageTracker:ResolveDependency(request, ReplicationType.SERVER)
			if foundServerDependency then
				error(string.format("[Loader] - %q is only available on the server", foundServerDependency.Name))
			end
		end
	end

	-- Just standard dependency search
	local foundBackup = DependencyUtils.findDependency(self._packages, request, self._replicationType)
	if foundBackup then
		if packageTracker then
			warn(
				string.format(
					"[Loader] - No package tracker for root %s (while loading %s)\n%s",
					self._packages:GetFullName(),
					request,
					debug.traceback()
				)
			)
		else
			warn(
				string.format(
					"[Loader] - Failed to find package %q in package tracker of root %s\n%s",
					request,
					self._packages:GetFullName(),
					debug.traceback()
				)
			)
		end

		-- Ensure hoarcekat story has a link to use
		-- TODO: Maybe add to global package cache instead...
		local parent = foundBackup.Parent
		if parent and not parent:FindFirstChild("loader") then
			local link = LoaderLinkUtils.create(script, "loader")
			link.Parent = parent
		end

		return foundBackup
	end

	-- TODO: Track location and provider install command
	error(
		string.format(
			"[Loader] - %q is not available. Please make this module or install it to the package requiring it.",
			request
		)
	)
	return nil
end

function Loader:_setupClientReplication()
	local copy = self._maid:Add(Instance.new("Folder"))
	copy.Name = self._packages.Name

	local references = ReplicatorReferences.new()

	local replicator = self._maid:Add(Replicator.new(references))
	replicator:SetTarget(copy)
	replicator:ReplicateFrom(self._packages)

	self._maid:Add(LoaderLinkCreator.new(copy, references, true))

	copy.Parent = ReplicatedStorage
end

function Loader:_setupLoaderPopulation(root)
	self._maid:Add(LoaderLinkCreator.new(root, nil, true))
end

function Loader:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return Loader
