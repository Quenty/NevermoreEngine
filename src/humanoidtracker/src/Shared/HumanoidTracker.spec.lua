--!strict
local require = require(script.Parent.loader).load(script)

local HumanoidTracker = require("HumanoidTracker")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		newPlayer = function(): Player
			return maid:Add(PlayerMock.new())
		end,
		newTracker = function(player: Player): any
			return maid:Add(HumanoidTracker.new(player))
		end,
		newLooseTracker = function(player: Player): any
			return HumanoidTracker.new(player)
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

local function makeDeadRig(): (Model, Humanoid)
	local rig = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 0
	humanoid.Parent = rig
	return rig, humanoid
end

describe("HumanoidTracker.new", function()
	it("errors without a player", function()
		expect(function()
			(HumanoidTracker :: any).new(nil)
		end).toThrow("No player")
	end)

	it("starts empty for a player with no character", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newTracker(player)

		expect(tracker.Humanoid.Value).toBeNil()
		expect(tracker.AliveHumanoid.Value).toBeNil()

		controller:Destroy()
	end)

	it("picks up a humanoid that spawned before the tracker existed", function()
		local controller = setup()

		local player = controller.newPlayer()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		local tracker = controller.newTracker(player)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		expect(tracker.Humanoid.Value).toBe(humanoid)
		expect(tracker.AliveHumanoid.Value).toBe(humanoid)

		controller:Destroy()
	end)
end)

describe("HumanoidTracker spawn lifecycle", function()
	it("tracks the humanoid across spawn, respawn and despawn", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newTracker(player)

		local first = PlayerMock.loadMinimalCharacterAsync(player)
		local firstHumanoid = first:FindFirstChildOfClass("Humanoid")
		expect(tracker.Humanoid.Value).toBe(firstHumanoid)
		expect(tracker.AliveHumanoid.Value).toBe(firstHumanoid)

		local second = PlayerMock.loadMinimalCharacterAsync(player)
		local secondHumanoid = second:FindFirstChildOfClass("Humanoid")
		expect(tracker.Humanoid.Value).toBe(secondHumanoid)
		expect(tracker.AliveHumanoid.Value).toBe(secondHumanoid)

		PlayerMock.removeCharacter(player)
		expect(tracker.Humanoid.Value).toBeNil()
		expect(tracker.AliveHumanoid.Value).toBeNil()

		controller:Destroy()
	end)

	it("waits for a humanoid when the character spawns without one", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newTracker(player)

		local character = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))
		expect(tracker.Humanoid.Value).toBeNil()

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		expect(tracker.Humanoid.Value).toBe(humanoid)

		controller:Destroy()
	end)

	-- Cloud runs never step the humanoid state machine (Died does not fire even at Health=0), so
	-- HumanoidDied and the alive->dead transition are only observable in a live server. These cover
	-- the dead-at-spawn path.
	it("does not consider a dead humanoid alive", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newTracker(player)

		local rig, humanoid = makeDeadRig()
		PlayerMock.loadCharacterAsync(player, rig)

		expect(tracker.Humanoid.Value).toBe(humanoid)
		expect(tracker.AliveHumanoid.Value).toBeNil()

		controller:Destroy()
	end)

	it("clears the alive humanoid when a respawn brings a dead one", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newTracker(player)

		PlayerMock.loadMinimalCharacterAsync(player)
		expect(tracker.AliveHumanoid.Value).never.toBeNil()

		local rig = makeDeadRig()
		PlayerMock.loadCharacterAsync(player, rig)
		expect(tracker.AliveHumanoid.Value).toBeNil()

		controller:Destroy()
	end)
end)

describe("HumanoidTracker.PromiseNextHumanoid", function()
	it("resolves immediately when a humanoid is already tracked", function()
		local controller = setup()

		local player = controller.newPlayer()
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		local tracker = controller.newTracker(player)

		local promise = tracker:PromiseNextHumanoid()
		expect(promise:IsFulfilled()).toBe(true)

		local isFulfilled, humanoid = promise:Yield()
		expect(isFulfilled).toBe(true)
		expect(humanoid).toBe(character:FindFirstChildOfClass("Humanoid"))

		controller:Destroy()
	end)

	it("resolves when the next humanoid appears", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newTracker(player)

		local promise = tracker:PromiseNextHumanoid()
		expect(promise:IsPending()).toBe(true)

		local character = PlayerMock.loadMinimalCharacterAsync(player)

		local isFulfilled, humanoid = promise:Yield()
		expect(isFulfilled).toBe(true)
		expect(humanoid).toBe(character:FindFirstChildOfClass("Humanoid"))

		controller:Destroy()
	end)

	it("reuses the pending promise across calls", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newTracker(player)

		expect(tracker:PromiseNextHumanoid()).toBe(tracker:PromiseNextHumanoid())

		controller:Destroy()
	end)

	it("rejects the pending promise when the tracker is destroyed", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newLooseTracker(player)

		local promise = tracker:PromiseNextHumanoid()
		tracker:Destroy()

		expect(promise:IsRejected()).toBe(true)

		controller:Destroy()
	end)
end)

describe("HumanoidTracker.Destroy", function()
	it("stops tracking after destroy", function()
		local controller = setup()

		local player = controller.newPlayer()
		local tracker = controller.newLooseTracker(player)
		tracker:Destroy()

		expect(function()
			PlayerMock.loadMinimalCharacterAsync(player)
		end).never.toThrow()

		controller:Destroy()
	end)
end)
