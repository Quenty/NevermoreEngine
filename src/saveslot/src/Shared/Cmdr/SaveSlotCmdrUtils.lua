--!strict
--[=[
	@class SaveSlotCmdrUtils
]=]

local require = require(script.Parent.loader).load(script)

local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")

local SaveSlotCmdrUtils = {}

-- How deep a summary value is expanded before it collapses to "...". Summaries come out of a
-- JSON-encoded attribute, so they are shallow in practice; this only guards a pathological one.
local MAX_VALUE_DEPTH = 3

function SaveSlotCmdrUtils.registerSlotIndexType(cmdr, saveSlotDataService)
	local slotIndex = {
		Transform = function(text: string, player: Player)
			local slots = saveSlotDataService:GetSlotList(player)
			local slotIndices = {}
			for _, metadata in slots do
				table.insert(slotIndices, tostring(metadata.SlotIndex))
			end

			-- The active ephemeral slot is deliberately absent from the slot list -- it is a throwaway
			-- session, not a save -- but it is still the slot the player is actually in, and admin tooling
			-- has to be able to name it (to persist it, export it, or end it). It answers to the reserved
			-- ephemeral index, which no real slot can hold, so it never shadows one. Offering it here is
			-- also what makes "." resolve while a session is active, since Default hands its index back
			-- through this finder.
			if saveSlotDataService:IsActiveSlotEphemeral(player) then
				table.insert(slotIndices, tostring(SaveSlotConstants.EPHEMERAL_SLOT_INDEX))
			end

			local matches = cmdr.Util.MakeFuzzyFinder(slotIndices)(text)
			if #matches > 0 then
				return matches
			end

			-- Autocomplete can only ever offer the executor's own slots -- Cmdr resolves types against the
			-- executor -- but these commands target other players, whose slots the executor cannot see. So
			-- any literal index typed out is accepted even when the executor has no such slot, which is what
			-- makes `saveslot-export SomeoneElse 3` possible. A target without that slot is reported by the
			-- command itself, which resolves the index per player.
			local literalIndex = tonumber(text)
			if literalIndex and (literalIndex >= 0) and (literalIndex % 1 == 0) then
				return { tostring(literalIndex) }
			end

			return matches
		end,
		Validate = function(keys)
			return #keys > 0, "Not a slot index."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return tonumber(keys[1])
		end,

		-- "." resolves to the player's current slot: the active slot when one is selected, otherwise the
		-- slot they last played. Cmdr feeds this string back through Transform, so it fuzzy matches the
		-- real slot. MakeListableType inherits Default, so "." works for saveslot-delete's list too.
		Default = function(player: Player): string?
			local slotId = saveSlotDataService:GetLastActiveSlotId(player)
			if not slotId then
				return nil
			end
			local metadata = saveSlotDataService:GetSlotMetadata(player, slotId)
			if type(metadata) ~= "table" then
				return nil
			end
			return tostring(metadata.SlotIndex)
		end,
	}

	cmdr.Registry:RegisterType("slotIndex", slotIndex)
	cmdr.Registry:RegisterType("slotIndices", cmdr.Util.MakeListableType(slotIndex))
end

local function formatNumber(value: number): string
	-- Datastore round-trips integers as floats, so print whole numbers without a decimal tail.
	if value % 1 == 0 and math.abs(value) < 1e15 then
		return string.format("%d", value)
	end

	return string.format("%.2f", value)
end

local function isArray(value: { [any]: any }): boolean
	local count = 0
	for _ in value do
		count += 1
	end

	return count == #value
end

local function formatTableInner(value: { [any]: any }, depth: number): string
	local parts = {}

	if isArray(value) then
		for _, item in value do
			table.insert(parts, SaveSlotCmdrUtils.formatValue(item, depth - 1))
		end
	else
		-- Sorted so repeated listings of the same slot read the same way.
		local entries = {}
		for key, item in value do
			table.insert(entries, { key = tostring(key), value = item })
		end
		table.sort(entries, function(a, b)
			return a.key < b.key
		end)

		for _, entry in entries do
			table.insert(parts, `{entry.key} = {SaveSlotCmdrUtils.formatValue(entry.value, depth - 1)}`)
		end
	end

	return table.concat(parts, ", ")
end

--[=[
	Renders a JSON-shaped value on a single line, for console output. Tables become `{a = 1, b = 2}`
	and arrays `[1, 2]`, nested up to `depth` levels before collapsing to "...".

	@param value any
	@param depth number? -- defaults to 3
	@return string
]=]
function SaveSlotCmdrUtils.formatValue(value: any, depth: number?): string
	local remaining = depth or MAX_VALUE_DEPTH

	if type(value) == "number" then
		return formatNumber(value)
	elseif type(value) ~= "table" then
		return tostring(value)
	end

	if remaining <= 0 then
		return "..."
	end

	local inner = formatTableInner(value, remaining)
	if isArray(value) then
		return `[{inner}]`
	end

	return "{" .. inner .. "}"
end

--[=[
	Renders a duration in seconds as "1h 23m", "23m", or "45s".

	@param seconds number
	@return string
]=]
function SaveSlotCmdrUtils.formatDuration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)

	if hours > 0 then
		return `{hours}h {minutes}m`
	elseif minutes > 0 then
		return `{minutes}m`
	end

	return `{total}s`
end

--[=[
	Renders a unix timestamp as UTC plus how long ago it was, e.g. "2026-08-12 14:03 UTC (3h ago)".
	The relative part is what an admin actually reads; the absolute one is what they quote back.

	@param unixTime number
	@param now number? -- defaults to os.time()
	@return string
]=]
function SaveSlotCmdrUtils.formatTimestamp(unixTime: number, now: number?): string
	local absolute = os.date("!%Y-%m-%d %H:%M UTC", math.floor(unixTime))
	local elapsed = (now or os.time()) - unixTime
	if elapsed < 0 then
		return absolute
	end

	local relative
	if elapsed < 60 then
		relative = "just now"
	elseif elapsed < 3600 then
		relative = `{math.floor(elapsed / 60)}m ago`
	elseif elapsed < 86400 then
		relative = `{math.floor(elapsed / 3600)}h ago`
	else
		relative = `{math.floor(elapsed / 86400)}d ago`
	end

	return `{absolute} ({relative})`
end

--[=[
	Renders a slot's [SaveSlotData.SaveSlotSummary] as one line per summary provider, keyed by provider
	name (see [HasSaveSlots.RegisterSummaryProvider]). A legacy plain-string summary is passed through
	as its own line, and a summary with nothing in it yields no lines at all.

	@param summary SaveSlotData.SaveSlotSummary | string | nil
	@return { string }
]=]
function SaveSlotCmdrUtils.formatSummaryLines(summary: SaveSlotData.SaveSlotSummary | string | nil): { string }
	if summary == nil then
		return {}
	elseif type(summary) == "string" then
		return { summary }
	end

	local names = {}
	for name in summary do
		table.insert(names, tostring(name))
	end
	table.sort(names)

	local lines = {}
	for _, name in names do
		local value = (summary :: any)[name]
		-- A provider's own table is unwrapped, so its fields sit next to the provider name rather than
		-- inside a second pair of braces.
		local text = if type(value) == "table" and next(value) ~= nil
			then formatTableInner(value, MAX_VALUE_DEPTH)
			else SaveSlotCmdrUtils.formatValue(value)
		table.insert(lines, `{name}: {text}`)
	end

	return lines
end

--[=[
	Renders one slot as the block `saveslot-list` prints for it: a header naming the slot, then an
	indented line of playtime and timestamps, then a line per summary provider. Lines with nothing
	behind them are left out, so a slot that has never been played prints as its header alone.

	@param metadata SaveSlotData.SaveSlotMetadata
	@param status string? -- appended to the header, e.g. "Active"
	@param now number? -- defaults to os.time(), for the relative timestamps
	@return string
]=]
function SaveSlotCmdrUtils.formatSlotBlock(
	metadata: SaveSlotData.SaveSlotMetadata,
	status: string?,
	now: number?
): string
	local name = metadata.SlotName or `Slot {metadata.SlotIndex}`
	local lines = { `"{name}" ({metadata.SlotIndex}){if status then ` — {status}` else ""}` }

	local played = {}
	if metadata.TimePlayed and metadata.TimePlayed > 0 then
		table.insert(played, `played {SaveSlotCmdrUtils.formatDuration(metadata.TimePlayed)}`)
	end
	if metadata.PlayCount and metadata.PlayCount > 0 then
		table.insert(played, `{formatNumber(metadata.PlayCount)} session(s)`)
	end
	if metadata.LastPlayedTime then
		table.insert(played, `last played {SaveSlotCmdrUtils.formatTimestamp(metadata.LastPlayedTime, now)}`)
	end
	if #played > 0 then
		table.insert(lines, `  {table.concat(played, ", ")}`)
	end

	if metadata.CreatedTime then
		table.insert(lines, `  created {SaveSlotCmdrUtils.formatTimestamp(metadata.CreatedTime, now)}`)
	end

	for _, line in SaveSlotCmdrUtils.formatSummaryLines(metadata.Summary) do
		table.insert(lines, `  {line}`)
	end

	return table.concat(lines, "\n")
end

return SaveSlotCmdrUtils
