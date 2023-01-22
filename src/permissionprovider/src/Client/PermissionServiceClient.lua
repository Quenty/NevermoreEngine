--[=[
	Provides permissions on the client. See [PermissionService] for more details.

	:::tip
	Be sure to initialize the [PermissionService] on the server.
	:::

	@class PermissionServiceClient
	@client
]=]

local require = require(script.Parent.loader).load(script)

local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderClient = require("PermissionProviderClient")
local Promise = require("Promise")

local PermissionServiceClient = {}
PermissionServiceClient.ServiceName = "PermissionServiceClient"

--[=[
	Initializes the permission service on the client. Should be done via [ServiceBag].
	@param _serviceBag ServiceBag
]=]
function PermissionServiceClient:Init(_serviceBag)
	self._provider = PermissionProviderClient.new(PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME)
end

--[=[
	Returns the permission provider
	@return Promise<PermissionProviderClient>
]=]
function PermissionServiceClient:PromisePermissionProvider()
	return Promise.resolved(self._provider)
end

return PermissionServiceClient