--!strict
local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local RxBrioTestUtils = require("RxBrioTestUtils")
local RxPlayerUtils = require("RxPlayerUtils")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local TEST_USER_ID = 8675309

local function isTestPlayer(player: Player): boolean
	return PlayerMock.isMock(player) and PlayerMock.read(player, "UserId") == TEST_USER_ID
end

local function setup(): any
	local maid = Maid.new()

	local controller = {
		newPlayer = function(overrides: { [string]: any }?): Player
			local player = PlayerMock.new(overrides or { UserId = TEST_USER_ID })
			player.Parent = Players
			maid:GiveTask(player)
			return player
		end,
		designateLocalPlayer = function(player: Player?)
			maid:GiveTask(PlayerMock.setMockedLocalPlayer(player))
		end,
		maid = maid,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxPlayerUtils.observePlayers", function()
	it("emits a mock that is already in the game", function()
		local controller = setup()

		local player = controller.newPlayer()
		local players = RxTestUtils.collectList(controller.maid, RxPlayerUtils.observePlayers())

		expect(#players >= 1).toBe(true)
		expect(players).toContain(player)

		controller:Destroy()
	end)

	it("emits a mock that joins after subscribing", function()
		local controller = setup()

		local players = RxTestUtils.collectList(controller.maid, RxPlayerUtils.observePlayers())
		local player = controller.newPlayer()

		expect(#players >= 1).toBe(true)
		expect(players).toContain(player)

		controller:Destroy()
	end)

	it("skips mocks the predicate rejects", function()
		local controller = setup()

		local rejected = controller.newPlayer({ UserId = TEST_USER_ID + 1 })
		local accepted = controller.newPlayer()
		local players = RxTestUtils.collectList(controller.maid, RxPlayerUtils.observePlayers(isTestPlayer))

		expect(#players >= 1).toBe(true)
		expect(players).toContain(accepted)
		expect(players).never.toContain(rejected)

		controller:Destroy()
	end)
end)

describe("RxPlayerUtils.observePlayersBrio", function()
	it("emits a living brio for a mock already in the game", function()
		local controller = setup()

		local player = controller.newPlayer()
		local alivePlayers =
			RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observePlayersBrio(isTestPlayer))

		expect(alivePlayers).toContain(player)

		controller:Destroy()
	end)

	it("emits a living brio for a mock that joins after subscribing", function()
		local controller = setup()

		local alivePlayers =
			RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observePlayersBrio(isTestPlayer))
		local player = controller.newPlayer()

		expect(alivePlayers).toContain(player)

		controller:Destroy()
	end)

	it("kills the brio when the mock is destroyed", function()
		local controller = setup()

		local player = controller.newPlayer()
		local alivePlayers =
			RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observePlayersBrio(isTestPlayer))

		expect(alivePlayers).toContain(player)
		player:Destroy()

		expect(alivePlayers).never.toContain(player)

		controller:Destroy()
	end)

	it("kills the brio when the mock is kicked", function()
		local controller = setup()

		local player = controller.newPlayer()
		local alivePlayers =
			RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observePlayersBrio(isTestPlayer))

		expect(alivePlayers).toContain(player)
		-- A kick unparents rather than destroys, which is what drops the mock out of the game
		PlayerMock.kick(player, "Kicked by a test")

		expect(alivePlayers).never.toContain(player)

		controller:Destroy()
	end)

	it("skips mocks the predicate rejects", function()
		local controller = setup()

		local rejected = controller.newPlayer({ UserId = TEST_USER_ID + 1 })
		controller.newPlayer()
		local alivePlayers =
			RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observePlayersBrio(isTestPlayer))

		expect(alivePlayers).never.toContain(rejected)

		controller:Destroy()
	end)
end)

describe("RxPlayerUtils.observeCharactersBrio", function()
	it("emits a brio holding the mock's spawned character", function()
		local controller = setup()

		local player = controller.newPlayer()
		local aliveCharacters = RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observeCharactersBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(aliveCharacters).toContain(character)

		controller:Destroy()
	end)

	it("kills the brio when the character despawns", function()
		local controller = setup()

		local player = controller.newPlayer()
		local aliveCharacters = RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observeCharactersBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(aliveCharacters).toContain(character)
		PlayerMock.removeCharacter(player)

		expect(aliveCharacters).never.toContain(character)

		controller:Destroy()
	end)
end)

describe("RxPlayerUtils.observeHumanoidsBrio", function()
	it("emits a brio holding the mock character's humanoid", function()
		local controller = setup()

		local player = controller.newPlayer()
		local aliveHumanoids = RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observeHumanoidsBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(aliveHumanoids).toContain(character:FindFirstChildOfClass("Humanoid"))

		controller:Destroy()
	end)
end)

describe("RxPlayerUtils.observeLocalPlayerBrio", function()
	it("emits nothing while no mock is designated", function()
		local controller = setup()

		controller.newPlayer()
		local brios = RxTestUtils.collectList(controller.maid, RxPlayerUtils.observeLocalPlayerBrio())

		expect(#brios).toBe(0)

		controller:Destroy()
	end)

	it("emits a living brio for a mock designated before subscribing", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)
		local brios = RxTestUtils.collectList(controller.maid, RxPlayerUtils.observeLocalPlayerBrio())

		expect(#brios >= 1).toBe(true)
		expect(brios[1]:GetValue()).toBe(player)

		controller:Destroy()
	end)

	it("emits a living brio for a mock designated after subscribing", function()
		local controller = setup()

		local brios = RxTestUtils.collectList(controller.maid, RxPlayerUtils.observeLocalPlayerBrio())
		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)

		expect(#brios >= 1).toBe(true)
		expect(brios[1]:GetValue()).toBe(player)

		controller:Destroy()
	end)

	it("kills the brio when the designation is cleared", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)
		local brios = RxTestUtils.collectList(controller.maid, RxPlayerUtils.observeLocalPlayerBrio())
		expect(#brios >= 1).toBe(true)

		PlayerMock.setMockedLocalPlayer(nil)

		expect(brios[1]:IsDead()).toBe(true)

		controller:Destroy()
	end)
end)

describe("RxPlayerUtils.observeLocalPlayerHumanoidBrio", function()
	it("emits a brio holding the designated mock's humanoid", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)
		local aliveHumanoids =
			RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observeLocalPlayerHumanoidBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(aliveHumanoids).toContain(character:FindFirstChildOfClass("Humanoid"))

		controller:Destroy()
	end)
end)

describe("RxPlayerUtils.observeFirstAppearanceLoaded", function()
	it("does not fire before the mock has spawned", function()
		local controller = setup()

		local player = controller.newPlayer()
		local fires =
			RxTestUtils.collectList(controller.maid, RxPlayerUtils.observeFirstAppearanceLoaded(player) :: any)

		expect(#fires).toBe(0)

		controller:Destroy()
	end)

	it("fires once the mock spawns", function()
		local controller = setup()

		local player = controller.newPlayer()
		local fired = 0
		local completed = false
		local maid = Maid.new()
		maid:GiveTask(RxPlayerUtils.observeFirstAppearanceLoaded(player):Subscribe(
			function()
				fired += 1
			end,
			nil,
			function()
				completed = true
			end
		))

		PlayerMock.loadMinimalCharacterAsync(player)

		expect(fired == 1 and completed).toBe(true)

		maid:DoCleaning()
		controller:Destroy()
	end)

	it("fires immediately when the mock has already spawned", function()
		local controller = setup()

		local player = controller.newPlayer()
		PlayerMock.loadMinimalCharacterAsync(player)

		local fired = 0
		local completed = false
		local maid = Maid.new()
		maid:GiveTask(RxPlayerUtils.observeFirstAppearanceLoaded(player):Subscribe(
			function()
				fired += 1
			end,
			nil,
			function()
				completed = true
			end
		))

		expect(fired).toBe(1)
		expect(completed).toBe(true)

		maid:DoCleaning()
		controller:Destroy()
	end)

	it("fails when the mock leaves before spawning", function()
		local controller = setup()

		local player = controller.newPlayer()
		local failure = Promise.new()
		local maid = Maid.new()
		maid:GiveTask(RxPlayerUtils.observeFirstAppearanceLoaded(player):Subscribe(nil, function(err)
			failure:Resolve(err)
		end))

		PlayerMock.kick(player, "Kicked by a test")

		expect(PromiseTestUtils.awaitFulfilled(failure)).never.toBeNil()

		maid:DoCleaning()
		controller:Destroy()
	end)
end)
