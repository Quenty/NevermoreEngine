--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.datastore)

local Maid = require(packages.Maid)
local Promise = require(packages.Promise)

local TURN_TIME = 8

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

		-- maid:GiveTask(dataStore:Observe():Subscribe(function(viewSnapshot)
		-- 	print(string.format("(%s) dataStore:Observe()", prefix), viewSnapshot)
		-- end))

		if prefix == "blue" then
			-- dataStore:SetDoDebugWriting(true)
			dataStore:SetSyncOnSave(true)
			dataStore:SetAutoSaveTimeSeconds(4)

			-- maid:GiveTask(dataStore:Observe():Subscribe(function(viewSnapshot)
			-- 	print(string.format("(%s) dataStore:Observe()", prefix), viewSnapshot)
			-- end))

			task.delay(4*TURN_TIME, function()
				warn("Blue server is restoring data")

				substore:Store(guid, true)
			end)
		elseif prefix == "red" then
			warn(string.format("%s server is storing data", prefix))

			-- dataStore:SetDoDebugWriting(true)
			dataStore:SetSyncOnSave(true)
			dataStore:SetAutoSaveTimeSeconds(4)
			-- dataStore:Save()

			task.delay(TURN_TIME, function()
				warn(string.format("%s server is wiping data", prefix))

				substore:Wipe()
				-- dataStore:Save()

				task.delay(TURN_TIME, function()
					warn(string.format("%s server is adding substore data", prefix))

					substore:Store(guid, {
						playerCount = 5;
						startTime = DateTime.now().UnixTimestamp
					})
					-- dataStore:Save()

					task.delay(TURN_TIME, function()
						warn(string.format("%s server is changing player count", prefix))
						local guidStore = substore:GetSubStore(guid)
						guidStore:Store("playerCount", 25)
						-- dataStore:Save()
					end)
				end)
			end)
		end

		-- TODO: Update some random numbers every second for a while....

		-- TODO: Force saving twice

		maid:GiveTask(dataStore:Observe():Subscribe(function(viewSnapshot)
			print(string.format("(%s) dataStore:Observe()", prefix), viewSnapshot)
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

spinUpGameCopy("red")
spinUpGameCopy("blue")
spinUpGameCopy("green")