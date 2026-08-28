--!strict
--[[
	Covers the graceful session close handoff between two sequential "server sessions" over one
	DataStoreMock: a session that ends cleanly must release its session lock, so the next server's
	load is an immediate clean takeover (no graceful-close wait, no retry ladder). Also pins the
	crash-safety semantics that must NOT change: a live holder still blocks, and a dead holder's
	fresh lock is only stolen through the retry ladder -- without leaking uncaught rejections.

	@class DataStoreGracefulClose.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local MessagingServiceMock = require("MessagingServiceMock")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("clean session end releases the lock (server-shutdown path)", function()
	it("a closing server releases the session so the next server loads immediately", function()
		local mock = DataStoreMock.new()

		-- Server A: a player in the server with a live session, about to be shut down.
		local maidA = Maid.new()
		local serviceBagA = DataStoreTestUtils.newServiceBag(maidA, MessagingServiceMock.new())
		local managerA = maidA:Add(PlayerDataStoreManager.new(serviceBagA, mock :: any, function(userId)
			return "user_" .. tostring(userId)
		end, true))

		local storeA = assert(managerA:GetDataStore(1), "No storeA")
		storeA:Store("coins", 42)
		if
			not PromiseTestUtils.awaitValue(function()
				local raw = mock:GetRaw("user_1")
				return raw ~= nil and raw.lock ~= nil
			end, 10)
		then
			expect("A never acquired the lock").toEqual("A acquired the lock")
			maidA:DoCleaning()
			return
		end

		-- Clean shutdown: Roblox fires PlayerRemoving for the player still in the server, and holds the
		-- close open until that removal has flushed.
		if not PromiseTestUtils.awaitSettled(DataStoreTestUtils.promiseSimulatedShutdown(managerA, { 1 }), 10) then
			expect("A's shutdown never flushed").toEqual("A's shutdown flushed")
			maidA:DoCleaning()
			return
		end
		maidA:DoCleaning()

		-- The close must have written the graceful release: data saved, lock gone.
		expect(mock:GetRaw("user_1").lock).toEqual(nil)
		expect(mock:GetRaw("user_1").coins).toEqual(42)

		-- Server B: an immediate clean takeover -- bounded well under the 5s graceful-close
		-- wait (and nowhere near the ~49s retry ladder).
		local maidB = Maid.new()
		local storeB = DataStoreTestUtils.newSessionLockedStore(maidB, mock, "user_1")
		local loadB = storeB:Load("coins")
		if not PromiseTestUtils.awaitSettled(loadB, 1) then
			expect("B load was not immediate").toEqual("B load was immediate")
			maidB:DoCleaning()
			return
		end
		expect((loadB:Wait())).toEqual(42)
		expect(mock:GetRaw("user_1").lock.ActiveSession.SessionId).toEqual(storeB:GetSessionId())

		maidB:DoCleaning()
	end)
end)

describe("crash-safety semantics preserved", function()
	it("still blocks on a live holder that does not close (ask-and-wait, no immediate steal)", function()
		local controller = DataStoreTestUtils.setup()

		local serverA = controller.newServer({ messaging = true })
		if not controller.awaitOwn(serverA) then
			expect("A load hung").toEqual("A load settled")
			controller:Destroy()
			return
		end

		local serverB = controller.newServer({ messaging = true })
		serverB:SetSessionMessagingCloseDelaySeconds(0.1)
		local loadB = serverB:PromiseLoadSuccessful()

		-- The holder is alive but never closes; B must still be waiting on the graceful
		-- protocol, not stealing a fresh lock.
		expect(PromiseTestUtils.awaitSettled(loadB, 2)).toEqual(false)
		expect(controller.mock:GetRaw("player_1").lock.ActiveSession.SessionId).toEqual(serverA:GetSessionId())

		controller:Destroy()
	end)

	it("steals a dead holder's fresh lock only through the retry ladder, leaking no rejections", function()
		local controller = DataStoreTestUtils.setup()

		-- A holder that died without closing: fresh lock, no live session behind it. Every
		-- graceful-close request times out, so the load must grind through the (shortened)
		-- retry ladder and then steal -- with every rejection along the way consumed (the
		-- test runner fails the suite on stray uncaught rejections).
		controller.mock:SetRaw("player_1", {
			coins = 9,
			lock = {
				LastUpdateTime = os.time(),
				ActiveSession = { SessionId = "dead-session", PlaceId = 123, JobId = "dead-job" },
			},
		})

		local serverB = controller.newServer({ messaging = true })
		serverB:SetLoadRetryOptions({ exponential = 1, initialWaitTime = 0.2, maxAttempts = 2, printWarning = false })
		serverB:SetSessionMessagingCloseDelaySeconds(0.05)

		local loadB = serverB:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(loadB, 20) then
			expect("B never stole the dead session's lock").toEqual("B stole the dead session's lock")
			controller:Destroy()
			return
		end
		expect((loadB:Wait())).toEqual(true)

		local raw = controller.mock:GetRaw("player_1")
		expect(raw.coins).toEqual(9)
		expect(raw.lock.ActiveSession.SessionId).toEqual(serverB:GetSessionId())

		controller:Destroy()
	end, 30000) -- Two full 5s graceful-close timeouts plus backoff, beyond jest's 5s default
end)
