--[=[
	@class SoundGroupService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local WellKnownSoundGroups = require("WellKnownSoundGroups")
local _ServiceBag = require("ServiceBag")

local SoundGroupService = {}
SoundGroupService.ServiceName = "SoundGroupService"

function SoundGroupService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Internal
	self._soundEffectService = self._serviceBag:GetService(require("SoundEffectService"))
end

function SoundGroupService:Start()
	-- Ensure initial creation of these so server effects can work
	self._soundEffectService:GetOrCreateSoundGroup(WellKnownSoundGroups.MASTER)
	self._soundEffectService:GetOrCreateSoundGroup(WellKnownSoundGroups.SFX)
	self._soundEffectService:GetOrCreateSoundGroup(WellKnownSoundGroups.MUSIC)
	self._soundEffectService:GetOrCreateSoundGroup(WellKnownSoundGroups.VOICE)
end

function SoundGroupService:Destroy()
	self._maid:DoCleaning()
end

return SoundGroupService