--[=[
	@class SecretsServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTE_FUNCTION_NAME = "SecretsServiceRemoteFunction";
	REQUEST_SECRET_KEY_NAMES_LIST = "requestSecretKeyNamesList"
})