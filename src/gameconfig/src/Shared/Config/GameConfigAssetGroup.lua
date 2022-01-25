--[=[
	@class GameConfigAssetGroup
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetDataUtils  = require("GameConfigAssetDataUtils")

local GameConfigAssetGroup = {}
GameConfigAssetGroup.ClassName = "GameConfigAssetGroup"
GameConfigAssetGroup.__index = GameConfigAssetGroup

--[=[
	Constructs a new GameConfigAssetGroup
	@param gameConfigAssetType GameConfigAssetType
	@return GameConfigAssetGroup
]=]
function GameConfigAssetGroup.new(gameConfigAssetType)
	local self = setmetatable({}, GameConfigAssetGroup)

	self._assetType = assert(gameConfigAssetType, "No gameConfigAssetType")
	self._nameMap = {}
	self._idMap = {}
	self._dataList = {}

	return self
end

--[=[
	Deserializes the asset group
	@param data any
	@return GameConfigAssetGroup
]=]
function GameConfigAssetGroup.deserialize(assetGroupData)
	assert(type(assetGroupData) == "table", "Bad assetGroupData")
	assert(type(assetGroupData.assetType) == "string", "Bad assetGroupData.assetType")
	assert(type(assetGroupData.entries) == "table", "Bad assetGroupData.entries")

	local group = GameConfigAssetGroup.new(assetGroupData.assetType)

	for _, assetData in pairs(assetGroupData.entries) do
		group:AddAssetData(assetData)
	end

	return group
end

--[=[
	Serializes the asset group
	@param assetGroup GameConfigAssetGroup
	@return any
]=]
function GameConfigAssetGroup.serialize(assetGroup)
	local assetGroupData = {}
	assetGroupData.assetType = assetGroup:GetAssetType()
	assetGroupData.entries = {}

	for _, item in pairs(assetGroup:GetDataList()) do
		table.insert(assetGroupData.entries, item)
	end

	return assetGroupData
end

--[=[
	Retrieves the asset type
	@return GameConfigAssetType
]=]
function GameConfigAssetGroup:GetAssetType()
	return self._assetType
end

--[=[
	Adds the asset data to the group
	@param assetData GameConfigAssetData
]=]
function GameConfigAssetGroup:AddAssetData(assetData)
	assert(GameConfigAssetDataUtils.isAssetData(assetData), "Bad assetData")

	if self._nameMap[assetData.assetName] then
		warn("Duplicate assetData, removing")
		return
	end

	self._nameMap[assetData.assetName] = assetData
	self._idMap[assetData.assetId] = assetData
	table.insert(self._dataList, assetData)
end

--[=[
	Returns asset data
	@param assetName string
	@return GameConfigAssetData
]=]
function GameConfigAssetGroup:GetDataByName(assetName)
	assert(type(assetName) == "string", "Bad assetName")

	return self._nameMap[assetName]
end

--[=[
	Returns assetData
	@param assetId number
	@return GameConfigAssetData
]=]
function GameConfigAssetGroup:GetDataById(assetId)
	assert(type(assetId) == "number", "Bad assetId")

	return self._idMap[assetId]
end

--[=[
	Retrieves a list of data
	@return { GameConfigAssetData }
]=]
function GameConfigAssetGroup:GetDataList()
	return self._dataList
end

return GameConfigAssetGroup