---
-- @module CmdrService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local PermissionService = require("PermissionService")
local Promise = require("Promise")

local CmdrService = {}

function CmdrService:Init(serviceBag)
	assert(not self._cmdr, "Already initialized")

	self._cmdr = require("Cmdr")
	self._cmdr:RegisterDefaultCommands()

	self._permissionService = serviceBag:GetService(PermissionService)

	self._cmdr.Registry:RegisterHook("BeforeRun", function(context)
		local providerPromise = self._permissionService:PromisePermissionProvider()
		if providerPromise:IsPending() then
			return "Still loading permissions"
		end

		local ok, provider = providerPromise:Yield()
		if not ok then
			return provider or "Failed to load permission provider"
		end

		if context.Group == "DefaultAdmin" and not provider:IsAdmin(context.Executor) then
			return "You don't have permission to run this command"
		end
	end)
end

function CmdrService:PromiseCmdr()
	assert(self._cmdr, "Not initialized")

	return Promise.resolved(self._cmdr)
end

return CmdrService