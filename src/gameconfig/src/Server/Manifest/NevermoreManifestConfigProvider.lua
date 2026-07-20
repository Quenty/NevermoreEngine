--!strict
--[=[
	Registers the deploy target's places -- read from the nevermore CLI manifest
	baked into the running place -- as PLACE assets in [GameConfigService], each
	at a high priority so it wins over a hand-authored place sharing the same key
	(see [GameConfigPicker.FindFirstActiveAssetOfKey]).

	Add it to a server [ServiceBag] after [GameConfigService]:

	```lua
	serviceBag:GetService(require("GameConfigService"))
	serviceBag:GetService(require("NevermoreManifestConfigProvider"))
	```

	In Studio or an undeployed build the manifest place table is empty, so nothing
	is registered and hand-authored config resolves exactly as before.

	@server
	@class NevermoreManifestConfigProvider
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigService = require("GameConfigService")
local Maid = require("Maid")
local NevermoreCLIManifestUtils = require("NevermoreCLIManifestUtils")
local ServiceBag = require("ServiceBag")

-- Well above the default priority (0) so a manifest place always beats a
-- hand-authored one that shares its key.
local MANIFEST_PLACE_PRIORITY = 1000

local NevermoreManifestConfigProvider = {}
NevermoreManifestConfigProvider.ServiceName = "NevermoreManifestConfigProvider"

export type NevermoreManifestConfigProvider = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_gameConfigService: GameConfigService.GameConfigService,
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = NevermoreManifestConfigProvider })
))

function NevermoreManifestConfigProvider.Init(self: NevermoreManifestConfigProvider, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._gameConfigService = self._serviceBag:GetService(GameConfigService :: any)
end

function NevermoreManifestConfigProvider.Start(self: NevermoreManifestConfigProvider)
	self:_applyPlaces(NevermoreCLIManifestUtils.getPlaces())
end

--[=[
	Registers each named place as a high-priority PLACE asset. Nameless entries
	(single-place targets) are skipped -- there is no config key to bind them to.

	@param places { NevermoreCLIManifestUtils.ManifestPlace }
	@private
]=]
function NevermoreManifestConfigProvider._applyPlaces(
	self: NevermoreManifestConfigProvider,
	places: { NevermoreCLIManifestUtils.ManifestPlace }
)
	for _, place in places do
		if place.name then
			local asset = self._gameConfigService:AddPlace(place.name, place.placeId, MANIFEST_PLACE_PRIORITY)
			self._maid:GiveTask(asset)
		end
	end
end

function NevermoreManifestConfigProvider.Destroy(self: NevermoreManifestConfigProvider)
	self._maid:DoCleaning()
end

return NevermoreManifestConfigProvider
