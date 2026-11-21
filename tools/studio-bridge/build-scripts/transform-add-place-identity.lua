--# selene: allow(incorrect_standard_library_use)
-- transform-add-place-identity.lua
-- Marks a place built from a checkout with the place and universe it was built
-- for, so the studio-bridge plugin can give it that identity when Studio opens
-- it. A local file opens with PlaceId 0, which DataStores and other place
-- services refuse; DataModel:SetPlaceId/SetUniverseId are plugin-only, so the
-- file carries the ids and the plugin applies them.
--
-- Usage: lune run transform-add-place-identity.lua <inputPath> <outputPath> <placeId> <universeId>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local inputPath = process.args[1]
local outputPath = process.args[2]
local placeId = process.args[3]
local universeId = process.args[4]

local function isId(value: string?): boolean
	return value ~= nil and string.match(value, "^%d+$") ~= nil
end

if not inputPath or not outputPath or not isId(placeId) or not isId(universeId) then
	print("Usage: lune run transform-add-place-identity.lua <inputPath> <outputPath> <placeId> <universeId>")
	process.exit(1)
end

-- Keep in sync with StudioBridgePlaceIdentityUtils in plugins/studio-bridge-plugin.
-- The ids are written as strings: place ids are past 2^31, and a number
-- attribute does not survive the place serializer intact.
local game = roblox.deserializePlace(fs.readFile(inputPath))
local workspace = game:GetService("Workspace")
workspace:SetAttribute("StudioBridgePlaceId", placeId)
workspace:SetAttribute("StudioBridgeUniverseId", universeId)
fs.writeFile(outputPath, roblox.serializePlace(game))
