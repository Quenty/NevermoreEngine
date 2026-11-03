--!strict
--[=[
	Action that searches the source of every script under `root` for `pattern`,
	answering with each matching line.

	- Matches the text plainly and case-insensitively by default. `luaPattern`
	  treats `pattern` as a Lua pattern, and `caseSensitive` keeps case.
	- Reads a script's open editor text when it has one, so unsaved edits are
	  searched as they read in Studio.
	- Stops after `limit` matching lines.

	Request: `{ type: "grepScripts", payload: { pattern, root?, luaPattern?, caseSensitive?, limit? } }`
	Response: `{ type: "grepScriptsResult", payload: { matches, searched, truncated } }`

	@class GrepScriptsAction
]=]

local DEFAULT_LIMIT = 200
local MAX_LINE_LENGTH = 300
local YIELD_EVERY = 200
-- Studio's own instances, which the place does not contain
local ENGINE_SERVICES = table.freeze({
	CoreGui = true,
	CorePackages = true,
	RobloxReplicatedStorage = true,
})

local GrepScriptsAction = {}

type GrepMatch = {
	path: string,
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
			local pattern = payload.pattern
			if type(pattern) ~= "string" or pattern == "" then
				return {
					success = false,
					code = "INVALID_PAYLOAD",
					message = "grepScripts needs a pattern",
				}
			end

			local luaPattern = payload.luaPattern == true
			local caseSensitive = payload.caseSensitive == true
			if luaPattern then
				local ok, err = pcall(string.find, "", pattern)
				if not ok then
					return {
						success = false,
						code = "INVALID_PAYLOAD",
						message = `Invalid Lua pattern: {err}`,
					}
				end
			end

			local root: Instance? = game
			if type(payload.root) == "string" then
				root = GrepScriptsAction._resolveInstance(payload.root)
				if not root then
					return {
						success = false,
						code = "INSTANCE_NOT_FOUND",
						message = `Instance not found at path: {payload.root}`,
					}
				end
			end

			local needle = if caseSensitive
				then pattern
				elseif luaPattern then GrepScriptsAction._lowerPattern(pattern)
				else string.lower(pattern)
			local limit = if type(payload.limit) == "number" then payload.limit else DEFAULT_LIMIT

			local matches: { GrepMatch } = {}
			local searched = 0
			local truncated = false
			for _, script in GrepScriptsAction._getScripts(root :: Instance) do
				searched += 1
				if searched % YIELD_EVERY == 0 then
					task.wait()
				end

				local source = GrepScriptsAction._readSource(script)
				for lineNumber, rawText in string.split(source, "\n") do
					local text = string.gsub(rawText, "\r$", "")
					local haystack = if caseSensitive then text else string.lower(text)
					if string.find(haystack, needle, 1, not luaPattern) then
						if #matches >= limit then
							truncated = true
							break
						end
						table.insert(matches, {
							path = script:GetFullName(),
							className = script.ClassName,
							line = lineNumber,
							text = string.sub(text, 1, MAX_LINE_LENGTH),
						})
					end
				end

				if truncated then
					break
				end
			end

			return {
				matches = matches,
				searched = searched,
				truncated = truncated,
			}
		end
	)
end

--[[
	Lowercases a Lua pattern's literal letters, leaving each character after a
	`%` alone, since `%S` and `%s` are opposite classes.
]]
function GrepScriptsAction._lowerPattern(pattern: string): string
	local lowered = {}
	local isEscaped = false
	for _, char in string.split(pattern, "") do
		table.insert(lowered, if isEscaped then char else string.lower(char))
		isEscaped = not isEscaped and char == "%"
	end
	return table.concat(lowered)
end

function GrepScriptsAction._readSource(script: LuaSourceContainer): string
	local editorOk, editorSource = pcall(function()
		return game:GetService("ScriptEditorService"):GetEditorSource(script)
	end)
	if editorOk and type(editorSource) == "string" then
		return editorSource
	end

	local ok, source = pcall(function()
		return (script :: any).Source
	end)
	return if ok and type(source) == "string" then source else ""
end

--[[
	Returns the scripts under `root`. For game, that is those of each place
	service the plugin may read, since some refuse access.
]]
function GrepScriptsAction._getScripts(root: Instance): { LuaSourceContainer }
	local roots = if root == game then game:GetChildren() else { root }

	local scripts = {}
	for _, searchRoot in roots do
		if root == game and ENGINE_SERVICES[searchRoot.ClassName] then
			continue
		end
		local ok, descendants = pcall(searchRoot.GetDescendants, searchRoot)
		if not ok then
			continue
		end
		if searchRoot:IsA("LuaSourceContainer") then
			table.insert(scripts, searchRoot)
		end
		for _, descendant in descendants do
			if descendant:IsA("LuaSourceContainer") then
				table.insert(scripts, descendant)
			end
		end
	end
	return scripts
end

--[[
	Walks `path` down from game, falling back to GetService for top-level names
	that are not children by that name. A leading "game" is optional.
]]
function GrepScriptsAction._resolveInstance(path: string): Instance?
	local parts = string.split(path, ".")
	local startIndex = if parts[1] == "game" then 2 else 1

	local current: Instance = game
	for index = startIndex, #parts do
		local part = parts[index]

		local ok, child = pcall(current.FindFirstChild, current, part)
		if ok and child then
			current = child
			continue
		end

		if current ~= game then
			return nil
		end

		local serviceOk, service = pcall(game.GetService, game, part)
		if not (serviceOk and service) then
			return nil
		end
		current = service
	end

	return current
end

return GrepScriptsAction
