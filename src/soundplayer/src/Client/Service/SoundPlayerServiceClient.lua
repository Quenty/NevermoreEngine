--!strict
--[=[
    @class SoundPlayerServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local LayeredSoundHelper = require("LayeredSoundHelper")
local LoopedSoundPlayer = require("LoopedSoundPlayer")
local Maid = require("Maid")
local Observable = require("Observable")
local ServiceBag = require("ServiceBag")
local SoundPlayerStack = require("SoundPlayerStack")

local SoundPlayerServiceClient = {}
SoundPlayerServiceClient.ServiceName = "SoundPlayerServiceClient"

export type SoundPlayerServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_soundGroupService: any,
		_soundPlayerHelper: LayeredSoundHelper.LayeredSoundHelper<SoundPlayerStack.SoundPlayerStack>,
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = SoundPlayerServiceClient })
))

function SoundPlayerServiceClient.Init(self: SoundPlayerServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("SoundGroupServiceClient"))

	self._soundPlayerHelper = self._maid:Add(LayeredSoundHelper.new(function(maid)
		local layer: SoundPlayerStack.SoundPlayerStack = maid:Add(SoundPlayerStack.new())

		return layer
	end))
end

--[=[
    Gets a sound group player for the given sound group path

    @param layerId string
    @return SoundPlayerStack
]=]
function SoundPlayerServiceClient.GetOrCreateSoundPlayerStack(
	self: SoundPlayerServiceClient,
	layerId: string
): SoundPlayerStack.SoundPlayerStack
	return self._soundPlayerHelper:GetOrCreateLayer(layerId)
end

function SoundPlayerServiceClient.PushSoundPlayer(
	self: SoundPlayerServiceClient,
	layerId: string,
	soundPlayer: LoopedSoundPlayer.LoopedSoundPlayer,
	priority: (number | Observable.Observable<number>)?
): () -> ()
	local layer = self._soundPlayerHelper:GetOrCreateLayer(layerId)
	return layer:PushSoundPlayer(soundPlayer, priority)
end

function SoundPlayerServiceClient.Destroy(self: SoundPlayerServiceClient): ()
	self._maid:DoCleaning()
	self._soundPlayerHelper = nil :: any
end

return SoundPlayerServiceClient
