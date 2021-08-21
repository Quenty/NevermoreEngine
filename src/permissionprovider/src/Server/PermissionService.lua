---
-- @module PermissionService
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local CreatorPermissionProvider = require("CreatorPermissionProvider")
local GroupPermissionProvider = require("GroupPermissionProvider")
local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderUtils = require("PermissionProviderUtils")
local Promise = require("Promise")

local PermissionService = {}

function PermissionService:Init(_serviceBag)
	assert(not self._promise, "Already initialized")
	assert(not self._provider, "Already have provider")

	self._provider = nil
	self._promise = Promise.new()
end

function PermissionService:SetProviderFromConfig(config)
	assert(self._promise, "Not initialized")
	assert(not self._provider, "Already have provider set")

	if config.type == PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE then
		self._provider = GroupPermissionProvider.new(config)
	elseif config.type == PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE then
		self._provider = CreatorPermissionProvider.new(config)
	else
		error("Bad provider")
	end
end

function PermissionService:Start()
	if not self._provider then
		self:SetProviderFromConfig(PermissionProviderUtils.createConfigFromGame())
	end

	self._provider:Start()

	self._promise:Resolve(self._provider)
end

function PermissionService:PromisePermissionProvider()
	assert(self._promise, "Not initialized")

	return self._promise
end

return PermissionService