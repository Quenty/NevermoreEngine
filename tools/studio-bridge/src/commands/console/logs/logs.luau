--[[
	QueryLogs action handler for the studio-bridge plugin.

	Reads from a MessageBuffer instance and returns filtered log entries.
	Supports direction (head/tail), count, level filtering, and
	includeInternal (to show/hide [StudioBridge] messages).

	Protocol:
	  Request:  { type: "queryLogs", payload: { count?, direction?, levels?, includeInternal? } }
	  Response: { type: "logsResult", payload: { entries, total, bufferCapacity } }
]]

local QueryLogsAction = {}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- Register this handler with the ActionRouter.
function QueryLogsAction.register(router: any, _sendMessage: any, logBuffer: any)
	router:register("queryLogs", function(payload: { [string]: any }, _requestId: string, _sessionId: string)
		local direction = payload.direction or "tail"
		local count = payload.count or 50
		local levels = payload.levels -- nil means all levels
		local includeInternal = payload.includeInternal == true

		-- Get raw entries from the buffer
		local result = logBuffer:get(direction, nil) -- get all, then filter

		local filtered = {}
		for _, entry in result.entries do
			-- Filter by includeInternal
			if not includeInternal and string.sub(entry.body, 1, 14) == "[StudioBridge]" then
				continue
			end

			-- Filter by levels
			if levels and #levels > 0 then
				local matched = false
				for _, level in levels do
					if entry.level == level then
						matched = true
						break
					end
				end
				if not matched then
					continue
				end
			end

			table.insert(filtered, entry)
		end

		-- Apply direction and count to filtered results
		local entries = {}
		if direction == "head" then
			for i = 1, math.min(count, #filtered) do
				table.insert(entries, filtered[i])
			end
		else
			local start = math.max(1, #filtered - count + 1)
			for i = start, #filtered do
				table.insert(entries, filtered[i])
			end
		end

		return {
			entries = entries,
			total = result.total,
			bufferCapacity = result.bufferCapacity,
		}
	end)
end

return QueryLogsAction
