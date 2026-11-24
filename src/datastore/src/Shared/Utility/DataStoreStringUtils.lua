--!strict
--[=[
	Utility methods to validate strings which can be used to attack datastores in a string saving attack otherwise.

	@class DataStoreStringUtils
]=]

local DataStoreStringUtils = {}

--[=[
	Checks to see if a string can be stored in the datastore. Any well-formed UTF-8 can be, including
	text outside ASCII.

	@param str string
	@return boolean
]=]
function DataStoreStringUtils.isValidUTF8(str: string): (boolean, string?)
	if type(str) ~= "string" then
		return false, "Not a string"
	end

	-- Malformed UTF-8 (including encoded surrogates) cannot be saved, and utf8.len refuses all of it.
	-- An ASCII-only check would block international text for no gain.
	-- https://gist.github.com/TheGreatSageEqualToHeaven/e0e1dc2698307c93f6013b9825705899#patch-1
	if not utf8.len(str) then
		return false, "Invalid string"
	end

	return true
end

return DataStoreStringUtils
