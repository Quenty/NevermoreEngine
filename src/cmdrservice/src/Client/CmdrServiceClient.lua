--[=[
	Loads cmdr on the client. See [CmdrService] for the server equivalent.

	@client
	@class CmdrServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local PermissionServiceClient = require("PermissionServiceClient")
local Promise = require("Promise")
local promiseChild = require("promiseChild")
local PromiseUtils = require("PromiseUtils")
local String = require("String")
local _ServiceBag = require("ServiceBag")

local CmdrServiceClient = {}
CmdrServiceClient.ServiceName = "CmdrServiceClient"

--[=[
	Starts the cmdr service on the client. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function CmdrServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._permissionServiceClient = self._serviceBag:GetService(PermissionServiceClient)

	self:PromiseCmdr():Then(function(cmdr)
		cmdr.Registry:RegisterHook("BeforeRun", function(context)
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
function CmdrServiceClient:Start()
	assert(self._serviceBag, "Not initialized")

	self._maid:GivePromise(PromiseUtils.all({
		self:PromiseCmdr(),
		self._maid:GivePromise(self._permissionServiceClient:PromisePermissionProvider())
			:Then(function(provider)
				return provider:PromiseIsAdmin()
			end)
	}))
	:Then(function(cmdr, isAdmin)
		if isAdmin then
			self:_setBindings(cmdr)
		else
			cmdr:SetActivationKeys({})
		end
	end)
end

function CmdrServiceClient:_setBindings(cmdr)
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
function CmdrServiceClient:PromiseCmdr()
	assert(self._serviceBag, "Not initialized")

	if self._cmdrPromise then
		return self._cmdrPromise
	end

	-- Suppress warning in test mode for hoarcekat
	local timeout = nil
	if not RunService:IsRunning() then
		timeout = 1e10
	end

	self._cmdrPromise = self._maid:GivePromise(promiseChild(ReplicatedStorage, "CmdrClient", timeout))
		:Then(function(cmdClient)
			return Promise.spawn(function(resolve, _reject)
				-- Requiring cmdr can yield
				return resolve(require(cmdClient))
			end)
		end)
	self._maid:GiveTask(self._cmdrPromise)

	return self._cmdrPromise
end

function CmdrServiceClient:Destroy()
	self._maid:DoCleaning()
end

return CmdrServiceClient