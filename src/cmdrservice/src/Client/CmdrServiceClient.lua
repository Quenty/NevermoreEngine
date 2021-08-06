---
-- @module CmdrServiceClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local promiseChild = require("promiseChild")
local PromiseUtils = require("PromiseUtils")
local PermissionServiceClient = require("PermissionServiceClient")

local CmdrServiceClient = {}

function CmdrServiceClient:Init(serviceBag)
	assert(serviceBag, "No serviceBag")

	self._permissionService = serviceBag:GetService(PermissionServiceClient)

	PromiseUtils.all({
		self:PromiseCmdr(),
		self._permissionService:PromisePermissionProvider()
			:Then(function(provider)
				return provider:PromiseIsAdmin()
			end)
	})
	:Then(function(cmdr, isAdmin)
		if isAdmin then
			cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
		else
			cmdr:SetActivationKeys({})
		end
	end)
end

function CmdrServiceClient:PromiseCmdr()
	if self._cmdrPromise then
		return self._cmdrPromise
	end

	self._cmdrPromise = promiseChild(ReplicatedStorage, "CmdrClient")
		:Then(function(cmdClient)
			return require(cmdClient)
		end)

	return self._cmdrPromise
end

return CmdrServiceClient