--[=[
	@class GameConfigDataService
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigDataService = {}
GameConfigDataService.ServiceName = "GameConfigDataService"

function GameConfigDataService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")


end

function GameConfigDataService:SetConfigPicker(configPicker)
	self._configPicker = configPicker
end

function GameConfigDataService:GetConfigPicker()
	return self._configPicker
end

return GameConfigDataService