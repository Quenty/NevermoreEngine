--!strict
--[=[
	Helpers for the replicated ownership-override map that [PlayerAssetOwnershipTracker] maintains.

	Each ownership tracker owns one [JSONAttributeValue] on the player, named per asset type, holding
	a map of `{ [assetIdString] = ownsAsset }`. The server writes it (authoritative) and Roblox
	replicates it read-only to clients, where every realm's tracker applies it. Storing the asset id
	as the (string) map key lets non-numeric ids (subscriptions) survive the JSON round-trip.

	@class PlayerProductOwnershipOverrideUtils
]=]

local PlayerProductOwnershipOverrideUtils = {}

-- Prefix for the per-asset-type override attribute on the player. Server-owned; clients may read it
-- but never assign it, so a player can never grant themselves ownership.
PlayerProductOwnershipOverrideUtils.ATTRIBUTE_PREFIX = "GameProductOwnershipOverride"

export type OwnershipOverrideState = { [string]: boolean }

--[=[
	The attribute name that carries a given asset type's override map.

	@param assetType string
	@return string
]=]
function PlayerProductOwnershipOverrideUtils.attributeName(assetType: string): string
	assert(type(assetType) == "string", "Bad assetType")

	return string.format("%s_%s", PlayerProductOwnershipOverrideUtils.ATTRIBUTE_PREFIX, assetType)
end

--[=[
	Coerces an arbitrary decoded attribute value into a well-formed override map, dropping any
	malformed entries. Returns a fresh mutable table (so callers may edit it), and treats nil (no
	attribute yet) as an empty map.

	@param value any
	@return OwnershipOverrideState
]=]
function PlayerProductOwnershipOverrideUtils.sanitizeState(value: any): OwnershipOverrideState
	local state: OwnershipOverrideState = {}
	if type(value) ~= "table" then
		return state
	end

	for key, ownsAsset in value do
		if type(key) == "string" and type(ownsAsset) == "boolean" then
			state[key] = ownsAsset
		end
	end

	return state
end

return PlayerProductOwnershipOverrideUtils
