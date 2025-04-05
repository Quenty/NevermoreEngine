--[=[
	@class SpawnCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local SpawnCmdrService = {}
SpawnCmdrService.ServiceName = "SpawnCmdrService"

function SpawnCmdrService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._spawnService = self._serviceBag:GetService((require :: any)("SpawnService"))
	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))

	self._cmdrService:RegisterCommand({
		Name = "regen";
		Aliases = {};
		Description = "Forces all spawners to regenerate.";
		Group = "Spawn";
		Args = {};
	}, function(_context)
		self._spawnService:Regenerate()

		return "Regenerated every spawner in the game."
	end)
end

return SpawnCmdrService