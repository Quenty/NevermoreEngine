--!strict
--[=[
	Action that searches the source of every script under `root` for `pattern`,
	answering with each matching line.

	- Matches the text plainly and case-insensitively by default. `luaPattern`
	  treats `pattern` as a Lua pattern, and `caseSensitive` keeps case.
	- Reads a script's open editor text when it has one, so unsaved edits are
	  searched as they read in Studio.

	Request: `{ type: "grepScripts", payload: { pattern, root?, query?, selector?, luaPattern?, caseSensitive?, limit? } }`
	Response: `{ type: "grepScriptsResult", payload: { matches, searched, total, scripts, truncated } }`, each match an InstanceRef with `line` and `text`

	@class GrepScriptsAction
]=]

local require = require(script.Parent.loader).load(script)

local InstanceQuery = require("InstanceQuery")
local InstanceRef = require("InstanceRef")

local DEFAULT_LIMIT = 200
local MAX_LINE_LENGTH = 300
local YIELD_EVERY = 200

local GrepScriptsAction = {}

type GrepMatch = {
	path: string,
	segments: { string },
	className: string,
	line: number,
	text: string,
}

--[=[
	Registers the `grepScripts` handler.
]=]
function GrepScriptsAction.register(router: any)
	router:setResponseType("grepScripts", "grepScriptsResult")
	router:register(
		"grepScripts",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			return GrepScriptsAction._grep(payload)
		end
	)
end

function GrepScriptsAction._grep(payload: { [string]: any }): { [string]: any }
	local pattern = payload.pattern
	if type(pattern) ~= "string" or pattern == "" then
		return {
			success = false,
			code = "INVALID_PAYLOAD",
			message = "grepScripts needs a pattern",
		}
	end

	local matchesLine, patternError =
		InstanceQuery.createTextMatcher(pattern, payload.luaPattern == true, payload.caseSensitive == true)
	if not matchesLine then
		return {
			success = false,
			code = "INVALID_PAYLOAD",
			message = patternError,
		}
	end

	local prepared, failure = InstanceQuery.prepare({
		root = payload.root,
		query = payload.query,
		selector = payload.selector,
	})
	if not prepared then
		return failure :: any
	end

	local limit = if type(payload.limit) == "number" then payload.limit else DEFAULT_LIMIT

	local matches: { GrepMatch } = {}
	local searched = 0
	local total = 0
	local scripts = 0
	for _, script in GrepScriptsAction._getScripts(prepared) do
		searched += 1
		if searched % YIELD_EVERY == 0 then
			task.wait()
		end

		local ref: InstanceRef.InstanceRef? = nil
		local hasMatch = false
		for lineNumber, text in InstanceQuery.getSourceLines(script) do
			if matchesLine(text) then
				total += 1
				hasMatch = true
				if #matches >= limit then
					continue
				end
				local scriptRef = ref or InstanceRef.from(script)
				ref = scriptRef
				table.insert(matches, {
					path = scriptRef.path,
					segments = scriptRef.segments,
					className = scriptRef.className,
					line = lineNumber,
					text = string.sub(text, 1, MAX_LINE_LENGTH),
				})
			end
		end

		if hasMatch then
			scripts += 1
		end
	end

	return {
		matches = matches,
		searched = searched,
		total = total,
		scripts = scripts,
		truncated = total > #matches,
	}
end

function GrepScriptsAction._getScripts(prepared: InstanceQuery.Prepared): { Instance }
	local scripts = {}
	local root = prepared.root
	if not prepared.selector and root:IsA("LuaSourceContainer") and prepared.matches(root) then
		table.insert(scripts, root)
	end
	for _, instance in InstanceQuery.getCandidates(prepared) do
		if instance:IsA("LuaSourceContainer") and prepared.matches(instance) then
			table.insert(scripts, instance)
		end
	end
	return scripts
end

return GrepScriptsAction
