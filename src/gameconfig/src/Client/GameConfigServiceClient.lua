--[=[
	@class GameConfigServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local BadgeUtils = require("BadgeUtils")
local GameConfig = require("GameConfig")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigPicker = require("GameConfigPicker")
local GameConfigServiceConstants = require("GameConfigServiceConstants")
local GameConfigTranslator = require("GameConfigTranslator")
local Maid = require("Maid")
local MarketplaceUtils = require("MarketplaceUtils")
local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local PromiseUtils = require("PromiseUtils")
local RemoteFunctionUtils = require("RemoteFunctionUtils")

local GameConfigServiceClient = {}

function GameConfigServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Internal
	self._configTranslator = self._serviceBag:GetService(GameConfigTranslator)

	self:_promiseTranslatedData():Then(function(translationData)
		for key, value in pairs(translationData) do
			print(key, value)
		end
	end)

	self:_promiseRemoteEvent():Then(function(remoteEvent)
		self._maid:GiveTask(remoteEvent.OnClientEvent:Connect(function(...)
			self:_handleRemoteEvent(...)
		end))
	end)

end

function GameConfigServiceClient:_promiseTranslatedData()
	return self:_promiseConfigPicker()
		:Then(function(configPicker)
			local config = configPicker:PickConfig()
			if not config then
				return
			end

			local translationData = {}
			local promises = {}

			for _, data in pairs(config:GetAssetGroup(GameConfigAssetTypes.BADGE):GetDataList()) do
				table.insert(promises, self._maid:GivePromise(BadgeUtils.promiseBadgeInfo(data.assetId))
					:Then(function(badgeData)
						local nameKey = ("badges.%s.name"):format(data.assetName)
						local descriptionKey = ("badges.%s.description"):format(data.assetName)
						translationData[nameKey] = badgeData.Name
						translationData[descriptionKey] = badgeData.Description
					end))
			end

			for _, data in pairs(config:GetAssetGroup(GameConfigAssetTypes.PRODUCT):GetDataList()) do
				table.insert(promises, self._maid:GivePromise(MarketplaceUtils.promiseProductInfo(data.assetId, Enum.InfoType.Product))
					:Then(function(productInfo)
						local nameKey = ("products.%s.name"):format(data.assetName)
						local descriptionKey = ("products.%s.description"):format(data.assetName)
						translationData[nameKey] = productInfo.Name
						translationData[descriptionKey] = productInfo.Description
					end))
			end

			for _, data in pairs(config:GetAssetGroup(GameConfigAssetTypes.PASS):GetDataList()) do
				table.insert(promises, self._maid:GivePromise(MarketplaceUtils.promiseProductInfo(data.assetId, Enum.InfoType.GamePass))
					:Then(function(passInfo)
						local nameKey = ("passes.%s.name"):format(data.assetName)
						local descriptionKey = ("passes.%s.description"):format(data.assetName)
						translationData[nameKey] = passInfo.Name
						translationData[descriptionKey] = passInfo.Description
					end))
			end

			return PromiseUtils.all(promises):Then(function()
				return translationData
			end)
		end)
end

function GameConfigServiceClient:_promiseConfigPicker()
	if self._configPickerPromise then
		return self._configPickerPromise
	end

	self._configPickerPromise = self:_promiseRemoteFunction()
		:Then(function(remoteFunction)
			return RemoteFunctionUtils.promiseInvokeServer(remoteFunction, GameConfigServiceConstants.REQUEST_CONFIGURATION_DATA)
		end)
		:Then(function(gameConfigPickerData)
			return GameConfigPicker.deserialize(gameConfigPickerData)
		end)

	return self._configPickerPromise
end

function GameConfigServiceClient:_addConfig(configData)
	self:_promiseConfigPicker()
		:Then(function(configPicker)
			local gameConfig = GameConfig.deserialize(configData)

			configPicker:AddConfig(gameConfig)

			return gameConfig
		end)
end

function GameConfigServiceClient:_handleRemoteEvent(request, ...)
	if request == GameConfigServiceConstants.REQUEST_ADD_CONFIG then
		self:_addConfig(...)
	else
		error(("Bad request %q"):format(tostring(request)))
	end
end

function GameConfigServiceClient:_promiseRemoteFunction()
	return self._maid:GivePromise(PromiseGetRemoteFunction(GameConfigServiceConstants.REMOTE_FUNCTION_NAME))
end

function GameConfigServiceClient:_promiseRemoteEvent()
	return self._maid:GivePromise(PromiseGetRemoteEvent(GameConfigServiceConstants.REMOTE_EVENT_NAME))
end

return GameConfigServiceClient