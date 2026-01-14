--!strict
--[=[
	Handles applying global volume and effects to specific sounds in a group based upon a path.

	@class SoundEffectService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local SoundEffectsList = require("SoundEffectsList")
local SoundEffectsRegistry = require("SoundEffectsRegistry")
local SoundGroupPathUtils = require("SoundGroupPathUtils")
local SoundGroupTracker = require("SoundGroupTracker")
local SoundGroupVolume = require("SoundGroupVolume")
local WellKnownSoundGroups = require("WellKnownSoundGroups")

local SoundEffectService = {}
SoundEffectService.ServiceName = "SoundEffectService"

export type SoundEffectService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_soundEffectsRegister: any, -- SoundEffectsRegistry.SoundEffectsRegistry,
		_tracker: any, -- SoundGroupTracker.SoundGroupTracker,
	},
	{} :: typeof({ __index = SoundEffectService })
))

function SoundEffectService.Init(self: SoundEffectService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("TieRealmService"))
	self._serviceBag:GetService(require("RoguePropertyService"))

	-- State
	self._soundEffectsRegister = self._maid:Add(SoundEffectsRegistry.new())
	self._tracker = self._maid:Add(SoundGroupTracker.new(SoundService))

	-- Binders
	self._serviceBag:GetService(require("SoundGroupVolume"))
end

function SoundEffectService.Start(self: SoundEffectService): ()
	self:_setupEffectApplication()
end

--[=[
	Assigns the sound group for the given
	@param sound Sound
	@param soundGroupPath string? -- Optional
]=]
function SoundEffectService.RegisterSFX(self: SoundEffectService, sound: Sound, soundGroupPath: string): ()
	assert(typeof(sound) == "Instance" and sound:IsA("Sound"), "Bad sound")
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath) or soundGroupPath == nil, "Bad soundGroupPath")

	sound.SoundGroup = self:GetOrCreateSoundGroup(soundGroupPath or WellKnownSoundGroups.SFX)
end

--[=[
	Creates a NumberValue multiplier for the given sound group path.

	Destroy (or unparent) the returned NumberValue to remove the multiplier.

	@param soundGroupPath string
	@return Promise<NumberValue>
]=]
function SoundEffectService:PromiseCreateVolumeMultiplier(soundGroupPath: string): Promise.Promise<NumberValue>
	local soundGroup = self:GetOrCreateSoundGroup(soundGroupPath)
	if soundGroup == nil then
		return Promise.rejected("Failed to get or create sound group for path: " .. soundGroupPath)
	end

	local soundGroupVolumeBinder = self._serviceBag:GetService(require("SoundGroupVolume"))
	soundGroupVolumeBinder:Tag(soundGroup)

	return soundGroupVolumeBinder:Promise(soundGroup):Then(function(soundGroupVolume)
		return soundGroupVolume:CreateMultiplier()
	end)
end

--[=[
	Returns the SoundGroup for the given path, creating it if it does not exist.

	@param soundGroupPath string
	@return SoundGroup
]=]
function SoundEffectService.GetOrCreateSoundGroup(self: SoundEffectService, soundGroupPath: string): SoundGroup
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")

	local found = self:GetSoundGroup(soundGroupPath)
	if found then
		return found
	end

	-- Handle deferred mode
	found = SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath)
	assert(found, "Failed to create sound group for path")

	SoundGroupVolume:Tag(found)

	return found
end

--[=[
	Returns the SoundGroup for the given path, or nil if it does not exist.

	@param soundGroupPath string
	@return SoundGroup
]=]
function SoundEffectService.GetSoundGroup(self: SoundEffectService, soundGroupPath: string): SoundGroup?
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
		SoundGroupVolume:Tag(found)
		return found
	end

	found = SoundGroupPathUtils.findSoundGroup(soundGroupPath)
	if found then
		SoundGroupVolume:Tag(found)
	end

	return found
end

function SoundEffectService.PushEffect(
	self: SoundEffectService,
	soundGroupPath: string,
	effect: SoundEffectsList.SoundEffectApplier
): ()
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")
	assert(type(effect) == "function", "Bad effect")

	return self._soundEffectsRegister:PushEffect(soundGroupPath, effect)
end

function SoundEffectService.ApplyEffects(
	self: SoundEffectService,
	soundGroupPath: string,
	instance: SoundGroup | Sound
): () -> ()
	assert(SoundGroupPathUtils.isSoundGroupPath(soundGroupPath), "Bad soundGroupPath")
	assert(typeof(instance) == "Instance" and (instance:IsA("SoundGroup") or instance:IsA("Sound")), "Bad instance")

	return self._soundEffectsRegister:ApplyEffects(soundGroupPath, instance)
end

function SoundEffectService._setupEffectApplication(self: SoundEffectService): ()
	self._maid:GiveTask(self._tracker:ObserveSoundGroupsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, soundGroup = brio:ToMaidAndValue()
		maid:GiveTask(self._tracker:ObserveSoundGroupPath(soundGroup):Subscribe(function(soundGroupPath)
			if soundGroupPath then
				maid._currentEffects = self._soundEffectsRegister:ApplyEffects(soundGroupPath, soundGroup)
			else
				maid._currentEffects = nil :: any
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

function SoundEffectService.Destroy(self: SoundEffectService): ()
	self._maid:DoCleaning()
end

return SoundEffectService
