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

	local guid = prefix .. " " .. HttpService:GenerateGUID(false)
	local maid = Maid.new()

	local gameDataStore = serviceBag:GetService(require(packages.GameDataStoreService))
	local bindToCloseService = serviceBag:GetService(require(packages.BindToCloseService))

	-- This would be an aggressive usage of this area, it probably won't scale well enough.
	-- But writing some shared code or something like API keys should scale fine.
	maid:GivePromise(gameDataStore:PromiseDataStore()):Then(function(dataStore)
		local substore = dataStore:GetSubStore("AliveServers")
		substore:Store(guid, true)

		-- maid:GiveTask(substore:Observe():Subscribe(function(data)
		-- 	print(string.format("(%s) dataStore.AliveServers:Observe()", prefix), data)
		-- end))

		if prefix == "blue" then
			dataStore:SetDoDebugWriting(true)
			dataStore:SetSyncOnSave(true)
			dataStore:SetAutoSaveTimeSeconds(3)

			maid:GiveTask(dataStore:Observe():Subscribe(function(viewSnapshot)
				print(string.format("(%s) dataStore:Observe()", prefix), viewSnapshot)
			end))
		else
			-- dataStore:SetDoDebugWriting(true)
			dataStore:SetSyncOnSave(false)
			dataStore:SetAutoSaveTimeSeconds(nil)
			dataStore:Save()

			task.delay(5, function()
				warn("Red is wiping data")

				substore:Wipe()
				dataStore:Save()

				task.delay(5, function()
					warn("Red is adding substore data")

					substore:Store(guid, {
						playerCount = 5;
						startTime = DateTime.now().UnixTimestamp
					})
					dataStore:Save()
				end)
			end)
		end

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

spinUpGameCopy("red")
spinUpGameCopy("blue")