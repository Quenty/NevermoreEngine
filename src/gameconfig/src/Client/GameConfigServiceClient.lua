--[=[
	@class GameConfigServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local GameConfigPicker = require("GameConfigPicker")

local GameConfigServiceClient = {}
GameConfigServiceClient.ServiceName = "GameConfigServiceClient"

function GameConfigServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))

	-- Internal
	self._serviceBag:GetService(require("GameConfigCommandServiceClient"))
	self._serviceBag:GetService(require("GameConfigTranslator"))
	self._serviceBag:GetService(require("GameConfigDataService"))
	self._binders = self._serviceBag:GetService(require("GameConfigBindersClient"))

	self._configPicker = self._maid:Add(GameConfigPicker.new(self._serviceBag, self._binders.GameConfig, self._binders.GameConfigAsset))

	self._serviceBag:GetService(require("GameConfigDataService")):SetConfigPicker(self._configPicker)
end

function GameConfigServiceClient:Start()

end

--[=[
	Retrieves the game configuration picker for the config service.
	@return GameConfigPicker
]=]
function GameConfigServiceClient:GetConfigPicker()
	return self._configPicker
end

function GameConfigServiceClient:Destroy()
	self._maid:DoCleaning()
end

return GameConfigServiceClient