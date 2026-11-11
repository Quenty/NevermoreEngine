--!strict
--[=[
	Action that answers `queryLogs` from the plugin's log buffer, filtered by
	level and by `since` (epoch seconds), then trimmed to `count` entries from
	the `head` or `tail`. `[StudioBridge]` messages are left out unless
	`includeInternal` is set. With `groupRepeats`, identical consecutive
	entries become one with `repeats` and `lastTimestamp`, before `count`
	applies, so `count` counts the grouped lines.

	Request: `{ type: "queryLogs", payload: { count?, direction?, levels?, includeInternal?, since?, groupRepeats? } }`
	Response: `{ type: "logsResult", payload: { entries, total, bufferCapacity } }`

	@class QueryLogsAction
]=]

local DEFAULT_COUNT = 50
local INTERNAL_PREFIX = "[StudioBridge]"

local QueryLogsAction = {}

type LogEntry = {
	level: string,
	body: string,
	timestamp: number,
	repeats: number?,
	lastTimestamp: number?,
}

--[=[
	Registers the `queryLogs` handler against `logBuffer`.
]=]
function QueryLogsAction.register(router: any, _sendMessage: any, logBuffer: any)
	router:setResponseType("queryLogs", "logsResult")
	router:register("queryLogs", function(payload: { [string]: any }, _requestId: string, _sessionId: string)
		local direction = payload.direction or "tail"
		local count = payload.count or DEFAULT_COUNT

		local snapshot = logBuffer:get(direction, nil)
		local filtered = QueryLogsAction._filterEntries(
			snapshot.entries,
			payload.levels,
			payload.includeInternal == true,
			if type(payload.since) == "number" then payload.since else nil
		)
		if payload.groupRepeats == true then
			filtered = QueryLogsAction._groupRepeats(filtered)
		end

		local takeCount = math.min(count, #filtered)
		local entries: { LogEntry }
		if direction == "head" then
			entries = table.move(filtered, 1, takeCount, 1, {})
		else
			entries = table.move(filtered, #filtered - takeCount + 1, #filtered, 1, {})
		end

		return {
			entries = entries,
			total = snapshot.total,
			bufferCapacity = snapshot.bufferCapacity,
		}
	end)
end

--[[
	Collapses runs of entries with the same level and body into the first,
	with how many there were and when the last was logged.
]]
function QueryLogsAction._groupRepeats(entries: { LogEntry }): { LogEntry }
	local grouped: { LogEntry } = {}
	local last: LogEntry? = nil
	for _, entry in entries do
		if last and last.level == entry.level and last.body == entry.body then
			last.repeats = (last.repeats or 1) + 1
			last.lastTimestamp = entry.timestamp
		else
			last = table.clone(entry)
			table.insert(grouped, last :: LogEntry)
		end
	end
	return grouped
end

function QueryLogsAction._filterEntries(
	entries: { LogEntry },
	levels: { string }?,
	includeInternal: boolean,
	since: number?
): { LogEntry }
	local filtered: { LogEntry } = {}
	for _, entry in entries do
		if not includeInternal and string.sub(entry.body, 1, #INTERNAL_PREFIX) == INTERNAL_PREFIX then
			continue
		end

		if levels and #levels > 0 and not table.find(levels, entry.level) then
			continue
		end

		if since and entry.timestamp < since then
			continue
		end

		table.insert(filtered, entry)
	end
	return filtered
end

return QueryLogsAction
