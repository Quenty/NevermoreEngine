---
-- @module CmdrServiceClient
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local promiseChild = require("promiseChild")
local PromiseUtils = require("PromiseUtils")
local PermissionServiceClient = require("PermissionServiceClient")

local CmdrServiceClient = {}

function CmdrServiceClient:Init(serviceBag)
	assert(serviceBag, "No serviceBag")

	self._permissionService = serviceBag:GetService(PermissionServiceClient)
end

function CmdrServiceClient:Start()
	PromiseUtils.all({
		self:PromiseCmdr(),
		self._permissionService:PromisePermissionProvider()
			:Then(function(provider)
				return provider:PromiseIsAdmin()
			end)
	})
	:Then(function(cmdr, isAdmin)
		if isAdmin then
			cmdr:SetActivationUnlocksMouse(true)
			cmdr:SetActivationKeys({ Enum.KeyCode.F2 })

			-- Default blink for debugging purposes
			cmdr.Dispatcher:Run("bind", Enum.KeyCode.G.Name, "blink")
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