--!strict
--[=[
	@class PackageTrackerProvider
]=]

local loader = script.Parent.Parent

local Maid = require(loader.Maid)
local PackageTracker = require(loader.Dependencies.PackageTracker)

local PackageTrackerProvider = {}
PackageTrackerProvider.ClassName = "PackageTrackerProvider"
PackageTrackerProvider.__index = PackageTrackerProvider

export type PackageTrackerProvider = typeof(setmetatable(
	{} :: {
		_packageTrackersRoots: { [Instance]: PackageTracker.PackageTracker },
		_maid: Maid.Maid,
		_trackCount: number,
	},
	{} :: typeof({ __index = PackageTrackerProvider })
))

function PackageTrackerProvider.new(): PackageTrackerProvider
	local self = setmetatable({}, PackageTrackerProvider)

	self._maid = Maid.new()
	self._packageTrackersRoots = {}
	self._trackCount = 0

	return self
end

function PackageTrackerProvider.AddPackageRoot(
	self: PackageTrackerProvider,
	instance: Instance
): PackageTracker.PackageTracker
	assert(typeof(instance) == "Instance", "Bad instance")

	if self._packageTrackersRoots[instance] then
		return self._packageTrackersRoots[instance]
	end

	self._trackCount += 1

	local maid = Maid.new()

	local packageTracker = PackageTracker.new(self :: any, instance)
	maid:GiveTask(packageTracker)

	self._packageTrackersRoots[instance] = packageTracker
	self._maid[instance] = maid

	packageTracker:StartTracking()

	-- TODO: Provide cleanup mechanism

	return self._packageTrackersRoots[instance]
end

function PackageTrackerProvider.FindPackageTracker(
	self: PackageTrackerProvider,
	instance: Instance
): PackageTracker.PackageTracker?
	assert(typeof(instance) == "Instance", "Bad instance")

	local current = instance
	while current do
		if self._packageTrackersRoots[current] then
			return self._packageTrackersRoots[current]
		end

		current = current.Parent :: Instance
	end

	return nil
end

function PackageTrackerProvider.Destroy(self: PackageTrackerProvider)
	self._maid:DoCleaning()
end

return PackageTrackerProvider
