--!strict
--[=[
	Loads cmdr on the client. See [CmdrService] for the server equivalent.

	@client
	@class CmdrServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local PermissionServiceClient = require("PermissionServiceClient")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local ServiceBag = require("ServiceBag")
local String = require("String")
local promiseChild = require("promiseChild")

local CmdrServiceClient = {}
CmdrServiceClient.ServiceName = "CmdrServiceClient"

export type CmdrServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_permissionServiceClient: any,
		_cmdrPromise: Promise.Promise<any>?,
	},
	{} :: typeof({ __index = CmdrServiceClient })
))

--[=[
	Starts the cmdr service on the client. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function CmdrServiceClient.Init(self: CmdrServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._permissionServiceClient = self._serviceBag:GetService(PermissionServiceClient)

	self:PromiseCmdr():Then(function(cmdr)
		cmdr.Registry:RegisterHook("BeforeRun", function(context): string?
			-- allow!
			if context.Executor == nil then
				return nil
			end

			local providerPromise = self._permissionServiceClient:PromisePermissionProvider()
			if providerPromise:IsPending() then
				return "Still loading permissions"
			end

			local ok, provider = providerPromise:Yield()
			if not ok then
				if type(provider) == "string" then
					return provider
				else
					return "Failed to load permission provider"
				end
			end

			local isAdmin
			ok, isAdmin = provider:PromiseIsAdmin(context.Executor):Yield()
			if not ok then
				if type(provider) == "string" then
					return provider
				else
					return "Failed to load permission provider"
				end
			end

			if not isAdmin then
				return "You don't have permission to run this command"
			else
				-- allow
				return nil
			end
		end)
	end)
end

--[=[
	Starts the service. Should be done via [ServiceBag].
]=]
function CmdrServiceClient.Start(self: CmdrServiceClient): ()
	assert(self._serviceBag, "Not initialized")

	;(self._maid
		:GivePromise(PromiseUtils.all({
			self:PromiseCmdr(),
			self._maid:GivePromise(self._permissionServiceClient:PromisePermissionProvider()):Then(function(provider)
				return provider:PromiseIsAdmin()
			end),
		})) :: any)
		:Then(function(cmdr: any, isAdmin: any)
			if isAdmin then
				self:_setBindings(cmdr)
			else
				cmdr:SetActivationKeys({})
			end
		end)
end

function CmdrServiceClient._setBindings(self: CmdrServiceClient, cmdr: any): ()
	cmdr:SetActivationUnlocksMouse(true)
	cmdr:SetActivationKeys({ Enum.KeyCode.F2 })

	-- enable activation on mobile
	self._maid:GiveTask(Players.LocalPlayer.Chatted:Connect(function(chat)
		if String.startsWith(chat, "/cmdr") then
			cmdr:Show()
		end
	end))

	-- Race condition
	task.defer(function()
		-- Default blink for debugging purposes
		cmdr.Dispatcher:Run("bind", Enum.KeyCode.G.Name, "blink")
	end)
end

--[=[
	Retrieves the cmdr for the client.
	@return Promise<CmdrClient>
]=]
function CmdrServiceClient.PromiseCmdr(self: CmdrServiceClient): Promise.Promise<any>
	assert(self._serviceBag, "Not initialized")

	if self._cmdrPromise then
		return self._cmdrPromise
	end

	-- Suppress warning in test mode for hoarcekat
	local timeout = nil
	if not RunService:IsRunning() then
		timeout = 1e10
	end

	local cmdrPromise = self._maid
		:GivePromise(promiseChild(ReplicatedStorage, "CmdrClient", timeout))
		:Then(function(cmdClient)
			return (Promise :: any).spawn(function(resolve: any, _reject: any)
				-- Requiring cmdr can yield
				return resolve((require :: any)(cmdClient))
			end)
		end)
	self._cmdrPromise = cmdrPromise
	self._maid:GiveTask(cmdrPromise)

	return cmdrPromise
end

function CmdrServiceClient.Destroy(self: CmdrServiceClient): ()
	self._maid:DoCleaning()
end

return CmdrServiceClient
