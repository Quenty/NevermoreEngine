--!strict
local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local RxPlayerUtils = require("RxPlayerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local TEST_USER_ID = 8675309

local function isTestPlayer(player: Player): boolean
	return PlayerMock.isMock(player) and PlayerMock.read(player, "UserId") == TEST_USER_ID
end

local function findLivingBrio(brios: { any }, value: any): any
	for _, brio in brios do
		if not brio:IsDead() and brio:GetValue() == value then
			return brio
		end
	end
	return nil
end

local function contains(values: { any }, value: any): boolean
	return table.find(values, value) ~= nil
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
			PlayerMock.setMockedLocalPlayer(player)
			maid:GiveTask(function()
				if player ~= nil and PlayerMock.getMockedLocalPlayer() == player then
					PlayerMock.setMockedLocalPlayer(nil)
				end
			end)
		end,
		record = function(observable: any): { any }
			local values = {}
			maid:GiveTask(observable:Subscribe(function(value)
				table.insert(values, value)
			end))
			return values
		end,
		awaitCount = function(values: { any }, count: number): boolean
			return PromiseTestUtils.awaitValue(function()
				return #values >= count
			end)
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	return controller
end

describe("RxPlayerUtils.observePlayers", function()
	it("emits a mock that is already in the game", function()
		local controller = setup()

		local player = controller.newPlayer()
		local players = controller.record(RxPlayerUtils.observePlayers())

		expect(controller.awaitCount(players, 1)).toBe(true)
		expect(contains(players, player)).toBe(true)

		controller.destroy()
	end)

	it("emits a mock that joins after subscribing", function()
		local controller = setup()

		local players = controller.record(RxPlayerUtils.observePlayers())
		local player = controller.newPlayer()

		expect(controller.awaitCount(players, 1)).toBe(true)
		expect(contains(players, player)).toBe(true)

		controller.destroy()
	end)

	it("skips mocks the predicate rejects", function()
		local controller = setup()

		local rejected = controller.newPlayer({ UserId = TEST_USER_ID + 1 })
		local accepted = controller.newPlayer()
		local players = controller.record(RxPlayerUtils.observePlayers(isTestPlayer))

		expect(controller.awaitCount(players, 1)).toBe(true)
		expect(contains(players, accepted)).toBe(true)
		expect(contains(players, rejected)).toBe(false)

		controller.destroy()
	end)
end)

describe("RxPlayerUtils.observePlayersBrio", function()
	it("emits a living brio for a mock already in the game", function()
		local controller = setup()

		local player = controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observePlayersBrio(isTestPlayer))

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(findLivingBrio(brios, player)).never.toBeNil()

		controller.destroy()
	end)

	it("emits a living brio for a mock that joins after subscribing", function()
		local controller = setup()

		local brios = controller.record(RxPlayerUtils.observePlayersBrio(isTestPlayer))
		local player = controller.newPlayer()

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(findLivingBrio(brios, player)).never.toBeNil()

		controller.destroy()
	end)

	it("kills the brio when the mock is destroyed", function()
		local controller = setup()

		local player = controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observePlayersBrio(isTestPlayer))
		expect(controller.awaitCount(brios, 1)).toBe(true)

		local brio = findLivingBrio(brios, player)
		player:Destroy()

		expect(PromiseTestUtils.awaitValue(function()
			return brio:IsDead()
		end)).toBe(true)

		controller.destroy()
	end)

	it("kills the brio when the mock is kicked", function()
		local controller = setup()

		local player = controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observePlayersBrio(isTestPlayer))
		expect(controller.awaitCount(brios, 1)).toBe(true)

		local brio = findLivingBrio(brios, player)
		-- A kick unparents rather than destroys, which is what drops the mock out of the game
		PlayerMock.kick(player, "Kicked by a test")

		expect(PromiseTestUtils.awaitValue(function()
			return brio:IsDead()
		end)).toBe(true)

		controller.destroy()
	end)

	it("skips mocks the predicate rejects", function()
		local controller = setup()

		local rejected = controller.newPlayer({ UserId = TEST_USER_ID + 1 })
		controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observePlayersBrio(isTestPlayer))

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(findLivingBrio(brios, rejected)).toBeNil()

		controller.destroy()
	end)
end)

describe("RxPlayerUtils.observeCharactersBrio", function()
	it("emits a brio holding the mock's spawned character", function()
		local controller = setup()

		local player = controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observeCharactersBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(findLivingBrio(brios, character)).never.toBeNil()

		controller.destroy()
	end)

	it("kills the brio when the character despawns", function()
		local controller = setup()

		local player = controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observeCharactersBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)
		expect(controller.awaitCount(brios, 1)).toBe(true)

		local brio = findLivingBrio(brios, character)
		PlayerMock.removeCharacter(player)

		expect(PromiseTestUtils.awaitValue(function()
			return brio:IsDead()
		end)).toBe(true)

		controller.destroy()
	end)
end)

describe("RxPlayerUtils.observeHumanoidsBrio", function()
	it("emits a brio holding the mock character's humanoid", function()
		local controller = setup()

		local player = controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observeHumanoidsBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(findLivingBrio(brios, character:FindFirstChildOfClass("Humanoid"))).never.toBeNil()

		controller.destroy()
	end)
end)

describe("RxPlayerUtils.observeLocalPlayerBrio", function()
	it("emits nothing while no mock is designated", function()
		local controller = setup()

		controller.newPlayer()
		local brios = controller.record(RxPlayerUtils.observeLocalPlayerBrio())

		expect(#brios).toBe(0)

		controller.destroy()
	end)

	it("emits a living brio for a mock designated before subscribing", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)
		local brios = controller.record(RxPlayerUtils.observeLocalPlayerBrio())

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(brios[1]:GetValue()).toBe(player)

		controller.destroy()
	end)

	it("emits a living brio for a mock designated after subscribing", function()
		local controller = setup()

		local brios = controller.record(RxPlayerUtils.observeLocalPlayerBrio())
		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(brios[1]:GetValue()).toBe(player)

		controller.destroy()
	end)

	it("kills the brio when the designation is cleared", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)
		local brios = controller.record(RxPlayerUtils.observeLocalPlayerBrio())
		expect(controller.awaitCount(brios, 1)).toBe(true)

		PlayerMock.setMockedLocalPlayer(nil)

		expect(PromiseTestUtils.awaitValue(function()
			return brios[1]:IsDead()
		end)).toBe(true)

		controller.destroy()
	end)
end)

describe("RxPlayerUtils.observeLocalPlayerHumanoidBrio", function()
	it("emits a brio holding the designated mock's humanoid", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designateLocalPlayer(player)
		local brios = controller.record(RxPlayerUtils.observeLocalPlayerHumanoidBrio())
		local character = PlayerMock.loadMinimalCharacterAsync(player)

		expect(controller.awaitCount(brios, 1)).toBe(true)
		expect(findLivingBrio(brios, character:FindFirstChildOfClass("Humanoid"))).never.toBeNil()

		controller.destroy()
	end)
end)

describe("RxPlayerUtils.observeFirstAppearanceLoaded", function()
	it("does not fire before the mock has spawned", function()
		local controller = setup()

		local player = controller.newPlayer()
		local fires = controller.record(RxPlayerUtils.observeFirstAppearanceLoaded(player))

		expect(#fires).toBe(0)

		controller.destroy()
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

		expect(PromiseTestUtils.awaitValue(function()
			return fired == 1 and completed
		end)).toBe(true)

		maid:DoCleaning()
		controller.destroy()
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
		controller.destroy()
	end)

	it("fails when the mock leaves before spawning", function()
		local controller = setup()

		local player = controller.newPlayer()
		local failure: any = nil
		local maid = Maid.new()
		maid:GiveTask(RxPlayerUtils.observeFirstAppearanceLoaded(player):Subscribe(nil, function(err)
			failure = err
		end))

		PlayerMock.kick(player, "Kicked by a test")

		expect(PromiseTestUtils.awaitValue(function()
			return failure ~= nil
		end)).toBe(true)

		maid:DoCleaning()
		controller.destroy()
	end)
end)
