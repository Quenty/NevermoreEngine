--!strict
--[=[
	Gives a place built from a checkout the identity of the place it was built
	for. `studio-bridge process launch --from checkout` opens a local file, and a
	local file opens with PlaceId 0, which DataStores and other place services
	refuse. The build marks the file with the target's place and universe ids;
	this applies them, since only a plugin may call SetPlaceId/SetUniverseId.

	A playtest started afterwards inherits the ids from the edit DataModel.

	@class StudioBridgePlaceIdentityUtils
]=]

-- Keep in sync with tools/studio-bridge/build-scripts/transform-add-place-identity.lua.
local PLACE_ID_ATTRIBUTE = "StudioBridgePlaceId"
local UNIVERSE_ID_ATTRIBUTE = "StudioBridgeUniverseId"

local StudioBridgePlaceIdentityUtils = {}

export type PlaceIdentity = {
	placeId: number,
	universeId: number,
}

-- Marked as decimal strings: place ids are past 2^31, and a number attribute
-- does not survive the place serializer intact.
local function parseId(value: any): number?
	if type(value) ~= "string" or not string.match(value, "^%d+$") then
		return nil
	end
	local id = tonumber(value)
	return if id and id > 0 then id else nil
end

--[=[
	The ids a build marked the place with, or nil for a place nobody marked.
]=]
function StudioBridgePlaceIdentityUtils.readMarkedIdentity(workspace: Instance): PlaceIdentity?
	local placeId = parseId(workspace:GetAttribute(PLACE_ID_ATTRIBUTE))
	local universeId = parseId(workspace:GetAttribute(UNIVERSE_ID_ATTRIBUTE))
	if not placeId or not universeId then
		return nil
	end
	return {
		placeId = placeId,
		universeId = universeId,
	}
end

--[=[
	Applies the marked identity to an edit DataModel that has none of its own.
	A place that already has a PlaceId, because it was opened from Roblox or
	published since, keeps it. Returns the identity applied, if any.
]=]
function StudioBridgePlaceIdentityUtils.applyMarkedIdentity(dataModel: DataModel): PlaceIdentity?
	if dataModel.PlaceId ~= 0 then
		return nil
	end

	local identity = StudioBridgePlaceIdentityUtils.readMarkedIdentity(dataModel:GetService("Workspace"))
	if not identity then
		return nil
	end

	dataModel:SetPlaceId(identity.placeId)
	dataModel:SetUniverseId(identity.universeId)
	return identity
end

return StudioBridgePlaceIdentityUtils
