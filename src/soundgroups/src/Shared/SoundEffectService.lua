--[=[
	Handles applying global volume and effects to specific sounds in a group based upon a path.

	@class SoundEffectService
]=]

local require = require(script.Parent.loader).load(script)

local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local SoundEffectsRegistry = require("SoundEffectsRegistry")
local SoundGroupPathUtils = require("SoundGroupPathUtils")
local SoundGroupTracker = require("SoundGroupTracker")
local WellKnownSoundGroups = require("WellKnownSoundGroups")
local _ServiceBag = require("ServiceBag")

local SoundEffectService = {}
SoundEffectService.ServiceName = "SoundEffectService"

function SoundEffectService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._soundEffectsRegister = self._maid:Add(SoundEffectsRegistry.new())
	self._tracker = self._maid:Add(SoundGroupTracker.new(SoundService))
end

function SoundEffectService:Start()
	self:_setupEffectApplication()
end

--[=[
	Assigns the sound group for the given
	@param sound Sound
	@param soundGroupPath string? -- Optional
]=]
function SoundEffectService:RegisterSFX(sound: Sound, soundGroupPath: string?)
	assert(typeof(sound) == "Instance" and sound:IsA("Sound"), "Bad sound")
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath) or soundGroupPath == nil, "Bad soundGroupPath")

	sound.SoundGroup = self:GetOrCreateSoundGroup(soundGroupPath or WellKnownSoundGroups.SFX)
end

function SoundEffectService:GetOrCreateSoundGroup(soundGroupPath: string): SoundGroup
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")

	local found = self:GetSoundGroup(soundGroupPath)
	if found then
		return found
	end

	-- Handle deferred mode
	return SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath)
end

function SoundEffectService:GetSoundGroup(soundGroupPath: string): SoundGroup
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")

	if not self._tracker then
		if not RunService:IsRunning() then
			warn("[SoundEffectService] - Not initialized, cache not used")
		end

		-- This means our cache isn't goign to work but this fixes stories
		return SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath)
	end

	local found = self._tracker:GetFirstSoundGroup(soundGroupPath)
	if found then
		return found
	end

	return SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath)
end

function SoundEffectService:PushEffect(soundGroupPath: string, effect)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")
	assert(type(effect) == "function", "Bad effect")

	return self._soundEffectsRegister:PushEffect(soundGroupPath, effect)
end

function SoundEffectService:ApplyEffects(soundGroupPath, instance)
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")
	assert(typeof(instance) == "Instance" and (instance:IsA("SoundGroup") or instance:IsA("Sound")), "Bad instance")

	return self._soundEffectsRegister:ApplyEffects(soundGroupPath, instance)
end

function SoundEffectService:_setupEffectApplication()
	self._maid:GiveTask(self._tracker:ObserveSoundGroupsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, soundGroup = brio:ToMaidAndValue()
		maid:GiveTask(self._tracker:ObserveSoundGroupPath(soundGroup)
			:Subscribe(function(soundGroupPath)
				if soundGroupPath then
					maid._currentEffects = self._soundEffectsRegister:ApplyEffects(soundGroupPath, soundGroup)
				else
					maid._currentEffects = nil
				end
			end))
	end))

	-- Render sound groups
	self._maid:GiveTask(self._soundEffectsRegister:ObserveActiveEffectsPathBrios():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, effectPath = brio:ToMaidAndValue()
		self:GetOrCreateSoundGroup(effectPath)

		maid:GiveTask(function()
			-- TODO: cleanup when this path isn't used? but what if something is registered there.
		end)
	end))
end


function SoundEffectService:Destroy()
	self._maid:DoCleaning()
end

return SoundEffectService