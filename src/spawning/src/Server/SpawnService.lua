--[=[
	Handles spawning stuff in the game
	@class SpawnService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local RandomUtils = require("RandomUtils")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local UPDATE_PERIOD_SEC = 5
local SPAWN_AFTER_GAME_START = 1
local MAX_BUDGET_PER_CLASS = 0.05
local WARN_ON_CLASS_BUDGET_EXHAUST = false
local TOTAL_BUDGET_BEFORE_WARN = 0.1

local SpawnService = {}
SpawnService.ServiceName = "SpawnService"

function SpawnService:Init(serviceBag: _ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._spawnBinderGroupsServer = self._serviceBag:GetService(require("SpawnBinderGroupsServer"))
	self._serviceBag:GetService(require("SpawnCmdrService"))
end

function SpawnService:Start()
	local lastUpdateTime = (os.clock() - UPDATE_PERIOD_SEC + SPAWN_AFTER_GAME_START)

	-- TODO: Smear across update pipeline
	self._maid:GiveTask(RunService.Stepped:Connect(function()
		if (lastUpdateTime + UPDATE_PERIOD_SEC) <= os.clock() then
			lastUpdateTime = os.clock()
			self:Update()
		end
	end))
end

function SpawnService:AddSpawnerBinder(spawnerBinder)
	self._spawnBinderGroupsServer.Spawners:Add(spawnerBinder)
end

function SpawnService:Regenerate()
	local startTime = os.clock()

	for _, binder in self._spawnBinderGroupsServer.Spawners:GetBinders() do
		for _, spawner in binder:GetAll() do
			spawner:Regenerate()
		end
	end

	if (os.clock() - startTime) >= 0.05 then
		warn(string.format("SpawnService regenerate time: %0.4f ms", (os.clock() - startTime) * 1000))
	end
end

function SpawnService:Update()
	debug.profilebegin("spawnService")

	local startTime = os.clock()
	local spawnerCount = 0

	for _, binder in self._spawnBinderGroupsServer.Spawners:GetBinders() do
		local classStartTime = os.clock()
		local classes = RandomUtils.shuffledCopy(binder:GetAll())

		for _, spawner in classes do
			spawnerCount = spawnerCount + 1
			spawner:SpawnUpdate(false)

			if (os.clock() - classStartTime) >= MAX_BUDGET_PER_CLASS then
				if WARN_ON_CLASS_BUDGET_EXHAUST then
					warn(string.format("[SpawnService.Update] - Class %q ran out of execution budget at %0.4f ms", binder:GetTag(), (os.clock() - classStartTime)*1000))
				end
				break
			end
		end
	end

	-- watch dog
	if (os.clock() - startTime) >= TOTAL_BUDGET_BEFORE_WARN then
		warn(string.format("[SpawnService.Update] - Update time: %0.4f ms for %d spawners", (os.clock() - startTime)*1000, spawnerCount))
	end

	debug.profileend()
end

function SpawnService:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
end

return SpawnService