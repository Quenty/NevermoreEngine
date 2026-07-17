--!nonstrict
--[[
	Integration coverage for DataStore against a mocked Roblox datastore: the load/save round-trip
	and how it behaves when datastore operations fail (e.g. the 509 Personal-RCC block).

	@class DataStore.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Asserts the promise settled within the timeout and returns whether it is now safe to :Yield(), so
-- a hung promise fails the test instead of freezing the runner.
local function expectSettled(promise, timeout: number?): boolean
	local settled = PromiseTestUtils.awaitSettled(promise, timeout)
	expect(settled).toEqual(true)
	return settled
end

describe("DataStore without session locking", function()
	it("should load the default value when the key is empty", function()
		local dataStore = DataStore.new(DataStoreMock.new(), "player_1")

		local promise = dataStore:Load("coins", 99)
		if not expectSettled(promise) then
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(99)

		dataStore:Destroy()
	end)

	it("should round-trip a stored value through the datastore", function()
		local mock = DataStoreMock.new()

		local writer = DataStore.new(mock, "player_1")
		writer:Store("coins", 5)

		local savePromise = writer:Save()
		if not expectSettled(savePromise) then
			return
		end
		expect((savePromise:Yield())).toEqual(true)

		local reader = DataStore.new(mock, "player_1")
		local loadPromise = reader:Load("coins")
		if not expectSettled(loadPromise) then
			return
		end

		local ok, value = loadPromise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(5)

		writer:Destroy()
		reader:Destroy()
	end)

	it("should round-trip multiple keys and load defaults for missing ones", function()
		local mock = DataStoreMock.new()

		local writer = DataStore.new(mock, "player_1")
		writer:Store("coins", 5)
		writer:Store("gems", 10)
		if not expectSettled(writer:Save()) then
			return
		end

		local reader = DataStore.new(mock, "player_1")
		local promise = reader:LoadAll()
		if not expectSettled(promise) then
			return
		end

		local ok, all = promise:Yield()
		expect(ok).toEqual(true)
		expect(all.coins).toEqual(5)
		expect(all.gems).toEqual(10)

		local missingPromise = reader:Load("missing", "default")
		if not expectSettled(missingPromise) then
			return
		end
		expect((select(2, missingPromise:Yield()))).toEqual("default")

		writer:Destroy()
		reader:Destroy()
	end)

	it("should round-trip substore values", function()
		local mock = DataStoreMock.new()

		local writer = DataStore.new(mock, "player_1")
		writer:GetSubStore("inventory"):Store("sword", true)
		if not expectSettled(writer:Save()) then
			return
		end

		local reader = DataStore.new(mock, "player_1")
		local promise = reader:GetSubStore("inventory"):Load("sword")
		if not expectSettled(promise) then
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(true)

		writer:Destroy()
		reader:Destroy()
	end)

	it("should delete a key so it no longer loads", function()
		local mock = DataStoreMock.new()

		local writer = DataStore.new(mock, "player_1")
		writer:Store("a", 1)
		writer:Store("b", 2)
		if not expectSettled(writer:Save()) then
			return
		end

		writer:Delete("a")
		if not expectSettled(writer:Save()) then
			return
		end

		local reader = DataStore.new(mock, "player_1")
		local promise = reader:LoadAll()
		if not expectSettled(promise) then
			return
		end

		local ok, all = promise:Yield()
		expect(ok).toEqual(true)
		expect(all.a).toEqual(nil)
		expect(all.b).toEqual(2)

		writer:Destroy()
		reader:Destroy()
	end)

	it("should resolve a save when nothing is staged", function()
		local mock = DataStoreMock.new()
		local dataStore = DataStore.new(mock, "player_1")

		if not expectSettled(dataStore:Load("x")) then
			return
		end

		local savePromise = dataStore:Save()
		if not expectSettled(savePromise) then
			return
		end
		expect((savePromise:Yield())).toEqual(true)

		dataStore:Destroy()
	end)

	it("should report load failure (not hang) when the datastore is unavailable", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local dataStore = DataStore.new(mock, "player_1")

		local promise = dataStore:PromiseLoadSuccessful()
		if not expectSettled(promise, 5) then
			return
		end

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(false)

		dataStore:Destroy()
	end)

	it("should reject a save when the datastore goes down after loading", function()
		local mock = DataStoreMock.new()
		local dataStore = DataStore.new(mock, "player_1")

		if not expectSettled(dataStore:Load("x")) then
			return
		end

		mock:FailAllRequests()
		dataStore:Store("x", 1)

		local savePromise = dataStore:Save()
		if not expectSettled(savePromise, 5) then
			return
		end
		expect((savePromise:Yield())).toEqual(false)

		dataStore:Destroy()
	end)

	it("should mark DidLoadFail after a failed load", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local dataStore = DataStore.new(mock, "player_1")
		local promise = dataStore:PromiseLoadSuccessful()
		if not expectSettled(promise, 5) then
			return
		end

		expect(dataStore:DidLoadFail()).toEqual(true)

		dataStore:Destroy()
	end)
end)

describe("DataStore with session locking", function()
	it("should load successfully against a healthy datastore", function()
		local mock = DataStoreMock.new()

		local dataStore = DataStore.new(mock, "player_1")
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not expectSettled(promise, 10) then
			return
		end

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(true)

		dataStore:Destroy()
	end)

	it("surfaces a persistent datastore failure fast instead of hanging", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local dataStore = DataStore.new(mock, "player_1")
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		local promise = dataStore:PromiseLoadSuccessful()
		if not expectSettled(promise, 5) then
			return
		end

		local ok, loadedOk = promise:Yield()
		expect(ok).toEqual(true)
		expect(loadedOk).toEqual(false)

		dataStore:Destroy()
	end)

	it("rejects a failed session-locked load with the preserved datastore error", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests(DataStoreMock.OPERATION_NOT_ALLOWED_509)

		local dataStore = DataStore.new(mock, "player_1")
		dataStore:SetSessionLockingEnabled(true)
		dataStore:SetUserIdList({ 1 })

		-- PromiseLoadSuccessful maps the error to a boolean, so read the rejection from
		-- PromiseViewUpToDate to assert the underlying datastore error propagates.
		local outcome, err = PromiseTestUtils.awaitOutcome(dataStore:PromiseViewUpToDate())

		expect(outcome).toEqual("rejected")
		expect(string.find(tostring(err), "509", 1, true) ~= nil).toEqual(true)

		dataStore:Destroy()
	end)
end)
