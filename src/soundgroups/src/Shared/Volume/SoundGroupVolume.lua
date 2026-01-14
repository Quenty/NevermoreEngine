--!strict
local SoundGroupVolumeInterface = require(script.Parent.SoundGroupVolumeInterface)
--[=[
	@class SoundGroupVolume
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local ServiceBag = require("ServiceBag")
local SoundGroupVolumeProperties = require("SoundGroupVolumeProperties")
local TieRealms = require("TieRealms")

local SoundGroupVolume = setmetatable({}, BaseObject)
SoundGroupVolume.ClassName = "SoundGroupVolume"
SoundGroupVolume.__index = SoundGroupVolume

export type SoundGroupVolume =
	typeof(setmetatable(
		{} :: {
			_obj: SoundGroup,
			_serviceBag: ServiceBag.ServiceBag,
			_tieRealmService: any,
			_properties: any,
			RenderedVolume: any,
		},
		{} :: typeof({ __index = SoundGroupVolume })
	))
	& BaseObject.BaseObject

function SoundGroupVolume.new(instance: SoundGroup, serviceBag: ServiceBag.ServiceBag): SoundGroupVolume
	local self: SoundGroupVolume = setmetatable(BaseObject.new(instance) :: any, SoundGroupVolume)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(require("TieRealmService"))

	self._properties = SoundGroupVolumeProperties:Get(self._serviceBag, self._obj)
	self.RenderedVolume = self._properties.Volume

	self._maid:GiveTask(SoundGroupVolumeInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	-- Assign our volume to the current volume if we're on the server
	if self._tieRealmService:GetTieRealm() == TieRealms.SERVER then
		self._properties.Volume:SetBaseValue(self._obj.Volume)
	end

	self._maid:GiveTask(self._properties.Volume:Observe():Subscribe(function(volume)
		self._obj.Volume = volume
	end))

	return self
end

--[=[
	Creates a volume multiplier for this sound group volume.

	@param amount number?
	@return NumberValue
]=]
function SoundGroupVolume.CreateMultiplier(self: SoundGroupVolume, amount: number?): NumberValue
	return self._properties.Volume:CreateMultiplier(amount or 1)
end

return Binder.new("SoundGroupVolume", SoundGroupVolume :: any) :: Binder.Binder<SoundGroupVolume>
