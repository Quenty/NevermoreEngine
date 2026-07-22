--!nonstrict
--[[
	@class DataStoreTwoServerLock.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local KEY = "player_1"

describe("two servers: clean handoff and crash recovery", function()
	it("hands a player off cleanly: A saves and closes, B loads A's data and owns the lock", function()
		local controller = DataStoreTestUtils.setup()

		local serverA = controller.newServer()
		expect(controller.awaitOwn(serverA)).toEqual(true)
		serverA:Store("coins", 42)
		if not PromiseTestUtils.awaitSettled(serverA:SaveAndCloseSession(), 10) then
			expect("A close hung").toEqual("settled")
			controller:destroy()
			return
		end

		local serverB = controller.newServer()
		local coins = serverB:Load("coins")
		if not PromiseTestUtils.awaitSettled(coins, 10) then
			expect("B load hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((coins:Wait())).toEqual(42)
		expect(controller.mock:GetRaw(KEY).lock.ActiveSession.SessionId).toEqual(serverB:GetSessionId())

		controller:destroy()
	end)

	it("recovers a crashed server's saved data by stealing its stale lock", function()
		local controller = DataStoreTestUtils.setup()

		local serverA = controller.newServer()
		expect(controller.awaitOwn(serverA)).toEqual(true)
		serverA:Store("coins", 7)
		if not PromiseTestUtils.awaitSettled(serverA:Save(), 10) then
			expect("A save hung").toEqual("settled")
			controller:destroy()
			return
		end

		local raw = controller.mock:GetRaw(KEY)
		raw.lock.LastUpdateTime = os.time() - 1000000
		controller.mock:SetRaw(KEY, raw)

		local serverB = controller.newServer()
		local coins = serverB:Load("coins")
		if not PromiseTestUtils.awaitSettled(coins, 10) then
			expect("B load hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((coins:Wait())).toEqual(7)
		expect(controller.mock:GetRaw(KEY).lock.ActiveSession.SessionId).toEqual(serverB:GetSessionId())

		controller:destroy()
	end)

	it("lets exactly one of two concurrent loads acquire the lock; the other stays blocked", function()
		local controller = DataStoreTestUtils.setup()

		local serverA = controller.newServer()
		local serverB = controller.newServer()

		local loadA = serverA:PromiseLoadSuccessful()
		local loadB = serverB:PromiseLoadSuccessful()

		expect(PromiseTestUtils.awaitValue(function()
			return not loadA:IsPending() or not loadB:IsPending()
		end, 5)).toEqual(true)

		local aSettled = not loadA:IsPending()
		local bSettled = not loadB:IsPending()
		expect(aSettled ~= bSettled).toEqual(true)

		local owner = controller.mock:GetRaw(KEY).lock.ActiveSession.SessionId
		expect(owner == serverA:GetSessionId() or owner == serverB:GetSessionId()).toEqual(true)

		controller:destroy()
	end)

	it("cancels the loser's write when a session is stolen (no duplication)", function()
		local controller = DataStoreTestUtils.setup()

		local serverA = controller.newServer()
		expect(controller.awaitOwn(serverA)).toEqual(true)

		controller.mock:SetRaw(KEY, {
			coins = 100,
			lock = {
				LastUpdateTime = os.time(),
				ActiveSession = { SessionId = "server-b", PlaceId = 222, JobId = "job-b" },
			},
		})

		local stolen = nil
		serverA.SessionStolen:Connect(function(session)
			stolen = session
		end)
		serverA:Store("coins", 5)
		if not PromiseTestUtils.awaitSettled(serverA:Save(), 10) then
			expect("A save hung").toEqual("settled")
			controller:destroy()
			return
		end

		expect(stolen).never.toBeNil()
		expect(controller.mock:GetRaw(KEY).coins).toEqual(100)

		controller:destroy()
	end)
end)

describe("two servers: MessagingService graceful close", function()
	it("completes the close handshake: B asks A to close, A closes and releases the lock", function()
		local controller = DataStoreTestUtils.setup()

		local serverA = controller.newServer({ messaging = true, autoCloseOnRequest = true })
		expect(controller.awaitOwn(serverA)).toEqual(true)

		local _serverB, helperB = controller.newServer({ messaging = true })

		local graceful = helperB:PromiseCloseSessionGraceful(game.PlaceId, game.JobId, serverA:GetSessionId())
		if not PromiseTestUtils.awaitSettled(graceful, 15) then
			expect("graceful close hung").toEqual("resolved")
			controller:destroy()
			return
		end
		expect((graceful:Yield())).toEqual(true)

		expect(PromiseTestUtils.awaitValue(function()
			local raw = controller.mock:GetRaw(KEY)
			return raw ~= nil and raw.lock == nil
		end, 5)).toEqual(true)

		controller:destroy()
	end, 30000) -- MessagingService round-trip, beyond jest's 5s default

	it("evicts the holder during a messaging-enabled load and then acquires (production flow)", function()
		local controller = DataStoreTestUtils.setup()

		local serverA = controller.newServer({ messaging = true, autoCloseOnRequest = true })
		expect(controller.awaitOwn(serverA)).toEqual(true)

		local serverB = controller.newServer({ messaging = true })
		serverB:SetSessionMessagingCloseDelaySeconds(0.1)
		local loadB = serverB:PromiseLoadSuccessful()

		if not PromiseTestUtils.awaitSettled(loadB, 8) then
			expect("B messaging load hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((loadB:Wait())).toEqual(true)
		expect(controller.mock:GetRaw(KEY).lock.ActiveSession.SessionId).toEqual(serverB:GetSessionId())

		controller:destroy()
	end)
end)
