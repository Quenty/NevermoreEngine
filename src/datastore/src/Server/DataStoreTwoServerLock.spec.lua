--!nonstrict
--[[
	Two servers fighting over one player's session-locked key: two DataStore objects (server A and
	server B) share one DataStoreMock with distinct SessionIds, exactly like two live game servers.
	This exercises the full cross-server lock lifecycle -- clean handoff via close, crash recovery via
	stale-lock steal, a concurrent-load race, the MessagingService graceful-close handshake, and
	session-stolen data integrity.

	@class DataStoreTwoServerLock.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMessageHelper = require("DataStoreMessageHelper")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach

local KEY = "player_1"

-- Every object a test creates is tracked here and torn down in afterEach, so a DataStore's auto-save
-- loop can never outlive the test. These specs share one Roblox place across all packages, so a
-- leaked background task throws in a later package's window.
local maid = Maid.new()

afterEach(function()
	maid:DoCleaning()
end)

local function newMessagingServiceBag()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	serviceBag:Start()
	return serviceBag
end

local function newServer(mock, serviceBag, opts)
	opts = opts or {}
	local dataStore = DataStore.new(mock, KEY)
	dataStore:SetSessionLockingEnabled(true)
	dataStore:SetUserIdList({ 1 })
	local helper
	if opts.messaging then
		dataStore:SetSessionMessagingEnabled(true, serviceBag)
		helper = DataStoreMessageHelper.new(serviceBag, dataStore)
	end
	if opts.autoCloseOnRequest then
		dataStore.SessionCloseRequested:Connect(function()
			dataStore:SaveAndCloseSession()
		end)
	end

	-- Tear the store (and its message helper) down before the serviceBag it borrows
	-- PlaceMessagingService from. The messaging tests register the bag's teardown after their
	-- servers, so it runs last; a bare (bag-less) server owns no bag, so this closure is all it needs.
	maid:GiveTask(function()
		if helper then
			helper:Destroy()
		end
		dataStore:Destroy()
	end)

	return dataStore, helper
end

local function awaitOwn(dataStore)
	local promise = dataStore:PromiseLoadSuccessful()
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		return false
	end
	local ok, loadedOk = promise:Yield()
	return ok and loadedOk
end

describe("two servers: clean handoff and crash recovery", function()
	it("hands a player off cleanly: A saves and closes, B loads A's data and owns the lock", function()
		local mock = DataStoreMock.new()

		local serverA = newServer(mock)
		expect(awaitOwn(serverA)).toEqual(true)
		serverA:Store("coins", 42)
		if not PromiseTestUtils.awaitSettled(serverA:SaveAndCloseSession(), 10) then
			expect("A close hung").toEqual("settled")
			return
		end

		local serverB = newServer(mock)
		local coins = serverB:Load("coins")
		if not PromiseTestUtils.awaitSettled(coins, 10) then
			expect("B load hung").toEqual("settled")
			return
		end
		expect((select(2, coins:Yield()))).toEqual(42)
		expect(mock:GetRaw(KEY).lock.ActiveSession.SessionId).toEqual(serverB:GetSessionId())
	end)

	it("recovers a crashed server's saved data by stealing its stale lock", function()
		local mock = DataStoreMock.new()

		-- A acquires, saves coins under its lock, then "crashes" (no clean close).
		local serverA = newServer(mock)
		expect(awaitOwn(serverA)).toEqual(true)
		serverA:Store("coins", 7)
		if not PromiseTestUtils.awaitSettled(serverA:Save(), 10) then
			expect("A save hung").toEqual("settled")
			return
		end

		-- Age A's lock so it looks like a long-dead (crashed) server, then abandon A.
		local raw = mock:GetRaw(KEY)
		raw.lock.LastUpdateTime = os.time() - 1000000
		mock:SetRaw(KEY, raw)

		-- B loads: steals the stale lock and recovers A's saved coins.
		local serverB = newServer(mock)
		local coins = serverB:Load("coins")
		if not PromiseTestUtils.awaitSettled(coins, 10) then
			expect("B load hung").toEqual("settled")
			return
		end
		expect((select(2, coins:Yield()))).toEqual(7)
		expect(mock:GetRaw(KEY).lock.ActiveSession.SessionId).toEqual(serverB:GetSessionId())
	end)

	it("lets exactly one of two concurrent loads acquire the lock; the other stays blocked", function()
		local mock = DataStoreMock.new()

		local serverA = newServer(mock)
		local serverB = newServer(mock)

		local loadA = serverA:PromiseLoadSuccessful()
		local loadB = serverB:PromiseLoadSuccessful()

		-- One acquires quickly; the other is blocked (retrying against the winner's fresh lock).
		expect(PromiseTestUtils.awaitValue(function()
			return not loadA:IsPending() or not loadB:IsPending()
		end, 5)).toEqual(true)

		local aSettled = not loadA:IsPending()
		local bSettled = not loadB:IsPending()
		expect(aSettled ~= bSettled).toEqual(true) -- exactly one

		local owner = mock:GetRaw(KEY).lock.ActiveSession.SessionId
		expect(owner == serverA:GetSessionId() or owner == serverB:GetSessionId()).toEqual(true)
	end)

	it("cancels the loser's write when a session is stolen (no duplication)", function()
		local mock = DataStoreMock.new()

		local serverA = newServer(mock)
		expect(awaitOwn(serverA)).toEqual(true)

		-- B takes over by writing its own lock + data directly (as if it stole the session).
		mock:SetRaw(KEY, {
			coins = 100,
			lock = {
				LastUpdateTime = os.time(),
				ActiveSession = { SessionId = "server-b", PlaceId = 222, JobId = "job-b" },
			},
		})

		-- A tries to save its own value; the write is cancelled (SessionStolen), B's data survives.
		local stolen = nil
		serverA.SessionStolen:Connect(function(session)
			stolen = session
		end)
		serverA:Store("coins", 5)
		if not PromiseTestUtils.awaitSettled(serverA:Save(), 10) then
			expect("A save hung").toEqual("settled")
			return
		end

		expect(stolen).never.toBeNil()
		expect(mock:GetRaw(KEY).coins).toEqual(100)
	end)
end)

describe("two servers: MessagingService graceful close", function()
	it("completes the close handshake: B asks A to close, A closes and releases the lock", function()
		local serviceBag = newMessagingServiceBag()
		local mock = DataStoreMock.new()

		local serverA, _helperA = newServer(mock, serviceBag, { messaging = true, autoCloseOnRequest = true })
		expect(awaitOwn(serverA)).toEqual(true)

		local _serverB, helperB = newServer(mock, serviceBag, { messaging = true })

		-- Registered after the servers so the bag is destroyed last (child before serviceBag).
		maid:GiveTask(function()
			serviceBag:Destroy()
		end)

		-- B gracefully asks A (the lock holder) to close.
		local graceful = helperB:PromiseCloseSessionGraceful(game.PlaceId, game.JobId, serverA:GetSessionId())
		if not PromiseTestUtils.awaitSettled(graceful, 15) then
			expect("graceful close hung").toEqual("resolved")
			return
		end
		expect((graceful:Yield())).toEqual(true)

		-- A honored the request and released its lock.
		expect(PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw(KEY)
			return raw ~= nil and raw.lock == nil
		end, 5)).toEqual(true)
	end, 30000) -- MessagingService round-trip, beyond jest's 5s default

	it("evicts the holder during a messaging-enabled load and then acquires (production flow)", function()
		local serviceBag = newMessagingServiceBag()
		local mock = DataStoreMock.new()

		-- A holds the lock and will honor a graceful close request.
		local serverA = newServer(mock, serviceBag, { messaging = true, autoCloseOnRequest = true })
		expect(awaitOwn(serverA)).toEqual(true)

		-- B loads with messaging enabled: blocked by A's fresh lock, its load asks A to close, then
		-- (after the propagation delay) retries and acquires. This is the real cross-server handoff.
		-- Use a tiny propagation delay so the test does not wait the production 5s.
		local serverB = newServer(mock, serviceBag, { messaging = true })

		-- Registered after the servers so the bag is destroyed last (child before serviceBag).
		maid:GiveTask(function()
			serviceBag:Destroy()
		end)

		serverB:SetSessionMessagingCloseDelaySeconds(0.1)
		local loadB = serverB:PromiseLoadSuccessful()

		if not PromiseTestUtils.awaitSettled(loadB, 8) then
			expect("B messaging load hung").toEqual("settled")
			return
		end
		expect((select(2, loadB:Yield()))).toEqual(true)
		expect(mock:GetRaw(KEY).lock.ActiveSession.SessionId).toEqual(serverB:GetSessionId())
	end)
end)
