--!strict
local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Brio = require("Brio")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local RxCharacterUtils = require("RxCharacterUtils")

local afterAll = Jest.Globals.afterAll
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a rig with one tracked descendant part. Rigs are per-spawn: despawning destroys the
-- character model (engine semantics), so a rig never comes back once removed.
local function makeRig(): (Model, Part)
	local rig = Instance.new("Model")
	local part = Instance.new("Part")
	part.Parent = rig
	return rig, part
end

local function setup()
	local player = PlayerMock.new()
	player.Parent = workspace -- setMockedLocalPlayer requires a parented mock
	PlayerMock.setMockedLocalPlayer(player)

	local function cleanup()
		if PlayerMock.getMockedLocalPlayer() == player then
			PlayerMock.setMockedLocalPlayer(nil)
		end
		player:Destroy() -- also removes any loaded character, like a player leaving
	end

	return player, cleanup
end

describe("RxCharacterUtils.observeIsOfLocalCharacter", function()
	local maid = Maid.new()
	local player, cleanupMock = setup()

	local firstRig, firstChildPart = makeRig()
	local secondRig, secondChildPart = makeRig()
	local unrelatedPart = Instance.new("Part")

	local firstChildValue = nil
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacter(firstChildPart):Subscribe(function(value)
		firstChildValue = value
	end))

	local firstRigValue = nil
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacter(firstRig):Subscribe(function(value)
		firstRigValue = value
	end))

	local secondChildValue = nil
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacter(secondChildPart):Subscribe(function(value)
		secondChildValue = value
	end))

	local unrelatedValue = nil
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacter(unrelatedPart):Subscribe(function(value)
		unrelatedValue = value
	end))

	afterAll(function()
		maid:Destroy()
		cleanupMock()
		unrelatedPart:Destroy()
	end)

	it("should initially emit false for all instances when no character is spawned", function()
		expect(firstChildValue).toEqual(false)
		expect(firstRigValue).toEqual(false)
		expect(unrelatedValue).toEqual(false)
	end)

	it("should emit true for the character and its descendant on spawn", function()
		PlayerMock.loadCharacterAsync(player, firstRig)
		expect(firstChildValue).toEqual(true)
		expect(firstRigValue).toEqual(true)
	end)

	it("should still emit false for instances outside the character", function()
		expect(unrelatedValue).toEqual(false)
		expect(secondChildValue).toEqual(false)
	end)

	it("should flip membership to the new character's parts on respawn", function()
		PlayerMock.loadCharacterAsync(player, secondRig)
		-- The old rig was destroyed with the respawn; its parts are never of the character again
		expect(firstChildValue).toEqual(false)
		expect(firstRigValue).toEqual(false)
		expect(secondChildValue).toEqual(true)
	end)

	it("should emit false for everything on despawn", function()
		PlayerMock.removeCharacter(player)
		expect(secondChildValue).toEqual(false)
		expect(unrelatedValue).toEqual(false)
	end)
end)

describe("RxCharacterUtils.observeIsOfLocalCharacterBrio", function()
	local maid = Maid.new()
	local player, cleanupMock = setup()

	local firstRig, firstChildPart = makeRig()
	local secondRig, secondChildPart = makeRig()
	local unrelatedPart = Instance.new("Part")

	local firstChildBrios = {}
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacterBrio(firstChildPart):Subscribe(function(brio)
		table.insert(firstChildBrios, brio)
	end))

	local secondChildBrios = {}
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacterBrio(secondChildPart):Subscribe(function(brio)
		table.insert(secondChildBrios, brio)
	end))

	local unrelatedBrioCount = 0
	maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacterBrio(unrelatedPart):Subscribe(function(_brio)
		unrelatedBrioCount += 1
	end))

	local cleanupTestBrio = nil
	local cleanupSub = RxCharacterUtils.observeIsOfLocalCharacterBrio(firstChildPart):Subscribe(function(brio)
		cleanupTestBrio = brio
	end)

	afterAll(function()
		maid:Destroy()
		cleanupSub:Destroy()
		cleanupMock()
		unrelatedPart:Destroy()
	end)

	it("should not emit any brio before a spawn", function()
		expect(#firstChildBrios).toEqual(0)
		expect(unrelatedBrioCount).toEqual(0)
	end)

	it("should emit a living brio for a descendant of the spawned character", function()
		PlayerMock.loadCharacterAsync(player, firstRig)
		expect(#firstChildBrios).toEqual(1)
		expect(Brio.isBrio(firstChildBrios[1])).toEqual(true)
		expect(firstChildBrios[1]:IsDead()).toEqual(false)
		expect(firstChildBrios[1]:GetValue()).toEqual(true)
	end)

	it("should not emit a brio for instances outside the character", function()
		expect(unrelatedBrioCount).toEqual(0)
		expect(#secondChildBrios).toEqual(0)
	end)

	it("should kill the brio when its subscription is destroyed", function()
		expect(cleanupTestBrio).never.toBeNil()
		expect(cleanupTestBrio:IsDead()).toEqual(false)
		local brioRef = cleanupTestBrio
		cleanupSub:Destroy()
		expect(brioRef:IsDead()).toEqual(true)
	end)

	it("should kill the old part's brio and emit for the new part on respawn", function()
		PlayerMock.loadCharacterAsync(player, secondRig)
		expect(firstChildBrios[1]:IsDead()).toEqual(true)
		expect(#firstChildBrios).toEqual(1) -- the destroyed rig's part never revives
		expect(#secondChildBrios).toEqual(1)
		expect(secondChildBrios[1]:IsDead()).toEqual(false)
		expect(secondChildBrios[1]:GetValue()).toEqual(true)
	end)

	it("should kill the brio on despawn", function()
		PlayerMock.removeCharacter(player)
		expect(secondChildBrios[1]:IsDead()).toEqual(true)
		expect(#secondChildBrios).toEqual(1)
	end)
end)

describe("RxCharacterUtils.observeCharacterBrio through the spawn lifecycle", function()
	local maid = Maid.new()
	local player = PlayerMock.new()

	local brios = {}
	maid:GiveTask(RxCharacterUtils.observeCharacterBrio(player):Subscribe(function(brio)
		table.insert(brios, brio)
	end))

	afterAll(function()
		maid:Destroy()
		PlayerMock.removeCharacter(player)
		player:Destroy()
	end)

	it("emits nothing before the first spawn", function()
		expect(#brios).toBe(0)
	end)

	it("emits a living brio holding the character on spawn", function()
		local rig = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))
		expect(#brios).toBe(1)
		expect(brios[1]:IsDead()).toBe(false)
		expect(brios[1]:GetValue()).toBe(rig)
	end)

	it("kills the old brio and emits a new one on respawn", function()
		local rig = PlayerMock.loadCharacterAsync(player, Instance.new("Model"))
		expect(brios[1]:IsDead()).toBe(true)
		expect(#brios).toBe(2)
		expect(brios[2]:IsDead()).toBe(false)
		expect(brios[2]:GetValue()).toBe(rig)
	end)

	it("kills the brio with no replacement when the character despawns", function()
		PlayerMock.removeCharacter(player)
		expect(brios[2]:IsDead()).toBe(true)
		expect(#brios).toBe(2)
	end)
end)

describe("RxCharacterUtils.observeLastHumanoidBrio across respawns with real rigs", function()
	local maid = Maid.new()
	local player = PlayerMock.new()

	local humanoidBrios = {}
	maid:GiveTask(RxCharacterUtils.observeLastHumanoidBrio(player):Subscribe(function(brio)
		table.insert(humanoidBrios, brio)
	end))

	afterAll(function()
		maid:Destroy()
		PlayerMock.removeCharacter(player)
		player:Destroy()
	end)

	it("emits the humanoid of an engine-built default R15 rig", function()
		local rig = PlayerMock.loadCharacterAsync(player)
		expect(#humanoidBrios).toBe(1)
		expect(humanoidBrios[1]:IsDead()).toBe(false)
		expect(humanoidBrios[1]:GetValue()).toBe(rig:FindFirstChildOfClass("Humanoid"))
	end)

	it("swaps to the humanoid of a real avatar appearance on respawn", function()
		-- Real appearance fetch by userId; verified to work in Open Cloud test runs
		local rig = Players:CreateHumanoidModelFromUserId(261)
		PlayerMock.loadCharacterAsync(player, rig)

		expect(humanoidBrios[1]:IsDead()).toBe(true)
		expect(#humanoidBrios).toBe(2)
		expect(humanoidBrios[2]:GetValue()).toBe(rig:FindFirstChildOfClass("Humanoid"))
	end)

	it("kills the humanoid brio when the character despawns", function()
		PlayerMock.removeCharacter(player)
		expect(humanoidBrios[2]:IsDead()).toBe(true)
	end)
end)

describe("RxCharacterUtils.observeLastAliveHumanoidBrio", function()
	-- Cloud runs never step the humanoid state machine (Humanoid.Died does not fire even at
	-- Health=0), so the engine-fired Died->brio-death transition is only observable in a live
	-- server. These cover the alive path, the dead-at-subscribe path, and death-by-respawn.

	it("emits a living brio for a spawned humanoid with health", function()
		local player = PlayerMock.new()
		PlayerMock.loadCharacterAsync(player)

		local brios = {}
		local sub = RxCharacterUtils.observeLastAliveHumanoidBrio(player):Subscribe(function(brio)
			table.insert(brios, brio)
		end)

		expect(#brios).toBe(1)
		expect(brios[1]:IsDead()).toBe(false)

		sub:Destroy()
		PlayerMock.removeCharacter(player)
		player:Destroy()
	end)

	it("emits nothing when the humanoid is already dead at subscribe", function()
		local player = PlayerMock.new()
		local rig = PlayerMock.loadCharacterAsync(player)
		local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0

		local count = 0
		local sub = RxCharacterUtils.observeLastAliveHumanoidBrio(player):Subscribe(function()
			count += 1
		end)

		expect(count).toBe(0)

		sub:Destroy()
		PlayerMock.removeCharacter(player)
		player:Destroy()
	end)

	it("kills the alive brio when the player respawns", function()
		local player = PlayerMock.new()
		PlayerMock.loadCharacterAsync(player)

		local brios = {}
		local sub = RxCharacterUtils.observeLastAliveHumanoidBrio(player):Subscribe(function(brio)
			table.insert(brios, brio)
		end)
		expect(#brios).toBe(1)

		PlayerMock.loadCharacterAsync(player)
		expect(brios[1]:IsDead()).toBe(true)
		expect(#brios).toBe(2)

		sub:Destroy()
		PlayerMock.removeCharacter(player)
		player:Destroy()
	end)
end)
