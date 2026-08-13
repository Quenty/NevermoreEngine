--!strict
--[=[
	Shared plumbing for the datastore Cmdr commands.

	@server
	@class DataStoreCmdrUtils
]=]

local require = require(script.Parent.loader).load(script)

local DataStoreStage = require("DataStoreStage")

local DataStoreCmdrUtils = {}

--[=[
	Splits a slash-delimited sub-store path into its segments, dropping empty ones so a stray or
	trailing slash is forgiving rather than an error. An empty path means the root store.

	@param text string
	@return { string }
]=]
function DataStoreCmdrUtils.parsePath(text: string): { string }
	assert(type(text) == "string", "Bad text")

	local path = {}
	for segment in string.gmatch(text, "[^/]+") do
		table.insert(path, segment)
	end

	return path
end

--[=[
	Walks a sub-store path from a store, returning the store itself for an empty path.

	@param dataStoreStage DataStoreStage
	@param path { string }
	@return DataStoreStage
]=]
function DataStoreCmdrUtils.resolveSubStore(
	dataStoreStage: DataStoreStage.DataStoreStage,
	path: { string }
): DataStoreStage.DataStoreStage
	local current = dataStoreStage
	for _, segment in path do
		current = current:GetSubStore(segment)
	end

	return current
end

--[=[
	Collects the sub-store paths within loaded data, so a later command can autocomplete against
	names this server has actually seen. Table-valued keys are taken to be sub-stores, which is a
	heuristic -- a plain table of data is indistinguishable from a sub-store once loaded -- but a
	wrong guess only ever costs a spurious autocomplete entry.

	@param names { [string]: true } -- mutated in place
	@param data any
	@param prefix string?
	@param depth number?
]=]
function DataStoreCmdrUtils.harvestSubStoreNames(
	names: { [string]: true },
	data: any,
	prefix: string?,
	depth: number?
): ()
	if type(data) ~= "table" then
		return
	end

	-- Two levels is where the useful names live (a system store and its sections); deeper paths are
	-- typed out literally rather than offered.
	local remaining = depth or 2
	if remaining <= 0 then
		return
	end

	for key, value in data do
		if type(key) == "string" and type(value) == "table" then
			local path = if prefix then `{prefix}/{key}` else key
			names[path] = true
			DataStoreCmdrUtils.harvestSubStoreNames(names, value, path, remaining - 1)
		end
	end
end

--[=[
	Registers the sub-store path type.

	Cmdr resolves types against the executor, who cannot see another player's stores, so this cannot
	offer a target's real sub-stores. It offers the paths this server has already read (see
	[DataStoreCmdrUtils.harvestSubStoreNames]) and otherwise accepts whatever is typed, which is what
	lets a path be named before anyone has read one.

	@param cmdr Cmdr
	@param getKnownNames () -> { string }
]=]
function DataStoreCmdrUtils.registerSubStoreType(cmdr: any, getKnownNames: () -> { string }): ()
	local subStore = {
		Transform = function(text: string)
			local matches = cmdr.Util.MakeFuzzyFinder(getKnownNames())(text)
			if #matches > 0 then
				return matches
			end

			if text ~= "" then
				return { text }
			end

			return matches
		end,
		Validate = function(keys: { string })
			return #keys > 0, "Not a sub-store path."
		end,
		Autocomplete = function(keys: { string })
			return keys
		end,
		Parse = function(keys: { string })
			return DataStoreCmdrUtils.parsePath(keys[1])
		end,
	}

	cmdr.Registry:RegisterType("dataStoreSubStore", subStore)
end

return DataStoreCmdrUtils
