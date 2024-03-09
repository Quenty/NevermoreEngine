--[=[
	Allows us to independently apply sound effects to both sound groups and to
	individual sounds.

	@class SoundEffectsRegistry
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local ObservableMap = require("ObservableMap")
local SoundEffectsList = require("SoundEffectsList")
local SoundGroupPathUtils = require("SoundGroupPathUtils")
local ObservableSet = require("ObservableSet")

local SoundEffectsRegistry = setmetatable({}, BaseObject)
SoundEffectsRegistry.ClassName = "SoundEffectsRegistry"
SoundEffectsRegistry.__index = SoundEffectsRegistry

function SoundEffectsRegistry.new()
	local self = setmetatable(BaseObject.new(), SoundEffectsRegistry)

	self._pathToEffectList = self._maid:Add(ObservableMap.new())
	self._activeEffectsPathSet = self._maid:Add(ObservableSet.new())

	return self
end

function SoundEffectsRegistry:PushEffect(soundGroupPath, effect)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")
	assert(type(effect) == "function", "Bad effect")

	local effectsList = self:_getOrCreateEffectList(soundGroupPath)
	return effectsList:PushEffect(effect)
end

function SoundEffectsRegistry:ApplyEffects(soundGroupPath, instance)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")
	assert(typeof(instance) == "Instance" and (instance:IsA("SoundGroup") or instance:IsA("Sound")), "Bad instance")

	local effectsList = self:_getOrCreateEffectList(soundGroupPath)
	return effectsList:ApplyEffects(instance)
end

function SoundEffectsRegistry:ObserveActiveEffectsPathBrios()
	return self._activeEffectsPathSet:ObserveItemsBrio()
end

function SoundEffectsRegistry:_getOrCreateEffectList(soundGroupPath)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")

	local found = self._pathToEffectList:Get(soundGroupPath)
	if found then
		return found
	end

	local maid = Maid.new()

	local soundEffectsList = maid:Add(SoundEffectsList.new())

	maid:GiveTask(soundEffectsList.IsActiveChanged:Connect(function()
		if not soundEffectsList:IsActive() then
			self._maid[soundEffectsList] = nil
		end
	end))
	maid:GiveTask(soundEffectsList:ObserveHasEffects():Subscribe(function(hasEffects)
		if hasEffects then
			maid._current = self._activeEffectsPathSet:Add(soundGroupPath)
		else
			maid._current = nil
		end
	end))

	self._maid[soundEffectsList] = maid

	maid:Add(self._pathToEffectList:Set(soundGroupPath, soundEffectsList))

	return soundEffectsList
end

return SoundEffectsRegistry