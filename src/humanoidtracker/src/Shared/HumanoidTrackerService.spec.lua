--!strict
local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local HumanoidTrackerService = require("HumanoidTrackerService")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local afterEach = Jest.Globals.afterEach
local beforeEach = Jest.Globals.beforeEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local maid

beforeEach(function()
	maid = Maid.new()
end)

afterEach(function()
	maid:DoCleaning()
end)

local function makeService(): any
	local serviceBag = maid:Add(ServiceBag.new())
	local service = serviceBag:GetService(HumanoidTrackerService)
	serviceBag:Init()
	serviceBag:Start()
	return service
end

describe("HumanoidTrackerService.GetHumanoidTracker", function()
	it("returns and caches a tracker per player", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())
		local otherPlayer = maid:Add(PlayerMock.new())

		local tracker = service:GetHumanoidTracker(player)
		expect(tracker).never.toBeNil()
		expect(service:GetHumanoidTracker(player)).toBe(tracker)
		expect(service:GetHumanoidTracker(otherPlayer)).never.toBe(tracker)
	end)

	it("rejects a non-player value", function()
		local service = makeService()

		expect(function()
			service:GetHumanoidTracker(5)
		end).toThrow("Bad player")
	end)
end)

describe("HumanoidTrackerService.GetHumanoid", function()
	it("returns the current humanoid once spawned", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())

		expect(service:GetHumanoid(player)).toBeNil()

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(service:GetHumanoid(player)).toBe(character:FindFirstChildOfClass("Humanoid"))
	end)
end)

describe("HumanoidTrackerService.GetAliveHumanoid", function()
	it("returns the humanoid only while it is alive", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(service:GetAliveHumanoid(player)).toBe(character:FindFirstChildOfClass("Humanoid"))

		PlayerMock.removeCharacter(player)
		expect(service:GetAliveHumanoid(player)).toBeNil()
	end)

	it("does not report a dead humanoid as alive", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())

		local rig = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.Health = 0
		humanoid.Parent = rig
		PlayerMock.loadCharacterAsync(player, rig)

		expect(service:GetHumanoid(player)).toBe(humanoid)
		expect(service:GetAliveHumanoid(player)).toBeNil()
	end)
end)

describe("HumanoidTrackerService.ObserveHumanoid", function()
	it("observes the humanoid across the spawn lifecycle", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())

		local emissions = 0
		local lastValue = nil
		maid:GiveTask(service:ObserveHumanoid(player):Subscribe(function(value)
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
	end)
end)

describe("HumanoidTrackerService.ObserveHumanoidBrio", function()
	it("emits a living brio per humanoid and kills it on despawn", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())

		local brios: { Brio.Brio<Humanoid> } = {}
		maid:GiveTask(service:ObserveHumanoidBrio(player):Subscribe(function(brio)
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
	end)
end)

describe("HumanoidTrackerService.ObserveAliveHumanoid", function()
	it("observes only living humanoids", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())

		local emissions = 0
		local lastValue = nil
		maid:GiveTask(service:ObserveAliveHumanoid(player):Subscribe(function(value)
			emissions += 1
			lastValue = value
		end))

		expect(emissions).toBe(1)
		expect(lastValue).toBeNil()

		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(emissions).toBe(2)
		expect(lastValue).toBe(character:FindFirstChildOfClass("Humanoid"))
	end)
end)

describe("HumanoidTrackerService.ObserveAliveHumanoidBrio", function()
	it("kills the alive brio on despawn", function()
		local service = makeService()
		local player = maid:Add(PlayerMock.new())

		local brios: { Brio.Brio<Humanoid> } = {}
		maid:GiveTask(service:ObserveAliveHumanoidBrio(player):Subscribe(function(brio)
			table.insert(brios, brio)
		end))

		PlayerMock.loadMinimalCharacterAsync(player)
		expect(#brios).toBe(1)
		expect(brios[1]:IsDead()).toBe(false)

		PlayerMock.removeCharacter(player)
		expect(brios[1]:IsDead()).toBe(true)
	end)
end)

describe("HumanoidTrackerService.Destroy", function()
	it("destroys its trackers on teardown", function()
		local player = maid:Add(PlayerMock.new())

		local teardownMaid = Maid.new()
		local serviceBag = teardownMaid:Add(ServiceBag.new())
		local service: any = serviceBag:GetService(HumanoidTrackerService)
		serviceBag:Init()
		serviceBag:Start()

		local tracker = service:GetHumanoidTracker(player)
		teardownMaid:DoCleaning()

		expect((tracker :: any).Destroy).toBeNil()
	end)
end)
