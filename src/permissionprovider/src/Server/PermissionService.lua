--[=[
	Provides permissions for the game. See [BasePermissionProvider].

	:::tip
	Be sure to initialize the [PermissionServiceClient] on the client.
	:::

	```lua
	local require = require(script.Parent.loader).load(script)

	local PermissionProvider = require("PermissionProvider")
	local PermissionProviderUtils = require("PermissionProviderUtils")

	return PermissionProvider.new(PermissionProviderUtils.createGroupRankConfig({
	  groupId = 8668163;
	  minAdminRequiredRank = 250;
	  minCreatorRequiredRank = 254;
	}))
	```

	@server
	@class PermissionService
]=]

local require = require(script.Parent.loader).load(script)

local CreatorPermissionProvider = require("CreatorPermissionProvider")
local GroupPermissionProvider = require("GroupPermissionProvider")
local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderUtils = require("PermissionProviderUtils")
local Promise = require("Promise")
local Maid = require("Maid")

local PermissionService = {}
PermissionService.ServiceName = "PermissionService"

--[=[
	Initializes the service. Should be done via [ServiceBag].
	@param _serviceBag ServiceBag
]=]
function PermissionService:Init(_serviceBag)
	assert(not self._promise, "Already initialized")
	assert(not self._provider, "Already have provider")

	self._provider = nil

	self._maid = Maid.new()

	self._promise = Promise.new()
	self._maid:GiveTask(self._promise)
end

--[=[
	Sets the provider from a config. See [PermissionProviderUtils.createGroupRankConfig]
	and [PermissionProviderUtils.createSingleUserConfig].

	@param config { type: string }
]=]
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

--[=[
	Starts the permission service. Should be done via [ServiceBag].
]=]
function PermissionService:Start()
	if not self._provider then
		self:SetProviderFromConfig(PermissionProviderUtils.createConfigFromGame())
	end

	self._provider:Start()

	self._promise:Resolve(self._provider)
end

--[=[
	Returns the permission provider
	@return Promise<BasePermissionProvider>
]=]
function PermissionService:PromisePermissionProvider()
	assert(self._promise, "Not initialized")

	return self._promise
end

function PermissionService:Destroy()
	self._maid:DoCleaning()
	self._provider = nil
end

return PermissionService