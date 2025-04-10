--!strict
--[=[
	@class SoundGroupTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxInstanceUtils = require("RxInstanceUtils")
local ObservableMapList = require("ObservableMapList")
local Maid = require("Maid")
local ObservableMap = require("ObservableMap")
local SoundGroupPathUtils = require("SoundGroupPathUtils")
local Rx = require("Rx")
local Observable = require("Observable")

local SoundGroupTracker = setmetatable({}, BaseObject)
SoundGroupTracker.ClassName = "SoundGroupTracker"
SoundGroupTracker.__index = SoundGroupTracker

export type SoundGroupTracker = typeof(setmetatable(
	{} :: {
		_pathToSoundGroupList: ObservableMapList.ObservableMapList<string, SoundGroup>,
		_soundGroupToPath: ObservableMap.ObservableMap<SoundGroup, string>,
	},
	{} :: typeof({ __index = SoundGroupTracker })
)) & BaseObject.BaseObject

function SoundGroupTracker.new(root): SoundGroupTracker
	local self: SoundGroupTracker = setmetatable(BaseObject.new() :: any, SoundGroupTracker)

	-- Handle edge case of multiple sound groups with the same name...
	self._pathToSoundGroupList = self._maid:Add(ObservableMapList.new())
	self._soundGroupToPath = self._maid:Add(ObservableMap.new())

	if root then
		self:Track(root)
	end

	return self
end

function SoundGroupTracker.GetFirstSoundGroup(self: SoundGroupTracker, soundGroupPath)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")

	return self._pathToSoundGroupList:GetAtListIndex(soundGroupPath, 1)
end

function SoundGroupTracker.ObserveSoundGroup(self: SoundGroupTracker, soundGroupPath)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")

	return self._pathToSoundGroupList:ObserveAtListIndex(soundGroupPath, 1)
end

function SoundGroupTracker.ObserveSoundGroupBrio(self: SoundGroupTracker, soundGroupPath)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")

	return self._pathToSoundGroupList:ObserveAtListIndexBrio(soundGroupPath, 1)
end

function SoundGroupTracker.ObserveSoundGroupsBrio(self: SoundGroupTracker)
	return self._soundGroupToPath:ObserveKeysBrio()
end

function SoundGroupTracker.Track(self: SoundGroupTracker, parent)
	return self:_track(nil, parent)
end

function SoundGroupTracker.ObserveSoundGroupPath(self: SoundGroupTracker, soundGroup)
	assert(typeof(soundGroup) == "Instance" and soundGroup:IsA("SoundGroup"), "Bad soundGroup")

	return self._soundGroupToPath:ObserveAtKey(soundGroup)
end

function SoundGroupTracker._track(self: SoundGroupTracker, observeRootPath, parent)
	assert(Observable.isObservable(observeRootPath) or observeRootPath == nil, "Bad observeRootPath")
	assert(typeof(parent) == "Instance", "Bad parent")

	local topMaid = Maid.new()

	topMaid:GiveTask(RxInstanceUtils.observeChildrenOfClassBrio(parent, "SoundGroup"):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, soundGroup = brio:ToMaidAndValue()

		-- stylua: ignore
		local observePath = Rx.combineLatest({
			rootPath = observeRootPath or nil;
			name = RxInstanceUtils.observeProperty(soundGroup, "Name");
		}):Pipe({
			Rx.map(function(state)
				if state.rootPath then
					-- TODO: Handle name having period in it...
					return string.format("%s.%s", state.rootPath, state.name)
				else
					return state.name
				end
			end) :: any
		})

		maid:Add(observePath:Subscribe(function(path)
			maid._currentPath = self._soundGroupToPath:Set(soundGroup :: SoundGroup, path)
		end))
		maid:Add(self._pathToSoundGroupList:Push(observePath, soundGroup))

		-- Track all nested descendants
		maid:Add(self:_track(observePath, soundGroup))
	end))

	topMaid:GiveTask(parent.Destroying:Connect(function()
		self._maid[topMaid] = nil
	end))
	topMaid:GiveTask(function()
		self._maid[topMaid] = nil
	end)

	self._maid[topMaid] = topMaid

	return function()
		self._maid[topMaid] = nil
	end
end

return SoundGroupTracker