--!strict
--[[
	@class TeleportServiceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")
local TeleportServiceUtils = require("TeleportServiceUtils")

local afterEach = Jest.Globals.afterEach
local beforeEach = Jest.Globals.beforeEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local jest = Jest.Globals.jest

local mocks: { Player } = {}

local function newMock(userId: number): Player
	local player = PlayerMock.new({ UserId = userId })
	table.insert(mocks, player)
	return player
end

-- A player the mock layer will not claim, so the call reaches the engine, which refuses it.
local function newUnmockedPlayer(): Player
	local player = Instance.new("Folder")
	player.Name = "NotAPlayerMock"
	table.insert(mocks, (player :: any) :: Player)
	return (player :: any) :: Player
end

-- A cloud run is a server, so the realm seam is what lets the client path be exercised at all.
--
-- Spied once and re-implemented between tests rather than restored and re-spied: jest.restoreAllMocks
-- clears the spy state but not the per-object mock registry, so a second jest.spyOn of the same method
-- hands back the cached mock WITHOUT reinstalling it, and the spy quietly stops applying.
local realIsServer = TeleportServiceUtils._isServer
local isServerSpy = jest.spyOn(TeleportServiceUtils, "_isServer")

local function pretendClient(): ()
	isServerSpy.mockReturnValue(false)
end

afterEach(function()
	isServerSpy.mockImplementation(realIsServer)

	for _, player in mocks do
		player:Destroy()
	end
	table.clear(mocks)
end)

local function readHop(player: Player, placeId: number): any
	return PlayerMock.readLookup(player, "TeleportService.Teleport", placeId)
end

local function clearHop(player: Player, placeId: number): ()
	PlayerMock.writeLookup(player, "TeleportService.Teleport", nil, placeId)
end

local function report(player: Player, placeId: number, result: Enum.TeleportResult, message: string): ()
	PlayerMock.fireServiceSignal(player, "TeleportService.TeleportInitFailed", player, result, message, placeId)
end

-- The everyday transient refusal, for tests about retrying rather than about classification.
local function refuse(player: Player, placeId: number, message: string): ()
	report(player, placeId, Enum.TeleportResult.GameFull, message)
end

-- Every result the engine can report, so a test over all of them cannot silently miss one.
local ALL_RESULTS: { Enum.TeleportResult } = Enum.TeleportResult:GetEnumItems()

local IN_FLIGHT: { Enum.TeleportResult } = {
	Enum.TeleportResult.Success,
	Enum.TeleportResult.IsTeleporting,
}

local TERMINAL: { Enum.TeleportResult } = {
	Enum.TeleportResult.GameNotFound,
	Enum.TeleportResult.Unauthorized,
	Enum.TeleportResult.Flooded,
}

local function awaitHop(player: Player, placeId: number): any
	PromiseTestUtils.awaitValue(function()
		return readHop(player, placeId) ~= nil
	end)
	return readHop(player, placeId)
end

describe("TeleportServiceUtils.teleport", function()
	beforeEach(function()
		pretendClient()
	end)

	-- It yields until the teleport is settled, and a teleport that works never settles -- the player
	-- leaves instead -- so the request is made off-thread and read back through the mock's record.
	local function requestTeleport(
		placeId: number,
		player: Player,
		teleportData: { [string]: any }?
	): () -> (boolean?, string?)
		local ok, err = nil :: boolean?, nil :: string?

		task.spawn(function()
			ok, err = TeleportServiceUtils.teleport(placeId, player, teleportData)
		end)

		return function(): (boolean?, string?)
			return ok, err
		end
	end

	it("records the teleport with via=Teleport and its data on a mock", function()
		local player = newMock(880001)
		requestTeleport(4567, player, { SlotId = "abc", Flag = true })

		local hop = awaitHop(player, 4567)
		expect(hop.via).toEqual("Teleport")
		expect(hop.teleportData.SlotId).toEqual("abc")
		expect(hop.teleportData.Flag).toEqual(true)
	end)

	it("records an empty data table when none is passed, so a read still reports the hop", function()
		local player = newMock(880002)
		requestTeleport(9999, player, nil)

		local hop = awaitHop(player, 9999)
		expect(hop).never.toEqual(nil)
		expect(hop.via).toEqual("Teleport")
	end)

	it("does not record a hop to a place that was never teleported to", function()
		local player = newMock(880003)
		requestTeleport(1111, player, {})

		awaitHop(player, 1111)
		expect(PlayerMock.readLookup(player, "TeleportService.Teleport", 2222)).toEqual(nil)
	end)

	it("overwrites a prior hop to the same place with the latest data", function()
		local player = newMock(880004)
		requestTeleport(333, player, { SlotId = "first" })
		awaitHop(player, 333)
		clearHop(player, 333)
		requestTeleport(333, player, { SlotId = "second" })

		expect(awaitHop(player, 333).teleportData.SlotId).toEqual("second")
	end)

	it("does not come back while the hop is still in flight", function()
		local player = newMock(880006)

		local read = requestTeleport(444, player, {})
		awaitHop(player, 444)

		task.wait(0.1)
		expect(read()).toEqual(nil)
	end)

	it("comes back false with the reason once the teleport has failed", function()
		local player = newMock(880007)

		local read = requestTeleport(555, player, {})
		awaitHop(player, 555)
		report(player, 555, Enum.TeleportResult.Unauthorized, "not allowed")

		PromiseTestUtils.awaitValue(function()
			return read() ~= nil
		end)

		local ok, err = read()
		expect(ok).toEqual(false)
		expect(err).toContain("Unauthorized")
	end)

	it("errors on a non-number placeId", function()
		local player = newMock(880005)
		expect(function()
			TeleportServiceUtils.teleport("nope" :: any, player, {})
		end).toThrow()
	end)

	it("errors when given no player", function()
		expect(function()
			TeleportServiceUtils.teleport(123, nil :: any, {})
		end).toThrow()
	end)
end)

describe("TeleportServiceUtils.teleportToPlaceInstance", function()
	it("records via, instanceId, spawnName and data on a mock", function()
		local player = newMock(881001)
		TeleportServiceUtils.teleportToPlaceInstance(500, "job-9", player, "SpawnA", { SlotId = "x" })

		local hop = PlayerMock.readLookup(player, "TeleportService.Teleport", 500)
		expect(hop.via).toEqual("TeleportToPlaceInstance")
		expect(hop.instanceId).toEqual("job-9")
		expect(hop.spawnName).toEqual("SpawnA")
		expect(hop.teleportData.SlotId).toEqual("x")
	end)

	it("errors on a non-string instanceId", function()
		local player = newMock(881002)
		expect(function()
			TeleportServiceUtils.teleportToPlaceInstance(500, 123 :: any, player)
		end).toThrow()
	end)
end)

describe("TeleportServiceUtils.teleportAsync", function()
	it("records each mock in the batch with the options' teleport data, skipping the engine", function()
		local a = newMock(882001)
		local b = newMock(882002)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ SlotId = "shared" })

		local result = TeleportServiceUtils.teleportAsync(600, { a, b }, options)

		expect(result).toEqual(nil)
		expect(PlayerMock.readLookup(a, "TeleportService.Teleport", 600).via).toEqual("TeleportAsync")
		expect(PlayerMock.readLookup(a, "TeleportService.Teleport", 600).teleportData.SlotId).toEqual("shared")
		expect(PlayerMock.readLookup(b, "TeleportService.Teleport", 600).teleportData.SlotId).toEqual("shared")
	end)

	it("records a mock even when no options are passed", function()
		local player = newMock(882003)
		TeleportServiceUtils.teleportAsync(601, { player }, nil)

		expect(PlayerMock.readLookup(player, "TeleportService.Teleport", 601).via).toEqual("TeleportAsync")
	end)

	it("errors on non-table players", function()
		expect(function()
			TeleportServiceUtils.teleportAsync(600, "nope" :: any, nil)
		end).toThrow()
	end)

	it("errors on options that are not a TeleportOptions", function()
		local player = newMock(882004)
		expect(function()
			TeleportServiceUtils.teleportAsync(600, { player }, Instance.new("Folder") :: any)
		end).toThrow()
	end)
end)

describe("TeleportServiceUtils.promiseTeleportServerOnce", function()
	it("is mock-aware: records mocks and resolves nil for an all-mock batch", function()
		local player = newMock(883001)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ SlotId = "z" })

		local result = TeleportServiceUtils.promiseTeleportServerOnce(700, { player }, options):Wait()

		expect(result).toEqual(nil)
		local hop = PlayerMock.readLookup(player, "TeleportService.Teleport", 700)
		expect(hop.via).toEqual("TeleportAsync")
		expect(hop.teleportData.SlotId).toEqual("z")
	end)
end)

describe("TeleportServiceUtils.promiseTeleportClientOnce", function()
	it("teleports on the spot, carrying the teleport data", function()
		local player = newMock(886001)

		TeleportServiceUtils.promiseTeleportClientOnce(820, player, { SlotId = "abc" })

		local hop = readHop(player, 820)
		expect(hop.via).toEqual("Teleport")
		expect(hop.teleportData.SlotId).toEqual("abc")
	end)

	it("stays pending, because a teleport that works ends with the player gone", function()
		local player = newMock(886002)

		local promise = TeleportServiceUtils.promiseTeleportClientOnce(821, player)

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)

		promise:Destroy()
	end)

	it("rejects with the whole report, so a caller decides on the result", function()
		local player = newMock(886003)

		local promise = TeleportServiceUtils.promiseTeleportClientOnce(822, player)
		report(player, 822, Enum.TeleportResult.Unauthorized, "not allowed")

		local outcome, rejected = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(rejected.result).toEqual(Enum.TeleportResult.Unauthorized)
		expect(rejected.message).toEqual("not allowed")
		expect(rejected.placeId).toEqual(822)
	end)

	it("renders its report as text, for a consumer that only wants a message", function()
		local player = newMock(886004)

		local promise = TeleportServiceUtils.promiseTeleportClientOnce(823, player)
		report(player, 823, Enum.TeleportResult.GameFull, "server full")

		local _, rejected = PromiseTestUtils.awaitOutcome(promise)
		expect(tostring(rejected)).toContain("823")
		expect(tostring(rejected)).toContain("GameFull")
		expect(tostring(rejected)).toContain("server full")
	end)

	it("asks exactly once, whatever the engine reports back", function()
		for _, result in ALL_RESULTS do
			local player = newMock(886100 + result.Value)

			local promise = TeleportServiceUtils.promiseTeleportClientOnce(824, player)
			expect(readHop(player, 824)).never.toEqual(nil)

			clearHop(player, 824)
			report(player, 824, result, "whatever the engine says")

			-- The request is out and Roblox cannot take it back, so nothing this reports may produce a
			-- second one. Retrying is the caller's decision, made only after this has rejected.
			task.wait(0.1)
			expect({ result = result.Name, secondHop = readHop(player, 824) }).toEqual({
				result = result.Name,
				secondHop = nil,
			})

			promise:Destroy()
		end
	end)

	it("stays pending while the engine says the hop is underway", function()
		for _, result in IN_FLIGHT do
			local player = newMock(886200 + result.Value)

			local promise = TeleportServiceUtils.promiseTeleportClientOnce(825, player)
			report(player, 825, result, "still going")

			expect({ result = result.Name, settled = PromiseTestUtils.awaitSettled(promise, 0.2) }).toEqual({
				result = result.Name,
				settled = false,
			})

			promise:Destroy()
		end
	end)

	it("reports a raised call as a Failure, so every rejection is a report", function()
		local player = newUnmockedPlayer()

		local promise = TeleportServiceUtils.promiseTeleportClientOnce(826, player)

		local outcome, rejected = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(rejected.result).toEqual(Enum.TeleportResult.Failure)
		expect(rejected.placeId).toEqual(826)
	end)

	it("ignores a report aimed at another player's teleport", function()
		local player = newMock(886005)
		local other = newMock(886006)

		local promise = TeleportServiceUtils.promiseTeleportClientOnce(827, player)
		report(other, 827, Enum.TeleportResult.GameFull, "someone else's problem")

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)

		promise:Destroy()
	end)

	it("ignores a report about a hop to a different place", function()
		local player = newMock(886007)

		local promise = TeleportServiceUtils.promiseTeleportClientOnce(828, player)
		report(player, 999, Enum.TeleportResult.GameFull, "a different destination")

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)

		promise:Destroy()
	end)

	it("rejects with nothing when cancelled, so a caller can tell teardown from a refusal", function()
		local player = newMock(886008)

		local outcome, err = "pending", nil :: any
		local promise = TeleportServiceUtils.promiseTeleportClientOnce(829, player)
		promise:Then(function()
			outcome = "resolved"
		end, function(...)
			outcome, err = "rejected", ...
		end)

		promise:Destroy()

		expect(outcome).toEqual("rejected")
		expect(err).toEqual(nil)
	end)

	it("stops listening once cancelled, so a later report cannot settle it", function()
		local player = newMock(886009)

		local promise = TeleportServiceUtils.promiseTeleportClientOnce(830, player)
		promise:Destroy()

		expect(function()
			report(player, 830, Enum.TeleportResult.GameFull, "too late")
			task.wait(0.1)
		end).never.toThrow()
	end)

	it("errors on a bad placeId, player, or teleport data", function()
		local player = newMock(886010)

		expect(function()
			TeleportServiceUtils.promiseTeleportClientOnce("nope" :: any, player)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClientOnce(831, nil :: any)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClientOnce(831, player, "nope" :: any)
		end).toThrow()
	end)

	it("refuses to teleport anyone but the local player", function()
		local localPlayer = newMock(886011)
		local someoneElse = newMock(886012);
		(localPlayer :: any).Parent = Workspace
		local restoreLocalPlayer = PlayerMock.setMockedLocalPlayer(localPlayer)

		expect(function()
			TeleportServiceUtils.promiseTeleportClientOnce(832, someoneElse)
		end).toThrow()

		-- ...and still sends the one player it may.
		local promise = TeleportServiceUtils.promiseTeleportClientOnce(832, localPlayer)
		expect(readHop(localPlayer, 832).via).toEqual("Teleport")

		promise:Destroy()
		restoreLocalPlayer()
	end)
end)

describe("TeleportServiceUtils.promiseTeleport (server)", function()
	it("sends the batch through TeleportAsync, resolving with the engine's result", function()
		local player = newMock(887001)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ SlotId = "batched" })

		local result = TeleportServiceUtils.promiseTeleport(840, { player }, options):Wait()

		expect(result).toEqual(nil)
		expect(readHop(player, 840).via).toEqual("TeleportAsync")
		expect(readHop(player, 840).teleportData.SlotId).toEqual("batched")
	end)

	it("takes a config instead of options, building the options the batch needs", function()
		local player = newMock(887002)

		TeleportServiceUtils.promiseTeleport(841, { player }, { teleportData = { SlotId = "from-config" } }):Wait()

		expect(readHop(player, 841).via).toEqual("TeleportAsync")
		expect(readHop(player, 841).teleportData.SlotId).toEqual("from-config")
	end)

	it("retries a throwing request, then rejects once the attempts are spent", function()
		local player = newUnmockedPlayer()

		local promise = TeleportServiceUtils.promiseTeleport(842, { player }, {
			maxAttempts = 3,
			retryWait = 0,
			printWarning = false,
		})

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(err).toContain("3 times")
	end)

	-- The engine accepts the request and refuses it a moment later, which is what a paid-access
	-- destination does. Without a grace window that refusal reaches nobody: the promise has already
	-- resolved, so whatever was waiting on the hop waits forever.
	describe("initFailedGraceSeconds", function()
		it("rejects with a refusal raised after the request was accepted", function()
			local player = newMock(887010)

			local promise = TeleportServiceUtils.promiseTeleport(844, { player }, {
				maxAttempts = 1,
				retryWait = 0,
				printWarning = false,
				initFailedGraceSeconds = 5,
			})

			awaitHop(player, 844)
			report(player, 844, Enum.TeleportResult.Unauthorized, "buy the game")

			local outcome, err = PromiseTestUtils.awaitOutcome(promise)
			expect(outcome).toEqual("rejected")
			expect(err.result).toEqual(Enum.TeleportResult.Unauthorized)
			expect(tostring(err)).toContain("buy the game")
		end)

		it("resolves once the window passes quietly, the hop being underway", function()
			local player = newMock(887011)

			local promise = TeleportServiceUtils.promiseTeleport(845, { player }, {
				maxAttempts = 1,
				retryWait = 0,
				initFailedGraceSeconds = 0.2,
			})

			expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
			local ok, result = promise:Yield()
			expect(ok).toEqual(true)
			-- Nil is what an all-mock batch resolves with: no engine call was made to return a result.
			expect(result).toEqual(nil)
		end)

		it("ignores a report that means the hop is still running", function()
			local player = newMock(887012)

			local promise = TeleportServiceUtils.promiseTeleport(846, { player }, {
				maxAttempts = 1,
				retryWait = 0,
				initFailedGraceSeconds = 0.4,
			})

			awaitHop(player, 846)
			report(player, 846, Enum.TeleportResult.Success, "on your way")

			local ok = promise:Yield()
			expect(ok).toEqual(true)
		end)

		it("spends an attempt on a refusal worth retrying", function()
			local player = newMock(887013)
			local attempts = 0

			local promise = TeleportServiceUtils.promiseTeleport(847, { player }, {
				maxAttempts = 2,
				retryWait = 0,
				printWarning = false,
				initFailedGraceSeconds = 5,
			})

			-- Each attempt writes its own hop record; clearing it is how the next one becomes visible.
			for _ = 1, 2 do
				awaitHop(player, 847)
				attempts += 1
				clearHop(player, 847)
				report(player, 847, Enum.TeleportResult.GameFull, `full {attempts}`)
			end

			local outcome = PromiseTestUtils.awaitOutcome(promise)
			expect(outcome).toEqual("rejected")
			expect(attempts).toEqual(2)
		end)

		it("resolves on acceptance without a window, as every server call did before", function()
			local player = newMock(887014)

			local promise = TeleportServiceUtils.promiseTeleport(848, { player }, { maxAttempts = 1, retryWait = 0 })

			expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)

			-- Reported afterwards and unheard, which is the behaviour a caller opts out of by leaving the
			-- window unset rather than something this test wants.
			report(player, 848, Enum.TeleportResult.Unauthorized, "too late to matter")

			local ok = promise:Yield()
			expect(ok).toEqual(true)
		end)
	end)
end)

describe("TeleportServiceUtils.promiseTeleportClient", function()
	beforeEach(function()
		pretendClient()
	end)

	it("is a transparent shell: promiseTeleport reaches the same client request", function()
		local player = newMock(887101)

		local promise = TeleportServiceUtils.promiseTeleport(843, player, { teleportData = { SlotId = "direct" } })

		local hop = readHop(player, 843)
		expect(hop.via).toEqual("Teleport")
		expect(hop.teleportData.SlotId).toEqual("direct")

		promise:Destroy()
	end)

	it("teleports on the spot, carrying the config's teleport data", function()
		local player = newMock(885001)

		TeleportServiceUtils.promiseTeleportClient(800, player, { teleportData = { SlotId = "abc" } })

		local hop = readHop(player, 800)
		expect(hop.via).toEqual("Teleport")
		expect(hop.teleportData.SlotId).toEqual("abc")
	end)

	it("teleports with no data at all when no config is given", function()
		local player = newMock(885002)

		TeleportServiceUtils.promiseTeleportClient(801, player)

		expect(readHop(player, 801).via).toEqual("Teleport")
	end)

	it("stays pending, because a teleport that works ends with the player gone", function()
		local player = newMock(885003)

		local promise = TeleportServiceUtils.promiseTeleportClient(802, player)

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
	end)

	it("teleports again after the engine refuses, carrying the same data", function()
		local player = newMock(885004)

		local promise = TeleportServiceUtils.promiseTeleportClient(803, player, {
			teleportData = { SlotId = "retry-me" },
			retryWait = 0,
		})

		clearHop(player, 803)
		refuse(player, 803, "server full")

		expect(awaitHop(player, 803).teleportData.SlotId).toEqual("retry-me")
		expect(promise:IsPending()).toEqual(true)

		promise:Destroy()
	end)

	it("keeps retrying until the attempts are spent, then rejects naming the last refusal", function()
		local player = newMock(885005)

		local promise = TeleportServiceUtils.promiseTeleportClient(804, player, { maxAttempts = 3, retryWait = 0 })

		refuse(player, 804, "refusal 1")
		clearHop(player, 804)
		awaitHop(player, 804)
		refuse(player, 804, "refusal 2")
		clearHop(player, 804)
		awaitHop(player, 804)
		refuse(player, 804, "refusal 3")

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(err).toContain("refusal 3")
		expect(err).toContain("3 times")
		expect(err).toContain("804")
	end)

	it("gives up on the first refusal when the config allows a single attempt", function()
		local player = newMock(885006)

		local promise = TeleportServiceUtils.promiseTeleportClient(805, player, { maxAttempts = 1, retryWait = 0 })

		clearHop(player, 805)
		refuse(player, 805, "nope")

		local outcome = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(readHop(player, 805)).toEqual(nil)
	end)

	it("waits the configured backoff before trying again", function()
		local player = newMock(885007)

		local promise = TeleportServiceUtils.promiseTeleportClient(806, player, { retryWait = 0.5 })

		clearHop(player, 806)
		refuse(player, 806, "not yet")

		task.wait(0.1)
		expect(readHop(player, 806)).toEqual(nil)

		expect(awaitHop(player, 806).via).toEqual("Teleport")

		promise:Destroy()
	end)

	it("ignores a refusal aimed at another player's teleport", function()
		local player = newMock(885008)
		local other = newMock(885009)

		local promise = TeleportServiceUtils.promiseTeleportClient(807, player, { maxAttempts = 1, retryWait = 0 })

		clearHop(player, 807)
		refuse(other, 807, "someone else's problem")

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)
		expect(readHop(player, 807)).toEqual(nil)

		promise:Destroy()
	end)

	it("ignores a refusal of a hop to a different place", function()
		local player = newMock(885010)

		local promise = TeleportServiceUtils.promiseTeleportClient(808, player, { maxAttempts = 1, retryWait = 0 })

		refuse(player, 999, "a different destination")

		expect(PromiseTestUtils.awaitSettled(promise, 0.2)).toEqual(false)

		promise:Destroy()
	end)

	it("rejects with nothing when cancelled, so a caller can tell teardown from a failure", function()
		local player = newMock(885011)

		local outcome, err = "pending", nil :: any
		local promise = TeleportServiceUtils.promiseTeleportClient(809, player)
		promise:Then(function()
			outcome = "resolved"
		end, function(...)
			outcome, err = "rejected", ...
		end)

		promise:Destroy()

		expect(outcome).toEqual("rejected")
		expect(err).toEqual(nil)
	end)

	it("stops retrying once cancelled, including a backoff already counting down", function()
		local player = newMock(885012)

		local promise = TeleportServiceUtils.promiseTeleportClient(810, player, { retryWait = 0.1 })

		refuse(player, 810, "will retry")
		promise:Destroy()
		clearHop(player, 810)

		-- Well past the backoff.
		task.wait(0.3)
		expect(readHop(player, 810)).toEqual(nil)
	end)

	it("ignores a refusal that lands after it has already given up", function()
		local player = newMock(885013)

		local promise = TeleportServiceUtils.promiseTeleportClient(811, player, { maxAttempts = 1, retryWait = 0 })

		refuse(player, 811, "first")
		local outcome = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")

		clearHop(player, 811)
		refuse(player, 811, "second")

		task.wait(0.1)
		expect(readHop(player, 811)).toEqual(nil)
	end)

	it("rejects when the engine raises instead of refusing through the event", function()
		local player = newUnmockedPlayer()

		local promise
		expect(function()
			promise = TeleportServiceUtils.promiseTeleportClient(813, player, { maxAttempts = 1, retryWait = 0 })
		end).never.toThrow()

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(err).toContain("813")
		expect(err).toContain("1 times")
	end)

	it("retries a raised refusal like any other, then rejects once the attempts are spent", function()
		local player = newUnmockedPlayer()

		local promise = TeleportServiceUtils.promiseTeleportClient(814, player, { maxAttempts = 3, retryWait = 0 })

		local outcome, err = PromiseTestUtils.awaitOutcome(promise)
		expect(outcome).toEqual("rejected")
		expect(err).toContain("3 times")
	end)

	it("gives up the moment a refusal will only repeat, without spending the budget", function()
		for _, result in TERMINAL do
			local player = newMock(886300 + result.Value)

			local promise = TeleportServiceUtils.promiseTeleportClient(815, player, {
				maxAttempts = 5,
				retryWait = 0,
				printWarning = false,
			})

			clearHop(player, 815)
			report(player, 815, result, "will not change")

			local outcome, rejected = PromiseTestUtils.awaitOutcome(promise)

			-- Rejected with the report itself rather than the retry wrapper's summary: nothing was
			-- retried, so there is nothing to summarize, and the caller still has the result.
			expect({
				result = result.Name,
				outcome = outcome,
				rejectedResult = rejected.result,
				secondHop = readHop(player, 815),
			}).toEqual({
				result = result.Name,
				outcome = "rejected",
				rejectedResult = result,
				secondHop = nil,
			})
		end
	end)

	it("never asks again while the engine says the hop is underway", function()
		for _, result in IN_FLIGHT do
			local player = newMock(886400 + result.Value)

			local promise = TeleportServiceUtils.promiseTeleportClient(816, player, { retryWait = 0 })

			clearHop(player, 816)
			report(player, 816, result, "still going")

			task.wait(0.1)
			expect({
				result = result.Name,
				secondHop = readHop(player, 816),
				settled = promise:IsPending() == false,
			}).toEqual({
				result = result.Name,
				secondHop = nil,
				settled = false,
			})

			promise:Destroy()
		end
	end)

	it("holds one request at a time: the next only goes out after the last has rejected", function()
		local player = newMock(886500)

		local promise = TeleportServiceUtils.promiseTeleportClient(817, player, {
			maxAttempts = 3,
			retryWait = 0.3,
			printWarning = false,
		})

		clearHop(player, 817)
		refuse(player, 817, "attempt 1 refused")

		-- The refusal is in and the backoff is running, so for that whole window no request exists.
		task.wait(0.1)
		expect(readHop(player, 817)).toEqual(nil)

		expect(awaitHop(player, 817).via).toEqual("Teleport")

		promise:Destroy()
	end)

	it("errors on a bad placeId, player, or config", function()
		local player = newMock(885014)

		expect(function()
			TeleportServiceUtils.promiseTeleportClient("nope" :: any, player)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, nil :: any)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, "nope" :: any)
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, { maxAttempts = 0 })
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, { retryWait = -1 })
		end).toThrow()
		expect(function()
			TeleportServiceUtils.promiseTeleportClient(812, player, { teleportData = "nope" :: any })
		end).toThrow()
	end)
end)

-- The record JSON round-trips its teleport data, exactly as a real teleport serializes it. The
-- fragile part is the per-player map's numeric-string keys.
describe("TeleportServiceUtils teleport data (consumer envelope round-trip)", function()
	it("recovers the arriving player's merged slice from a recorded envelope", function()
		local userId = 884001
		local player = newMock(userId)

		local envelope = TeleportDataEnvelopeUtils.build(
			{ WorldIndex = 3, Reason = "journey" },
			{ [tostring(userId)] = { SlotId = "abc-123", Ephemeral = true, Trace = { Origin = "hub", Depth = 2 } } }
		)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(envelope)

		TeleportServiceUtils.teleportAsync(4242, { player }, options)

		local recorded = PlayerMock.readLookup(player, "TeleportService.Teleport", 4242)
		expect(TeleportDataEnvelopeUtils.readSlice(recorded.teleportData, userId)).toEqual({
			WorldIndex = 3,
			Reason = "journey",
			SlotId = "abc-123",
			Ephemeral = true,
			Trace = { Origin = "hub", Depth = 2 },
		})
	end)

	it("keeps per-player slices distinct after the record's JSON round-trip", function()
		local a = newMock(884101)
		local b = newMock(884102)

		local envelope = TeleportDataEnvelopeUtils.build(nil, {
			["884101"] = { SlotId = "for-a" },
			["884102"] = { SlotId = "for-b" },
		})
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(envelope)

		TeleportServiceUtils.teleportAsync(4243, { a, b }, options)

		local dataA = PlayerMock.readLookup(a, "TeleportService.Teleport", 4243).teleportData
		local dataB = PlayerMock.readLookup(b, "TeleportService.Teleport", 4243).teleportData
		expect(TeleportDataEnvelopeUtils.readSlice(dataA, 884101)).toEqual({ SlotId = "for-a" })
		expect(TeleportDataEnvelopeUtils.readSlice(dataB, 884102)).toEqual({ SlotId = "for-b" })
	end)
end)
