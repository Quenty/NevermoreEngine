--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.datastore)

local Maid = require(packages.Maid)
local Promise = require(packages.Promise)

local function spinUpGameCopy()
	local serviceBag = require(packages.ServiceBag).new()
	serviceBag:GetService(require(packages.GameDataStoreService))
	serviceBag:GetService(require(packages.PlayerDataStoreService))

	serviceBag:Init()
	serviceBag:Start()

	local guid = HttpService:GenerateGUID(false)
	local maid = Maid.new()

	local gameDataStore = serviceBag:GetService(require(packages.GameDataStoreService))
	local bindToCloseService = serviceBag:GetService(require(packages.BindToCloseService))

	maid:GivePromise(gameDataStore:PromiseDataStore()):Then(function(dataStore)
		local substore = dataStore:GetSubStore("AliveServers")
		substore:Store(guid, {
			CreateTime = DateTime.now().UnixTimestamp;
		})

		dataStore:LoadAll():Then(function(data)
			print(data)
		end)

		maid:GiveTask(bindToCloseService:RegisterPromiseOnCloseCallback(function()
			substore:Delete(guid)
			return Promise.resolved()
		end))

		maid:GiveTask(dataStore:Observe("AliveServers", {}):Subscribe(function(value)
			print("[Observe] - Alive servers", value)
		end))
	end)

	return maid
end

spinUpGameCopy()
spinUpGameCopy()