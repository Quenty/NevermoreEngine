--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.datastore)

local Maid = require(packages.Maid)
local Promise = require(packages.Promise)

local function spinUpGameCopy(prefix)
	assert(type(prefix) == "string", "Bad prefix")

	local serviceBag = require(packages.ServiceBag).new()
	serviceBag:GetService(require(packages.GameDataStoreService))
	serviceBag:GetService(require(packages.PlayerDataStoreService))

	serviceBag:Init()
	serviceBag:Start()

	local guid = prefix .. "_" .. HttpService:GenerateGUID(false)
	local maid = Maid.new()

	local gameDataStore = serviceBag:GetService(require(packages.GameDataStoreService))
	local bindToCloseService = serviceBag:GetService(require(packages.BindToCloseService))

	-- This would be an aggressive usage of this area, it probably won't scale well enough.
	-- But writing some shared code or something like API keys should scale fine.
	maid:GivePromise(gameDataStore:PromiseDataStore()):Then(function(dataStore)
		-- dataStore:SetDoDebugWriting(true)

		local substore = dataStore:GetSubStore("AliveServers")
		substore:Store(guid, true)

		-- maid:GiveTask(substore:Observe():Subscribe(function(data)
		-- 	print(prefix, "Changed", data)
		-- end))

		maid:GiveTask(dataStore.Changed:Connect(function(viewSnapshot)
			print(string.format("(%s) dataStore.Changed", prefix), viewSnapshot)
		end))

		maid:GiveTask(dataStore:Observe():Subscribe(function(viewSnapshot)
			print(string.format("(%s) dataStore:Observe()", prefix), viewSnapshot)
			-- print(string.format("[%s][Observe] - Alive servers", prefix), value)
		end))

		-- dataStore:LoadAll():Then(function(data)
		-- 	-- print(string.format("[%s][LoadAll] - Load all", prefix), data)
		-- end)

		-- local entrySubstore = substore:GetSubStore(guid)
		-- entrySubstore:LoadAll():Then(function(data)
		-- 	-- print(string.format("[%s][SUBSTORE][LoadAll] Loaded substore", prefix), data)
		-- end)

		-- entrySubstore:Overwrite(os.clock())

		maid:GiveTask(bindToCloseService:RegisterPromiseOnCloseCallback(function()
			substore:Delete(guid)
			return Promise.resolved()
		end))

	end)

	return maid
end

spinUpGameCopy("quenty")
spinUpGameCopy("martxn")