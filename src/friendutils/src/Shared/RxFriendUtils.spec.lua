--!strict
--[[
	@class RxFriendUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Brio = require("Brio")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local RxFriendUtils = require("RxFriendUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local function newMock(userId: number): Player
		local player = PlayerMock.new({ UserId = userId })
		player.Parent = Workspace
		maid:GiveTask(player)
		return player
	end

	local function newLocalMock(userId: number): Player
		local player = newMock(userId)
		maid:Add(PlayerMock.setMockedLocalPlayer(player))
		return player
	end

	local function fireCoreFriendship(observer: Player, otherPlayer: Player, isFriend: boolean): ()
		local coreName = if isFriend then "PlayerFriendedEvent" else "PlayerUnfriendedEvent"
		PlayerMock.callMethod(observer, "StarterGui.GetCore", coreName):Fire(otherPlayer)
	end

	local function trackBrios(observer: Player): { Brio.Brio<Player> }
		local emissions: { Brio.Brio<Player> } = {}
		maid:GiveTask(RxFriendUtils.observeFriendsInServerAsBrios(observer):Subscribe(function(brio)
			table.insert(emissions, brio)
		end))
		return emissions
	end

	local controller = {
		newMock = newMock,
		newLocalMock = newLocalMock,
		fireCoreFriendship = fireCoreFriendship,
		trackBrios = trackBrios,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxFriendUtils.observeFriendsInServerAsBrios", function()
	it("emits an initial lifetime for a mock that is already a friend", function()
		local controller = setup()

		local observer = controller.newMock(90051001)
		local friend = controller.newMock(90051002)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", true, 90051002)

		local emissions = controller.trackBrios(observer)

		expect(#emissions).toBe(1)
		expect(emissions[1]:GetValue()).toBe(friend)
		expect(emissions[1]:IsDead()).toBe(false)

		controller:Destroy()
	end)

	it("emits nothing when no mock is a friend", function()
		local controller = setup()

		local observer = controller.newMock(90051003)
		controller.newMock(90051004)

		local emissions = controller.trackBrios(observer)

		expect(#emissions).toBe(0)

		controller:Destroy()
	end)

	it("emits when the CoreGui reports a friending and kills the lifetime on unfriend", function()
		local controller = setup()

		local observer = controller.newLocalMock(90051005)
		local friend = controller.newMock(90051006)

		local emissions = controller.trackBrios(observer)
		expect(#emissions).toBe(0)

		controller.fireCoreFriendship(observer, friend, true)
		expect(#emissions).toBe(1)
		expect(emissions[1]:GetValue()).toBe(friend)

		controller.fireCoreFriendship(observer, friend, false)
		expect(emissions[1]:IsDead()).toBe(true)

		controller:Destroy()
	end)

	it("emits a fresh lifetime per re-friend", function()
		local controller = setup()

		local observer = controller.newLocalMock(90051007)
		local friend = controller.newMock(90051008)

		local emissions = controller.trackBrios(observer)

		controller.fireCoreFriendship(observer, friend, true)
		controller.fireCoreFriendship(observer, friend, false)
		controller.fireCoreFriendship(observer, friend, true)

		expect(#emissions).toBe(2)
		expect(emissions[1]:IsDead()).toBe(true)
		expect(emissions[2]:IsDead()).toBe(false)

		controller:Destroy()
	end)

	it("does not emit a duplicate lifetime for a repeated friended signal", function()
		local controller = setup()

		local observer = controller.newLocalMock(90051009)
		local friend = controller.newMock(90051010)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", true, 90051010)

		local emissions = controller.trackBrios(observer)

		controller.fireCoreFriendship(observer, friend, true)

		expect(#emissions).toBe(1)

		controller:Destroy()
	end)

	it("emits for a friend mock that joins after subscription", function()
		local controller = setup()

		local observer = controller.newMock(90051011)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", true, 90051012)

		local emissions = controller.trackBrios(observer)
		expect(#emissions).toBe(0)

		local friend = controller.newMock(90051012)

		expect(#emissions).toBe(1)
		expect(emissions[1]:GetValue()).toBe(friend)

		controller:Destroy()
	end)

	it("kills the lifetime when the friend mock leaves", function()
		local controller = setup()

		local observer = controller.newMock(90051013)
		local friend = controller.newMock(90051014)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", true, 90051014)

		local emissions = controller.trackBrios(observer)
		expect(#emissions).toBe(1)

		friend:Destroy()

		expect(emissions[1]:IsDead()).toBe(true)

		controller:Destroy()
	end)
end)
