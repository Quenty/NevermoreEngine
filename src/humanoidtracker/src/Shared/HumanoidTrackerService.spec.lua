--!strict
local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local HumanoidTrackerService = require("HumanoidTrackerService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		maid = maid,
		newPlayer = function(): Player
			return maid:Add(PlayerMock.new())
		end,
		newService = function(): any
			local serviceBag = maid:Add(ServiceBag.new())
			local service = serviceBag:GetService(HumanoidTrackerService)
			serviceBag:Init()
			serviceBag:Start()
			return service
		end,
		newLooseService = function(): (any, any)
			local serviceBag = ServiceBag.new()
			local service = serviceBag:GetService(HumanoidTrackerService)
			serviceBag:Init()
			serviceBag:Start()
			return serviceBag, service
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("HumanoidTrackerService.GetHumanoidTracker", function()
	it("returns and caches a tracker per player", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()
		local otherPlayer = controller.newPlayer()

		local tracker = service:GetHumanoidTracker(player)
		expect(tracker).never.toBeNil()
		expect(service:GetHumanoidTracker(player)).toBe(tracker)
		expect(service:GetHumanoidTracker(otherPlayer)).never.toBe(tracker)

		controller.destroy()
	end)

	it("rejects a non-player value", function()
		local controller = setup()

		local service = controller.newService()

		expect(function()
			service:GetHumanoidTracker(5)
		end).toThrow("Bad player")

		controller.destroy()
	end)
end)

describe("HumanoidTrackerService.GetHumanoid", function()
	it("returns the current humanoid once spawned", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()

		expect(service:GetHumanoid(player)).toBeNil()

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(service:GetHumanoid(player)).toBe(character:FindFirstChildOfClass("Humanoid"))

		controller.destroy()
	end)
end)

describe("HumanoidTrackerService.GetAliveHumanoid", function()
	it("returns the humanoid only while it is alive", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(service:GetAliveHumanoid(player)).toBe(character:FindFirstChildOfClass("Humanoid"))

		PlayerMock.removeCharacter(player)
		expect(service:GetAliveHumanoid(player)).toBeNil()

		controller.destroy()
	end)

	it("does not report a dead humanoid as alive", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()

		local rig = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.Health = 0
		humanoid.Parent = rig
		PlayerMock.loadCharacterAsync(player, rig)

		expect(service:GetHumanoid(player)).toBe(humanoid)
		expect(service:GetAliveHumanoid(player)).toBeNil()

		controller.destroy()
	end)
end)

describe("HumanoidTrackerService.ObserveHumanoid", function()
	it("observes the humanoid across the spawn lifecycle", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()

		local emissions = 0
		local lastValue = nil
		controller.maid:GiveTask(service:ObserveHumanoid(player):Subscribe(function(value)
			emissions += 1
			lastValue = value
		end))

		expect(emissions).toBe(1)
		expect(lastValue).toBeNil()

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(emissions).toBe(2)
		expect(lastValue).toBe(character:FindFirstChildOfClass("Humanoid"))

		PlayerMock.removeCharacter(player)
		expect(emissions).toBe(3)
		expect(lastValue).toBeNil()

		controller.destroy()
	end)
end)

describe("HumanoidTrackerService.ObserveHumanoidBrio", function()
	it("emits a living brio per humanoid and kills it on despawn", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()

		local brios: { Brio.Brio<Humanoid> } = {}
		controller.maid:GiveTask(service:ObserveHumanoidBrio(player):Subscribe(function(brio)
			table.insert(brios, brio)
		end))

		expect(#brios).toBe(0)

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(#brios).toBe(1)
		expect(Brio.isBrio(brios[1])).toBe(true)
		expect(brios[1]:IsDead()).toBe(false)
		expect(brios[1]:GetValue()).toBe(character:FindFirstChildOfClass("Humanoid"))

		PlayerMock.removeCharacter(player)
		expect(brios[1]:IsDead()).toBe(true)
		expect(#brios).toBe(1)

		controller.destroy()
	end)
end)

describe("HumanoidTrackerService.ObserveAliveHumanoid", function()
	it("observes only living humanoids", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()

		local emissions = 0
		local lastValue = nil
		controller.maid:GiveTask(service:ObserveAliveHumanoid(player):Subscribe(function(value)
			emissions += 1
			lastValue = value
		end))

		expect(emissions).toBe(1)
		expect(lastValue).toBeNil()

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(emissions).toBe(2)
		expect(lastValue).toBe(character:FindFirstChildOfClass("Humanoid"))

		controller.destroy()
	end)
end)

describe("HumanoidTrackerService.ObserveAliveHumanoidBrio", function()
	it("kills the alive brio on despawn", function()
		local controller = setup()

		local service = controller.newService()
		local player = controller.newPlayer()

		local brios: { Brio.Brio<Humanoid> } = {}
		controller.maid:GiveTask(service:ObserveAliveHumanoidBrio(player):Subscribe(function(brio)
			table.insert(brios, brio)
		end))

		PlayerMock.loadMinimalCharacterAsync(player)
		expect(#brios).toBe(1)
		expect(brios[1]:IsDead()).toBe(false)

		PlayerMock.removeCharacter(player)
		expect(brios[1]:IsDead()).toBe(true)

		controller.destroy()
	end)
end)

describe("HumanoidTrackerService.Destroy", function()
	it("destroys its trackers on teardown", function()
		local controller = setup()

		local player = controller.newPlayer()

		local serviceBag, service = controller.newLooseService()

		local tracker = service:GetHumanoidTracker(player)
		serviceBag:Destroy()

		expect((tracker :: any).Destroy).toBeNil()

		controller.destroy()
	end)
end)
