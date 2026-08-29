--!strict
--[=[
	Shared plumbing for the datastore Cmdr commands. Runs on both realms, so nothing here may reach
	for a store -- those live on the server.

	@class DataStoreCmdrUtils
]=]

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
	Registers the sub-store path type.

	Cmdr resolves types against the executor, who cannot see another player's stores, so a path is
	accepted as typed rather than completed against anything.

	@param cmdr Cmdr
]=]
function DataStoreCmdrUtils.registerSubStoreType(cmdr: any): ()
	local subStore = {
		Transform = function(text: string)
			if text ~= "" then
				return { text }
			end

			return {}
		end,
		Validate = function(keys: { string })
			return #keys > 0, "Not a sub-store path."
		end,
		Parse = function(keys: { string })
			return DataStoreCmdrUtils.parsePath(keys[1])
		end,
	}

	cmdr.Registry:RegisterType("dataStoreSubStore", subStore)
end

return DataStoreCmdrUtils
