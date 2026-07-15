--!strict
--[=[
	@class SpawnCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local SpawnCmdrService = {}
SpawnCmdrService.ServiceName = "SpawnCmdrService"

export type SpawnCmdrService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_spawnService: any,
		_cmdrService: any,
	},
	{} :: typeof({ __index = SpawnCmdrService })
))

function SpawnCmdrService.Init(self: SpawnCmdrService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._spawnService = self._serviceBag:GetService((require :: any)("SpawnService"))
	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))

	self._cmdrService:RegisterCommand({
		Name = "regen",
		Aliases = {},
		Description = "Forces all spawners to regenerate.",
		Group = "Spawn",
		Args = {},
	}, function(_context)
		self._spawnService:Regenerate()

		return "Regenerated every spawner in the game."
	end)
end

return SpawnCmdrService
