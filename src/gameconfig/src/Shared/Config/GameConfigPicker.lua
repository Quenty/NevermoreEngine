--[=[
	@class GameConfigPicker
]=]

local require = require(script.Parent.loader).load(script)

local GameConfig = require("GameConfig")

local GameConfigPicker = {}
GameConfigPicker.ClassName = "GameConfigPicker"
GameConfigPicker.__index = GameConfigPicker

--[=[
	Constructs a new GameConfigPicker
	@return GameConfigPicker
]=]
function GameConfigPicker.new()
	local self = setmetatable({}, GameConfigPicker)

	self._configs = {} -- [experienceId] = MantleConfig
	self._configList = {}
	self._gameCurrentConfig = nil

	return self
end

--[=[
	Deserializes the game config picker
	@param gameConfigPickerData any
	@return GameConfigPicker
]=]
function GameConfigPicker.deserialize(gameConfigPickerData)
	local picker = GameConfigPicker.new()

	for _, gameConfigData in pairs(gameConfigPickerData) do
		picker:AddConfig(GameConfig.deserialize(gameConfigData))
	end

	return picker
end

--[=[
	Serializes the game config
	@param gameConfigPicker GameConfigPicker
	@return any
]=]
function GameConfigPicker.serialize(gameConfigPicker)
	local gameConfigPickerData = {}

	for _, gameConfig in pairs(gameConfigPicker:GetConfigList()) do
		table.insert(gameConfigPickerData, GameConfig.serialize(gameConfig))
	end

	return gameConfigPickerData
end

function GameConfigPicker:PickConfig()
	local current = self:_getCurrentGameConfig()
	if current then
		return current
	end

	return nil
end

--[=[
	Adds a new game config to the picker
	@param config GameConfig
]=]
function GameConfigPicker:AddConfig(config)
	assert(config, "Bad config")

	local experienceId = config:GetExperienceId()
	if self._configs[experienceId] then
		error(("Already have a configuration for gameId %d"):format(experienceId))
	end

	if experienceId == game.GameId then
		self._gameCurrentConfig = config
	end

	-- Ordered for priority, I guess
	table.insert(self._configList, config)
	self._configs[experienceId] = config
end

function GameConfigPicker:_getCurrentGameConfig()
	return self._gameCurrentConfig
end

--[=[
	Returns a list of all configurations
	@return { GameConfig }
]=]
function GameConfigPicker:GetConfigList()
	return self._configList
end

--[=[
	Gets asset data for the current place for the given assetType. If an id is given,
	it will look up the equivalent id and retrieve the correct asset for this place.
	@param assetType MantleAssetType
	@param assetNameOrId string | number
	@return MantleAssetData?
]=]
function GameConfigPicker:FindPlaceAssetDataByNameOrId(assetType, assetNameOrId)
	assert(type(assetType) == "string", "Bad assetType")

	if type(assetNameOrId) == "string" then
		return self:GetAssetDataByName(assetType, assetNameOrId)
	elseif type(assetNameOrId) == "number" then
		local bestAsset = self:_getAssetDataById(assetType, assetNameOrId)
		if not bestAsset then
			return nil
		end

		-- Translate back to the correct asset for this place
		return self:GetAssetDataByName(assetType, bestAsset.name)
	else
		error("Bad assetNameOrId type")
	end
end

function GameConfigPicker:GetAllAssetDataByNameOrId(assetType, assetNameOrId)
	assert(type(assetType) == "string", "Bad assetType")

	if type(assetNameOrId) == "string" then
		-- Get all matching the same name
		local assetDataList = {}
		for _, config in pairs(self._configList) do
			local data = config:GetAssetDataByName(assetType, assetNameOrId)
			if data then
				table.insert(assetDataList, data)
			end
		end
		return assetDataList
	elseif type(assetNameOrId) == "number" then
		local first = self:_getAssetDataById(assetNameOrId)
		if not first then
			return {}
		end

		-- Get all matching the same name
		local assetDataList = {}
		for _, config in pairs(self._configList) do
			local data = config:GetAssetDataByName(assetType, first.name)
			if data then
				table.insert(assetDataList, data)
			end
		end
		return assetDataList
	else
		error("Bad assetNameOrId type")
	end
end

--[=[
	@param assetType MantleAssetType
	@param assetId number
	@return MantleAssetData?
]=]
function GameConfigPicker:_getAssetDataById(assetType, assetId)
	assert(type(assetType) == "string", "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	-- Try game config
	local gameConfig = self:_getCurrentGameConfig()
	if gameConfig then
		local result = gameConfig:GetAssetDataById(assetType, assetId)
		if result then
			return result
		end
	end

	-- Fallback to list
	for _, config in pairs(self._configList) do
		local result = config:GetAssetDataById(assetType, assetId)
		if result then
			return result
		end
	end

	return nil
end

--[=[
	@param assetType MantleAssetType
	@param assetName string
	@return MantleAssetData?
]=]
function GameConfigPicker:GetAssetDataByName(assetType, assetName)
	assert(type(assetType) == "string", "Bad assetType")
	assert(type(assetName) == "number", "Bad assetName")

	-- Try game config
	local gameConfig = self:_getCurrentGameConfig()
	if gameConfig then
		local result = gameConfig:GetAssetDataByName(assetType, assetName)
		if result then
			return result
		end
	end

	-- Fallback to list
	for _, config in pairs(self._configList) do
		local result = config:GetAssetDataByName(assetType, assetName)
		if result then
			return result
		end
	end

	return nil
end

return GameConfigPicker