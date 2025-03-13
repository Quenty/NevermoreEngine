--[=[
	@class GameConfigCmdrUtils
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")

local GameConfigCmdrUtils = {}

function GameConfigCmdrUtils.registerAssetTypes(cmdr, configPicker)
	assert(cmdr, "Bad cmdr")
	assert(configPicker, "Bad configPicker")

	for _, assetType in GameConfigAssetTypes do
		GameConfigCmdrUtils.registerAssetType(cmdr, configPicker, assetType)
	end
end

function GameConfigCmdrUtils.registerAssetType(cmdr, configPicker, assetType: GameConfigAssetTypes.GameConfigAssetType)
	assert(cmdr, "Bad cmdr")
	assert(type(assetType) == "string", "Bad assetType")
	assert(configPicker, "Bad configPicker")

	--stylua: ignore
	local assetIdDefinition = {
		Transform = function(text)
			local allAssets = configPicker:GetAllActiveAssetsOfType(assetType)
			local assetKeys = {}

			-- TODO: Translate too?
			for _, assetConfig in allAssets do
				table.insert(assetKeys, assetConfig:GetAssetKey())
			end

			local find = cmdr.Util.MakeFuzzyFinder(assetKeys)
			local found = find(text)

			-- Allow numbers here too
			if tonumber(text) then
				table.insert(found, tonumber(text))
			end

			return found
		end;
		Validate = function(keys)
			return #keys > 0, string.format("No %s with that name could be found.", assetType)
		end,
		Autocomplete = function(keys)
			local stringified = {}
			for _, item in keys do
				table.insert(stringified, tostring(item))
			end
			return stringified
		end,
		Parse = function(keys)
			local value = keys[1]
			if type(value) == "number" then
				return value
			end

			local asset = configPicker:FindFirstActiveAssetOfKey(assetType, value)
			if asset then
				return asset:GetAssetId()
			end

			return nil
		end;
	}

	cmdr.Registry:RegisterType(assetType .. "Id", assetIdDefinition)
	cmdr.Registry:RegisterType(assetType .. "Ids", cmdr.Util.MakeListableType(assetIdDefinition))
end

return GameConfigCmdrUtils