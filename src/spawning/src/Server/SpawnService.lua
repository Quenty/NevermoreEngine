--[=[
	Handles spawning stuff in the game
	@class SpawnService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local RandomUtils = require("RandomUtils")
local Maid = require("Maid")

local UPDATE_PERIOD_SEC = 5
local SPAWN_AFTER_GAME_START = 1
local MAX_BUDGET_PER_CLASS = 0.05
local WARN_ON_CLASS_BUDGET_EXHAUST = false
local TOTAL_BUDGET_BEFORE_WARN = 0.1

local SpawnService = {}

function SpawnService:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._spawnBinderGroupsServer = self._serviceBag:GetService(require("SpawnBinderGroupsServer"))
	self._serviceBag:GetService(require("SpawnCmdrService"))
end

function SpawnService:Start()
	local lastUpdateTime = (tick() - UPDATE_PERIOD_SEC + SPAWN_AFTER_GAME_START)

	-- TODO: Smear across update pipeline
	self._maid:GiveTask(RunService.Stepped:Connect(function()
		if (lastUpdateTime + UPDATE_PERIOD_SEC) <= tick() then
			lastUpdateTime = tick()
			self:Update()
		end
	end))
end

function SpawnService:AddSpawnerBinder(spawnerBinder)
	self._spawnBinderGroupsServer.Spawners:Add(spawnerBinder)
end

function SpawnService:Regenerate()
	local startTime = tick()

	for _, binder in pairs(self._spawnBinderGroupsServer.Spawners:GetBinders()) do
		for _, spawner in pairs(binder:GetAll()) do
			spawner:Regenerate()
		end
	end

	if (tick() - startTime) >= 0.05 then
		warn(("SpawnService regenerate time: %0.4f ms"):format((tick() - startTime)*1000))
	end
end

function SpawnService:Update()
	debug.profilebegin("spawnService")

	local startTime = tick()
	local spawnerCount = 0

	for _, binder in pairs(self._spawnBinderGroupsServer.Spawners:GetBinders()) do
		local classStartTime = tick()
		local classes = RandomUtils.shuffledCopy(binder:GetAll())

		for _, spawner in pairs(classes) do
			spawnerCount = spawnerCount + 1
			spawner:SpawnUpdate(false)

			if (tick() - classStartTime) >= MAX_BUDGET_PER_CLASS then
				if WARN_ON_CLASS_BUDGET_EXHAUST then
					warn(("[SpawnService.Update] - Class %q ran out of execution budget at %0.4f ms")
						:format(binder:GetTag(), (tick() - classStartTime)*1000))
				end
				break
			end
		end
	end

	-- watch dog
	if (tick() - startTime) >= TOTAL_BUDGET_BEFORE_WARN then
		warn(("[SpawnService.Update] - Update time: %0.4f ms for %d spawners")
			:format((tick() - startTime)*1000, spawnerCount))
	end

	debug.profileend()
end

function SpawnService:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
end

return SpawnService