--!strict
--[=[
	Registers the shared cmdr enum types used by the game product commands. These must be
	registered on both the server (so commands validate and parse) and the client (so cmdr can
	autocomplete them), mirroring how [GameConfigCmdrUtils] registers the asset id types.

	@class GameProductCmdrTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")

local GameProductCmdrTypeUtils = {}

--[=[
	The name of the ownable-asset-type enum cmdr type.
	@prop OwnableAssetTypeName "ownableAssetType"
	@within GameProductCmdrTypeUtils
]=]
GameProductCmdrTypeUtils.OwnableAssetTypeName = "ownableAssetType"

--[=[
	The name of the ownership-state enum cmdr type.
	@prop OwnershipStateName "ownershipState"
	@within GameProductCmdrTypeUtils
]=]
GameProductCmdrTypeUtils.OwnershipStateName = "ownershipState"

--[=[
	The name of the ownable-asset id/key cmdr type. Autocompletes asset keys across all ownable
	asset types (a union -- it is not filtered by the command's chosen AssetType, since cmdr
	types cannot read sibling arguments) and also accepts raw numeric ids.
	@prop OwnableAssetIdOrKeyName "ownableAssetIdOrKey"
	@within GameProductCmdrTypeUtils
]=]
GameProductCmdrTypeUtils.OwnableAssetIdOrKeyName = "ownableAssetIdOrKey"

-- Asset types that have an ownership tracker (see PlayerProductManagerBase), and so can have
-- their ownership overridden.
local OWNABLE_ASSET_TYPES: { GameConfigAssetTypes.GameConfigAssetType } = {
	GameConfigAssetTypes.GAME,
	GameConfigAssetTypes.PASS,
	GameConfigAssetTypes.ASSET,
	GameConfigAssetTypes.BUNDLE,
	GameConfigAssetTypes.SUBSCRIPTION,
	GameConfigAssetTypes.MEMBERSHIP,
}

--[=[
	Ownership override states accepted by the `set-ownership` command.
	@prop OwnershipStates { "own", "disown", "clear" }
	@within GameProductCmdrTypeUtils
]=]
GameProductCmdrTypeUtils.OwnershipStates = { "own", "disown", "clear" }

-- Builds the ownable-asset id/key type. Autocompletes keys across every ownable asset type
-- (a union) and accepts raw numbers. Parse returns the raw key string or number; the command
-- resolves it against its chosen AssetType via the config picker.
local function makeOwnableAssetIdOrKeyType(cmdr: any, configPicker: any)
	--stylua: ignore
	return {
		Transform = function(text)
			local keys = {}
			local seen = {}

			for _, assetType in OWNABLE_ASSET_TYPES do
				for _, assetConfig in configPicker:GetAllActiveAssetsOfType(assetType) do
					local key = assetConfig:GetAssetKey()
					if not seen[key] then
						seen[key] = true
						table.insert(keys, key)
					end
				end
			end

			local find = cmdr.Util.MakeFuzzyFinder(keys)
			local found = find(text)

			-- Allow raw numeric ids too
			if tonumber(text) then
				table.insert(found, tonumber(text))
			end

			return found
		end;
		Validate = function(found)
			return #found > 0, "No ownable asset with that key or id could be found."
		end;
		Autocomplete = function(found)
			local strings = {}
			for _, item in found do
				table.insert(strings, tostring(item))
			end
			return strings
		end;
		Parse = function(found)
			return found[1]
		end;
	}
end

--[=[
	Registers the game product cmdr types. Safe to call once per cmdr registry (server and each
	client). Registering a duplicate type name throws, so this should only be called from a
	single service on each realm.

	@param cmdr Cmdr
	@param configPicker GameConfigPicker
]=]
function GameProductCmdrTypeUtils.registerTypes(cmdr: any, configPicker: any): ()
	assert(cmdr, "Bad cmdr")
	assert(configPicker, "Bad configPicker")

	cmdr.Registry:RegisterType(
		GameProductCmdrTypeUtils.OwnableAssetTypeName,
		cmdr.Util.MakeEnumType(GameProductCmdrTypeUtils.OwnableAssetTypeName, OWNABLE_ASSET_TYPES)
	)

	cmdr.Registry:RegisterType(
		GameProductCmdrTypeUtils.OwnershipStateName,
		cmdr.Util.MakeEnumType(GameProductCmdrTypeUtils.OwnershipStateName, GameProductCmdrTypeUtils.OwnershipStates)
	)

	cmdr.Registry:RegisterType(
		GameProductCmdrTypeUtils.OwnableAssetIdOrKeyName,
		makeOwnableAssetIdOrKeyType(cmdr, configPicker)
	)
end

return GameProductCmdrTypeUtils
