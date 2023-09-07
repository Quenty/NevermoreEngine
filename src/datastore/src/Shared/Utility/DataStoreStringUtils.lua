--[=[
	Utility methods to validate strings which can be used to attack datastores in a string saving attack otherwise.

	@class DataStoreStringUtils
]=]

local DataStoreStringUtils = {}

--[=[
	Checks to see if a string can be stored in the datastore

	@param str string
	@return boolean
]=]
function DataStoreStringUtils.isValidUTF8(str)
	if type(str) ~= "string" then
		return false, "Not a string"
	end

	if not utf8.len(str) then
		return false, "Invalid string"
	end

	-- https://gist.github.com/TheGreatSageEqualToHeaven/e0e1dc2698307c93f6013b9825705899#patch-1
	if string.match(str, "[^\0-\127]") then
		return false, "Invalid string"
	end

	return true
end

return DataStoreStringUtils
