--!nonstrict
--[[
	Characterization coverage for DataStorePromises, using DataStoreMock as the datastore.
	@class DataStorePromises.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStorePromises = require("DataStorePromises")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStorePromises.isDataStore", function()
	it("should be true for a DataStoreMock", function()
		expect(DataStorePromises.isDataStore(DataStoreMock.new())).toEqual(true)
	end)

	it("should be false for a plain table", function()
		expect(DataStorePromises.isDataStore({})).toEqual(false)
	end)

	it("should be false for nil", function()
		expect(DataStorePromises.isDataStore(nil)).toEqual(false)
	end)

	it("should be false for primitives", function()
		expect(DataStorePromises.isDataStore(5)).toEqual(false)
		expect(DataStorePromises.isDataStore("str")).toEqual(false)
		expect(DataStorePromises.isDataStore(true)).toEqual(false)
	end)

	it("should be true for an Instance", function()
		expect(DataStorePromises.isDataStore(Instance.new("Folder"))).toEqual(true)
	end)
end)

describe("DataStorePromises.promiseDataStore", function()
	it("should resolve an Instance in the cloud test place", function()
		local promise = DataStorePromises.promiseDataStore("SpecStore", "SpecScope")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok, dataStore = promise:Yield()
		expect(ok).toEqual(true)
		expect(typeof(dataStore)).toEqual("Instance")
	end)

	it("should throw synchronously for a non-string name", function()
		expect(function()
			DataStorePromises.promiseDataStore(5 :: any, "scope")
		end).toThrow("Bad name")
	end)

	it("should throw synchronously for a non-string scope", function()
		expect(function()
			DataStorePromises.promiseDataStore("name", 5 :: any)
		end).toThrow("Bad scope")
	end)
end)

describe("DataStorePromises.getAsync", function()
	it("should resolve with the stored value", function()
		local mock = DataStoreMock.new()
		mock:SetRaw("key", { coins = 5 })

		local promise = DataStorePromises.getAsync(mock, "key")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value.coins).toEqual(5)
	end)

	it("should resolve with nil for an unset key", function()
		local mock = DataStoreMock.new()

		local promise = DataStorePromises.getAsync(mock, "missing")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(nil)
	end)

	it("should reject when the store fails all requests", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local promise = DataStorePromises.getAsync(mock, "key")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok = promise:Yield()
		expect(ok).toEqual(false)
	end)

	it("should throw synchronously for a bad robloxDataStore", function()
		expect(function()
			DataStorePromises.getAsync({} :: any, "key")
		end).toThrow("Bad robloxDataStore")
	end)

	it("should throw synchronously for a non-string key", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.getAsync(mock, 5 :: any)
		end).toThrow("Bad key")
	end)
end)

describe("DataStorePromises.updateAsync", function()
	it("should resolve with the updated value", function()
		local mock = DataStoreMock.new()
		mock:SetRaw("key", 1)

		local promise = DataStorePromises.updateAsync(mock, "key", function(current)
			return (current or 0) + 1
		end)
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(2)
	end)

	it("should pass the current value to the transform and update the store", function()
		local mock = DataStoreMock.new()
		mock:SetRaw("key", 10)

		local seen
		local promise = DataStorePromises.updateAsync(mock, "key", function(current)
			seen = current
			return current + 5
		end)
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok = promise:Yield()
		expect(ok).toEqual(true)
		expect(seen).toEqual(10)
		expect(mock:GetRaw("key")).toEqual(15)
	end)

	it("should reject when the store fails all requests", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local promise = DataStorePromises.updateAsync(mock, "key", function()
			return 1
		end)
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok = promise:Yield()
		expect(ok).toEqual(false)
	end)

	it("should throw synchronously for a bad robloxDataStore", function()
		expect(function()
			DataStorePromises.updateAsync({} :: any, "key", function()
				return 1
			end)
		end).toThrow("Bad robloxDataStore")
	end)

	it("should throw synchronously for a non-string key", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.updateAsync(mock, 5 :: any, function()
				return 1
			end)
		end).toThrow("Bad key")
	end)

	it("should throw synchronously for a non-function updateFunc", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.updateAsync(mock, "key", 5 :: any)
		end).toThrow("Bad updateFunc")
	end)
end)

describe("DataStorePromises.setAsync", function()
	it("should resolve true and write the value", function()
		local mock = DataStoreMock.new()

		local promise = DataStorePromises.setAsync(mock, "key", "value")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(true)
		expect(mock:GetRaw("key")).toEqual("value")
	end)

	it("should accept userIds", function()
		local mock = DataStoreMock.new()

		local promise = DataStorePromises.setAsync(mock, "key", "value", { 111, 222 })
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok = promise:Yield()
		expect(ok).toEqual(true)
	end)

	it("should reject when the store fails all requests", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local promise = DataStorePromises.setAsync(mock, "key", "value")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok = promise:Yield()
		expect(ok).toEqual(false)
	end)

	it("should throw synchronously for a bad robloxDataStore", function()
		expect(function()
			DataStorePromises.setAsync({} :: any, "key", "value")
		end).toThrow("Bad robloxDataStore")
	end)

	it("should throw synchronously for a non-string key", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.setAsync(mock, 5 :: any, "value")
		end).toThrow("Bad key")
	end)

	it("should throw synchronously for bad userIds", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.setAsync(mock, "key", "value", "notatable" :: any)
		end).toThrow("Bad userIds")
	end)
end)

describe("DataStorePromises.promiseIncrementAsync", function()
	it("should resolve true and increment the value", function()
		local mock = DataStoreMock.new()
		mock:SetRaw("key", 5)

		local promise = DataStorePromises.promiseIncrementAsync(mock, "key", 3)
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(true)
		expect(mock:GetRaw("key")).toEqual(8)
	end)

	it("should reject when the store fails all requests", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local promise = DataStorePromises.promiseIncrementAsync(mock, "key", 1)
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok = promise:Yield()
		expect(ok).toEqual(false)
	end)

	it("should throw synchronously for a bad robloxDataStore", function()
		expect(function()
			DataStorePromises.promiseIncrementAsync({} :: any, "key", 1)
		end).toThrow("Bad robloxDataStore")
	end)

	it("should throw synchronously for a non-string key", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.promiseIncrementAsync(mock, 5 :: any, 1)
		end).toThrow("Bad key")
	end)

	it("should throw synchronously for a non-number delta", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.promiseIncrementAsync(mock, "key", "notanumber" :: any)
		end).toThrow("Bad delta")
	end)
end)

describe("DataStorePromises.removeAsync", function()
	it("should resolve true and clear the key", function()
		local mock = DataStoreMock.new()
		mock:SetRaw("key", "value")

		local promise = DataStorePromises.removeAsync(mock, "key")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok, value = promise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(true)
		expect(mock:GetRaw("key")).toEqual(nil)
	end)

	it("should reject when the store fails all requests", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local promise = DataStorePromises.removeAsync(mock, "key")
		if not PromiseTestUtils.awaitSettled(promise) then
			expect("promise hung").toEqual("promise settled")
			return
		end

		local ok = promise:Yield()
		expect(ok).toEqual(false)
	end)

	it("should throw synchronously for a bad robloxDataStore", function()
		expect(function()
			DataStorePromises.removeAsync({} :: any, "key")
		end).toThrow("Bad robloxDataStore")
	end)

	it("should throw synchronously for a non-string key", function()
		local mock = DataStoreMock.new()
		expect(function()
			DataStorePromises.removeAsync(mock, 5 :: any)
		end).toThrow("Bad key")
	end)
end)
