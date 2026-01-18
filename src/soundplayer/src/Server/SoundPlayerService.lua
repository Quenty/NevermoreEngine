--!strict
--[=[
    @class SoundPlayerService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local SoundPlayerService = {}
SoundPlayerService.ServiceName = "SoundPlayerService"

export type SoundPlayerService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = SoundPlayerService })
))

function SoundPlayerService.Init(self: SoundPlayerService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._serviceBag:GetService(require("SoundGroupService"))
end

return SoundPlayerService
