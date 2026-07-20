--!strict
--[=[
	Pure assembly and reading of the per-player teleport-data envelope, plus the size guard.

	A group teleport carries a single [TeleportData] table that every arriving player reads back
	through `GetJoinData().TeleportData`. To carry *per-player* data we wrap the contributions in an
	envelope: shared keys under one reserved key, and each player's slice under another keyed by
	stringified `UserId` (the only identity stable across a teleport). Each player merges the shared
	slice with their own on arrival. A non-envelope table (an in-flight teleport from a build predating
	this, or a hand-written `TeleportData`) is read as-is, so the change is backward compatible.

	All logic here is pure and keyed by plain numbers, so it is unit tested without any [Player].

	@server
	@class TeleportDataEnvelopeUtils
]=]

local HttpService = game:GetService("HttpService")

local TeleportDataEnvelopeUtils = {}

-- Reserved top-level keys. Providers contribute keys *inside* a slice, never at the envelope root,
-- so these only collide with a hand-written flat table that itself uses one of these names -- which
-- is why they are namespaced.
local SHARED_KEY = "__shared"
local PER_PLAYER_KEY = "__perPlayer"

-- Roblox's TeleportData has no hard limit, but payloads past ~250 KB "usually fail, leading to lost
-- data or errors", so we treat that as the ceiling and warn with margin below it (JSONEncode length
-- is an approximation of the real serialized size).
TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES = 250 * 1024
TeleportDataEnvelopeUtils.WARN_TELEPORT_DATA_BYTES = 200 * 1024

export type TeleportDataSlice = { [string]: any }
export type SizeLevel = "ok" | "warn" | "over"
export type SizeClassification = {
	bytes: number,
	level: SizeLevel,
}

--[=[
	Whether a table read from teleport data is one of our envelopes (versus a legacy/hand-written flat
	table, which carries data keys at the root).

	@param raw any
	@return boolean
]=]
function TeleportDataEnvelopeUtils.isEnvelope(raw: any): boolean
	if type(raw) ~= "table" then
		return false
	end

	return type(raw[SHARED_KEY]) == "table" or type(raw[PER_PLAYER_KEY]) == "table"
end

--[=[
	Assembles an envelope from a shared slice and a map of per-player slices keyed by UserId. Empty
	sections are omitted, so a teleport carrying nothing serializes to `{}`.

	@param sharedSlice TeleportDataSlice? -- applied to every arriving player
	@param perPlayerByUserId { [string]: TeleportDataSlice }? -- keyed by stringified UserId
	@return { [string]: any }
]=]
function TeleportDataEnvelopeUtils.build(
	sharedSlice: TeleportDataSlice?,
	perPlayerByUserId: { [string]: TeleportDataSlice }?
): { [string]: any }
	local envelope: { [string]: any } = {}

	if sharedSlice ~= nil and next(sharedSlice) ~= nil then
		envelope[SHARED_KEY] = sharedSlice
	end

	if perPlayerByUserId ~= nil and next(perPlayerByUserId) ~= nil then
		envelope[PER_PLAYER_KEY] = perPlayerByUserId
	end

	return envelope
end

--[=[
	Reads the slice a specific player arrived with: the shared slice merged with that player's own
	(per-player wins on conflict, being the more specific). A non-envelope table is returned as-is
	(legacy/hand-written flat data). Returns nil when the player carried nothing.

	@param raw any -- the raw arrived teleport data
	@param userId number | string -- the arriving player's UserId
	@return TeleportDataSlice?
]=]
function TeleportDataEnvelopeUtils.readSlice(raw: any, userId: number | string): TeleportDataSlice?
	if type(raw) ~= "table" then
		return nil
	end

	if not TeleportDataEnvelopeUtils.isEnvelope(raw) then
		return raw
	end

	local merged: TeleportDataSlice = {}

	local shared = raw[SHARED_KEY]
	if type(shared) == "table" then
		for key, value in shared do
			merged[key] = value
		end
	end

	local perPlayer = raw[PER_PLAYER_KEY]
	if type(perPlayer) == "table" then
		local slice = perPlayer[tostring(userId)]
		if type(slice) == "table" then
			for key, value in slice do
				merged[key] = value
			end
		end
	end

	if next(merged) == nil then
		return nil
	end

	return merged
end

--[=[
	Approximate serialized byte size of teleport data, via its JSON encoding. Encoding also fails
	loudly on genuinely un-encodable data (a cyclic table, a function value), so that surfaces here at
	build time rather than as a broken teleport.

	@param data any
	@return number
]=]
function TeleportDataEnvelopeUtils.measureBytes(data: any): number
	local ok, encodedOrErr = pcall(function()
		return HttpService:JSONEncode(data)
	end)

	if not ok then
		error(`[TeleportDataEnvelopeUtils] teleport data could not be encoded: {tostring(encodedOrErr)}`)
	end

	return #(encodedOrErr :: string)
end

--[=[
	Classifies teleport data against the size budget: `ok`, `warn` (approaching the cap), or `over`
	(past it -- will likely be dropped/error by Roblox).

	@param data any
	@return SizeClassification
]=]
function TeleportDataEnvelopeUtils.classifySize(data: any): SizeClassification
	local bytes = TeleportDataEnvelopeUtils.measureBytes(data)

	local level: SizeLevel
	if bytes > TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES then
		level = "over"
	elseif bytes > TeleportDataEnvelopeUtils.WARN_TELEPORT_DATA_BYTES then
		level = "warn"
	else
		level = "ok"
	end

	return {
		bytes = bytes,
		level = level,
	}
end

return TeleportDataEnvelopeUtils
