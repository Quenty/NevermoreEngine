--[=[
	Loads cmdr on the client. See [CmdrService] for the server equivalent.

	@client
	@class CmdrServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Maid = require("Maid")
local PermissionServiceClient = require("PermissionServiceClient")
local Promise = require("Promise")
local promiseChild = require("promiseChild")
local PromiseUtils = require("PromiseUtils")
local String = require("String")

local CmdrServiceClient = {}

--[=[
	Starts the cmdr service on the client. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function CmdrServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
	self._permissionService = self._serviceBag:GetService(PermissionServiceClient)
end

--[=[
	Starts the service. Should be done via [ServiceBag].
]=]
function CmdrServiceClient:Start()
	assert(self._serviceBag, "Not initialized")

	self._maid:GivePromise(PromiseUtils.all({
		self:PromiseCmdr(),
		self._maid:GivePromise(self._permissionService:PromisePermissionProvider())
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

	-- Default blink for debugging purposes
	cmdr.Dispatcher:Run("bind", Enum.KeyCode.G.Name, "blink")
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

	self._cmdrPromise = promiseChild(ReplicatedStorage, "CmdrClient")
		:Then(function(cmdClient)
			return Promise.spawn(function(resolve, _reject)
				-- Requiring cmdr can yield
				return resolve(require(cmdClient))
			end)
		end)
	self._maid:GiveTask(self._cmdrPromise)

	return self._cmdrPromise
end

return CmdrServiceClient