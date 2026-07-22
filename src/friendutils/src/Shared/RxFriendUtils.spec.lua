--!strict
--[[
	@class RxFriendUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Brio = require("Brio")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local RxFriendUtils = require("RxFriendUtils")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RxFriendUtils.observeFriendsInServerAsBrios", function()
	local maid = Maid.new()

	afterEach(function()
		maid:DoCleaning()
	end)

	local function makeMock(userId: number): Player
		local player = PlayerMock.new({ UserId = userId })
		player.Parent = Workspace
		maid:GiveTask(player)
		return player
	end

	local function trackBrios(observer: Player): { Brio.Brio<Player> }
		local emissions: { Brio.Brio<Player> } = {}
		maid:GiveTask(RxFriendUtils.observeFriendsInServerAsBrios(observer):Subscribe(function(brio)
			table.insert(emissions, brio)
		end))
		return emissions
	end

	it("emits an initial lifetime for a mock that is already a friend", function()
		local observer = makeMock(90051001)
		local friend = makeMock(90051002)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051002, true)

		local emissions = trackBrios(observer)

		expect(#emissions).toBe(1)
		expect(emissions[1]:GetValue()).toBe(friend)
		expect(emissions[1]:IsDead()).toBe(false)
	end)

	it("emits nothing when no mock is a friend", function()
		local observer = makeMock(90051003)
		makeMock(90051004)

		local emissions = trackBrios(observer)

		expect(#emissions).toBe(0)
	end)

	it("emits when friendship is written mid-test and kills the lifetime on unfriend", function()
		local observer = makeMock(90051005)
		local friend = makeMock(90051006)

		local emissions = trackBrios(observer)
		expect(#emissions).toBe(0)

		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051006, true)
		expect(#emissions).toBe(1)
		expect(emissions[1]:GetValue()).toBe(friend)

		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051006, false)
		expect(emissions[1]:IsDead()).toBe(true)
	end)

	it("emits a fresh lifetime per re-friend", function()
		local observer = makeMock(90051007)
		makeMock(90051008)

		local emissions = trackBrios(observer)

		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051008, true)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051008, false)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051008, true)

		expect(#emissions).toBe(2)
		expect(emissions[1]:IsDead()).toBe(true)
		expect(emissions[2]:IsDead()).toBe(false)
	end)

	it("does not emit a duplicate lifetime for a repeated friended signal", function()
		local observer = makeMock(90051009)
		makeMock(90051010)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051010, true)

		local emissions = trackBrios(observer)

		-- The CoreGui friended event this wiring stands in for can fire repeatedly; a re-write of
		-- the same state must not open a second lifetime.
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051010, true)

		expect(#emissions).toBe(1)
	end)

	it("emits for a friend mock that joins after subscription", function()
		local observer = makeMock(90051011)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051012, true)

		local emissions = trackBrios(observer)
		expect(#emissions).toBe(0)

		local friend = makeMock(90051012)

		expect(#emissions).toBe(1)
		expect(emissions[1]:GetValue()).toBe(friend)
	end)

	it("kills the lifetime when the friend mock leaves", function()
		local observer = makeMock(90051013)
		local friend = makeMock(90051014)
		PlayerMock.writeLookup(observer, "Player.IsFriendsWithAsync", 90051014, true)

		local emissions = trackBrios(observer)
		expect(#emissions).toBe(1)

		friend:Destroy()

		expect(emissions[1]:IsDead()).toBe(true)
	end)
end)
