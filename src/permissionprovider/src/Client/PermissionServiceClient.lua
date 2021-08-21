---
-- @module PermissionServiceClient
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderClient = require("PermissionProviderClient")
local Promise = require("Promise")

local PermissionServiceClient = {}

function PermissionServiceClient:Init(_serviceBag)
	self._provider = PermissionProviderClient.new(PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME)
end

function PermissionServiceClient:PromisePermissionProvider()
	return Promise.resolved(self._provider)
end

return PermissionServiceClient