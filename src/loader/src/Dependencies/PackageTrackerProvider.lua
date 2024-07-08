--[=[
	@class PackageTrackerProvider
]=]

local loader = script.Parent.Parent

local Maid = require(loader.Maid)
local PackageTracker = require(loader.Dependencies.PackageTracker)

local PackageTrackerProvider = {}
PackageTrackerProvider.ClassName = "PackageTrackerProvider"
PackageTrackerProvider.__index = PackageTrackerProvider

function PackageTrackerProvider.new()
	local self = setmetatable({}, PackageTrackerProvider)

	self._maid = Maid.new()
	self._packageTrackersRoots = {}
	self._trackCount = 0

	return self
end

function PackageTrackerProvider:AddPackageRoot(instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	if self._packageTrackersRoots[instance] then
		return self._packageTrackersRoots[instance]
	end

	self._trackCount = self._trackCount + 1

	local maid = Maid.new()

	self._packageTrackersRoots[instance] = maid:Add(PackageTracker.new(self, instance))
	self._maid[instance] = maid

	self._packageTrackersRoots[instance]:StartTracking()

	-- TODO: Provide cleanup mechanism

	return self._packageTrackersRoots[instance]
end

function PackageTrackerProvider:FindPackageTracker(instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	local current = instance
	while current do
		if self._packageTrackersRoots[current] then
			return self._packageTrackersRoots[current]
		end

		current = current.Parent
	end

	return nil
end

function PackageTrackerProvider:Destroy()
	self._maid:DoCleaning()
end

return PackageTrackerProvider
