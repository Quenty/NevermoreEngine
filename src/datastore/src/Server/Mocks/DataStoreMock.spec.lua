--!nonstrict
--[[
	Sanity coverage for the DataStoreMock itself, so tests that rely on it can trust its
	datastore-faithful behavior (deep-copy round-tripping, UpdateAsync transform semantics,
	and failure injection).

	Note: the mock's GetAsync/UpdateAsync/RemoveAsync return `(value, keyInfo)`; jest-lua's
	`expect` takes exactly one argument, so those results are wrapped in parens to keep only
	the value.

	@class DataStoreMock.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStoreMock.isDataStoreMock", function()
	it("should be true for a mock", function()
		expect(DataStoreMock.isDataStoreMock(DataStoreMock.new())).toEqual(true)
	end)

	it("should be false for a plain table", function()
		expect(DataStoreMock.isDataStoreMock({})).toEqual(false)
	end)

	it("should be false for a table with a different metatable", function()
		expect(DataStoreMock.isDataStoreMock(setmetatable({}, { __index = {} }))).toEqual(false)
	end)

	it("should be false for nil and primitives", function()
		expect(DataStoreMock.isDataStoreMock(nil)).toEqual(false)
		expect(DataStoreMock.isDataStoreMock(5)).toEqual(false)
		expect(DataStoreMock.isDataStoreMock("str")).toEqual(false)
		expect(DataStoreMock.isDataStoreMock(true)).toEqual(false)
	end)
end)

describe("DataStoreMock:GetAsync", function()
	it("should return nil for an unset key", function()
		local store = DataStoreMock.new()
		expect((store:GetAsync("missing"))).toEqual(nil)
	end)

	it("should return the value set via SetAsync", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", 42)
		expect((store:GetAsync("key"))).toEqual(42)
	end)

	it("should return a keyInfo as its second result", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", 1)

		local _, keyInfo = store:GetAsync("key")
		expect(keyInfo).never.toBeNil()
		expect(type(keyInfo.GetUserIds)).toEqual("function")
		expect(type(keyInfo.GetMetadata)).toEqual("function")
	end)

	it("should return a deep copy so mutating the result does not affect storage", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", { coins = 5 })

		local first = store:GetAsync("key")
		first.coins = 999

		local second = store:GetAsync("key")
		expect(second.coins).toEqual(5)
	end)

	it("should return independent copies across nested tables", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", { nested = { list = { 1, 2, 3 } } })

		local first = store:GetAsync("key")
		table.insert(first.nested.list, 4)

		local second = store:GetAsync("key")
		expect(#second.nested.list).toEqual(3)
	end)
end)

describe("DataStoreMock:SetAsync", function()
	it("should overwrite an existing value", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", "first")
		store:SetAsync("key", "second")
		expect((store:GetAsync("key"))).toEqual("second")
	end)

	it("should not alias the stored value to the caller's table", function()
		local store = DataStoreMock.new()
		local value = { coins = 5 }
		store:SetAsync("key", value)
		value.coins = 999
		expect((store:GetAsync("key")).coins).toEqual(5)
	end)

	it("should record associated userIds", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", 1, { 111, 222 })

		local _, keyInfo = store:GetAsync("key")
		expect(keyInfo:GetUserIds()).toEqual({ 111, 222 })
	end)
end)

describe("DataStoreMock:UpdateAsync", function()
	it("should pass the current value to the transform", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", 1)

		local seen
		store:UpdateAsync("key", function(current)
			seen = current
			return current + 1
		end)

		expect(seen).toEqual(1)
		expect((store:GetAsync("key"))).toEqual(2)
	end)

	it("should pass nil to the transform for an unset key", function()
		local store = DataStoreMock.new()

		local seen = "unset"
		store:UpdateAsync("key", function(current)
			seen = current
			return 1
		end)

		expect(seen).toEqual(nil)
		expect((store:GetAsync("key"))).toEqual(1)
	end)

	it("should return the newly written value", function()
		local store = DataStoreMock.new()
		local written = store:UpdateAsync("key", function()
			return { coins = 3 }
		end)
		expect(written.coins).toEqual(3)
	end)

	it("should cancel the update when the transform returns nil", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", "original")

		store:UpdateAsync("key", function()
			return nil
		end)

		expect((store:GetAsync("key"))).toEqual("original")
	end)

	it("should deep copy the current value so the transform cannot mutate storage in place", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", { coins = 5 })

		store:UpdateAsync("key", function(current)
			current.coins = 999
			return nil -- cancel, so only an in-place mutation could leak
		end)

		expect((store:GetAsync("key")).coins).toEqual(5)
	end)

	it("should pass a keyInfo to the transform", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", 1, { 42 })

		local seenUserIds
		store:UpdateAsync("key", function(_current, keyInfo)
			seenUserIds = keyInfo:GetUserIds()
			return 2
		end)

		expect(seenUserIds).toEqual({ 42 })
	end)
end)

describe("DataStoreMock:RemoveAsync", function()
	it("should return the removed value and clear the key", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", "value")

		expect((store:RemoveAsync("key"))).toEqual("value")
		expect((store:GetAsync("key"))).toEqual(nil)
	end)

	it("should return nil when removing a missing key", function()
		local store = DataStoreMock.new()
		expect((store:RemoveAsync("missing"))).toEqual(nil)
	end)
end)

describe("DataStoreMock:IncrementAsync", function()
	it("should increment from zero", function()
		local store = DataStoreMock.new()
		expect(store:IncrementAsync("key", 5)).toEqual(5)
		expect(store:IncrementAsync("key", 3)).toEqual(8)
	end)

	it("should default the delta to 1", function()
		local store = DataStoreMock.new()
		expect(store:IncrementAsync("key")).toEqual(1)
	end)

	it("should throw when incrementing a non-number value", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", "not a number")
		expect(function()
			store:IncrementAsync("key", 1)
		end).toThrow("Cannot increment non-number value")
	end)
end)

describe("DataStoreMock failure injection", function()
	it("should throw on every request while failing all requests", function()
		local store = DataStoreMock.new()
		store:FailAllRequests()

		expect(function()
			store:GetAsync("key")
		end).toThrow("509")
		expect(function()
			store:UpdateAsync("key", function()
				return 1
			end)
		end).toThrow("509")
		expect(function()
			store:SetAsync("key", 1)
		end).toThrow("509")
		expect(function()
			store:RemoveAsync("key")
		end).toThrow("509")
	end)

	it("should throw the 509 message by default", function()
		local store = DataStoreMock.new()
		store:FailAllRequests()

		local ok, err = pcall(function()
			store:GetAsync("key")
		end)
		expect(ok).toEqual(false)
		expect(string.find(tostring(err), "509", 1, true) ~= nil).toEqual(true)
	end)

	it("should throw a custom message when provided", function()
		local store = DataStoreMock.new()
		store:FailAllRequests("custom boom")

		local ok, err = pcall(function()
			store:GetAsync("key")
		end)
		expect(ok).toEqual(false)
		expect(string.find(tostring(err), "custom boom", 1, true) ~= nil).toEqual(true)
	end)

	it("should recover after StopFailing", function()
		local store = DataStoreMock.new()
		store:FailAllRequests()
		store:StopFailing()

		store:SetAsync("key", 1)
		expect((store:GetAsync("key"))).toEqual(1)
	end)

	it("should fail only the next N requests then recover", function()
		local store = DataStoreMock.new()
		store:FailNextRequests(2)

		expect(function()
			store:GetAsync("key")
		end).toThrow("509")
		expect(function()
			store:GetAsync("key")
		end).toThrow("509")

		-- Third request succeeds
		store:SetAsync("key", "ok")
		expect((store:GetAsync("key"))).toEqual("ok")
	end)

	it("should not fail when FailNextRequests count is zero", function()
		local store = DataStoreMock.new()
		store:FailNextRequests(0)
		store:SetAsync("key", 1)
		expect((store:GetAsync("key"))).toEqual(1)
	end)

	it("should support a custom error injector targeting a specific method", function()
		local store = DataStoreMock.new()
		store:SetErrorInjector(function(ctx)
			if ctx.method == "UpdateAsync" then
				return "no updates allowed"
			end
			return nil
		end)

		-- Reads are fine
		expect(function()
			store:GetAsync("key")
		end).never.toThrow()

		-- Updates fail
		expect(function()
			store:UpdateAsync("key", function()
				return 1
			end)
		end).toThrow("no updates allowed")
	end)

	it("should still count failed requests", function()
		local store = DataStoreMock.new()
		store:FailAllRequests()

		pcall(function()
			store:GetAsync("key")
		end)
		pcall(function()
			store:GetAsync("key")
		end)

		expect(store:GetCallCount("GetAsync")).toEqual(2)
		expect(store:GetCallCount()).toEqual(2)
	end)

	it("should not mutate storage when a request fails", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", "original")
		store:FailAllRequests()

		pcall(function()
			store:SetAsync("key", "should not persist")
		end)

		store:StopFailing()
		expect((store:GetAsync("key"))).toEqual("original")
	end)
end)

describe("DataStoreMock call counting", function()
	it("should count per-method and in total", function()
		local store = DataStoreMock.new()
		store:GetAsync("a")
		store:GetAsync("b")
		store:SetAsync("a", 1)

		expect(store:GetCallCount("GetAsync")).toEqual(2)
		expect(store:GetCallCount("SetAsync")).toEqual(1)
		expect(store:GetCallCount("UpdateAsync")).toEqual(0)
		expect(store:GetCallCount()).toEqual(3)
	end)
end)

describe("DataStoreMock serialized-size overflow", function()
	it("should not enforce any size limit by default", function()
		local store = DataStoreMock.new()
		-- A value far larger than a small limit persists fine when no limit is configured.
		expect(function()
			store:SetAsync("key", string.rep("A", 100000))
		end).never.toThrow()
	end)

	it("should reject a SetAsync whose value exceeds the configured limit", function()
		local store = DataStoreMock.new()
		store:SetMaxValueLength(1024)

		expect(function()
			store:SetAsync("key", string.rep("A", 4096))
		end).toThrow("maximum size limit")
	end)

	it("should allow a SetAsync whose value fits within the configured limit", function()
		local store = DataStoreMock.new()
		store:SetMaxValueLength(1024)

		expect(function()
			store:SetAsync("key", "small")
		end).never.toThrow()
		expect((store:GetAsync("key"))).toEqual("small")
	end)

	it("should not persist an oversized value that was rejected", function()
		local store = DataStoreMock.new()
		store:SetAsync("key", "original")
		store:SetMaxValueLength(1024)

		pcall(function()
			store:SetAsync("key", string.rep("A", 4096))
		end)

		store:SetMaxValueLength(nil)
		expect((store:GetAsync("key"))).toEqual("original")
	end)

	it("should reject an UpdateAsync whose returned value exceeds the configured limit", function()
		local store = DataStoreMock.new()
		store:SetMaxValueLength(1024)

		expect(function()
			store:UpdateAsync("key", function()
				return string.rep("A", 4096)
			end)
		end).toThrow("maximum size limit")
	end)

	it("should measure the serialized size of tables, not their length", function()
		local store = DataStoreMock.new()
		store:SetMaxValueLength(64)

		local big = {}
		for i = 1, 100 do
			big[i] = i
		end

		expect(function()
			store:SetAsync("key", big)
		end).toThrow("maximum size limit")
	end)

	it("should stop enforcing once the limit is cleared", function()
		local store = DataStoreMock.new()
		store:SetMaxValueLength(1024)
		store:SetMaxValueLength(nil)

		expect(function()
			store:SetAsync("key", string.rep("A", 4096))
		end).never.toThrow()
	end)
end)

describe("DataStoreMock:ExportRaw / ImportRaw", function()
	it("should round-trip values written through the real datastore APIs", function()
		local sessionA = DataStoreMock.new()
		sessionA:SetAsync("player_1", { coins = 5, inventory = { "sword", "shield" } })
		sessionA:UpdateAsync("player_2", function()
			return { coins = 12, quests = { active = { "eggHunt" }, completed = {} } }
		end)
		sessionA:SetAsync("motd", "Welcome!")

		local json = sessionA:ExportRaw()
		expect(type(json)).toEqual("string")

		local sessionB = DataStoreMock.new()
		sessionB:ImportRaw(json)

		expect((sessionB:GetAsync("player_1"))).toEqual({ coins = 5, inventory = { "sword", "shield" } })
		expect((sessionB:GetAsync("player_2"))).toEqual({
			coins = 12,
			quests = { active = { "eggHunt" }, completed = {} },
		})
		expect((sessionB:GetAsync("motd"))).toEqual("Welcome!")
	end)

	it("should hand out a sane keyInfo for imported keys, like a mock seeded via SetRaw", function()
		local sessionA = DataStoreMock.new()
		sessionA:SetAsync("key", { coins = 5 })
		sessionA:SetAsync("key", { coins = 6 }) -- version bumps stay behind, like SetRaw

		local sessionB = DataStoreMock.new()
		sessionB:ImportRaw(sessionA:ExportRaw())

		local _, keyInfo = sessionB:GetAsync("key")
		expect(keyInfo).never.toBeNil()
		expect(keyInfo.Version).toEqual("0")
		expect(keyInfo:GetUserIds()).toEqual({})
		expect(keyInfo:GetMetadata()).toEqual({})
	end)

	it("should replace, not merge, the existing contents on import", function()
		local source = DataStoreMock.new()
		source:SetAsync("imported", 1)

		local target = DataStoreMock.new()
		target:SetAsync("preexisting", "should be discarded")
		target:SetAsync("imported", "stale value")

		target:ImportRaw(source:ExportRaw())

		expect((target:GetAsync("preexisting"))).toEqual(nil)
		expect((target:GetAsync("imported"))).toEqual(1)
	end)

	it("should discard bookkeeping for keys that survive a replace", function()
		local source = DataStoreMock.new()
		source:SetAsync("key", 1)

		local target = DataStoreMock.new()
		target:SetAsync("key", "old", { 111 })
		target:ImportRaw(source:ExportRaw())

		local _, keyInfo = target:GetAsync("key")
		expect(keyInfo.Version).toEqual("0")
		expect(keyInfo:GetUserIds()).toEqual({})
	end)

	it("should round-trip an empty store", function()
		local empty = DataStoreMock.new()

		local target = DataStoreMock.new()
		target:SetAsync("key", "should be discarded")
		target:ImportRaw(empty:ExportRaw())

		expect((target:GetAsync("key"))).toEqual(nil)
	end)

	it("should export stably across an import cycle", function()
		local sessionA = DataStoreMock.new()
		sessionA:SetAsync("player_1", { coins = 5, nested = { list = { 1, 2, 3 } } })
		sessionA:SetAsync("player_2", true)

		local firstExport = sessionA:ExportRaw()

		local sessionB = DataStoreMock.new()
		sessionB:ImportRaw(firstExport)
		local secondExport = sessionB:ExportRaw()

		-- Key order inside the JSON is not guaranteed, so compare decoded contents.
		local HttpService = game:GetService("HttpService")
		expect(HttpService:JSONDecode(secondExport)).toEqual(HttpService:JSONDecode(firstExport))
	end)

	it("should not alias imported values to later reads", function()
		local source = DataStoreMock.new()
		source:SetAsync("key", { coins = 5 })

		local target = DataStoreMock.new()
		target:ImportRaw(source:ExportRaw())

		local first = target:GetAsync("key")
		first.coins = 999

		expect((target:GetAsync("key")).coins).toEqual(5)
	end)

	it("should throw a clear error for malformed json", function()
		local store = DataStoreMock.new()
		expect(function()
			store:ImportRaw("not json {")
		end).toThrow("Could not decode json")
	end)

	it("should throw when the json is not an object", function()
		local store = DataStoreMock.new()
		expect(function()
			store:ImportRaw('"just a string"')
		end).toThrow()
	end)
end)

describe("DataStoreMock:SetRaw / GetRaw", function()
	it("should seed and read without triggering failures", function()
		local store = DataStoreMock.new()
		store:FailAllRequests()

		store:SetRaw("key", { coins = 7 })
		expect(store:GetRaw("key").coins).toEqual(7)
		-- Raw access does not count as a datastore call
		expect(store:GetCallCount()).toEqual(0)
	end)

	it("should deep copy on SetRaw and GetRaw", function()
		local store = DataStoreMock.new()
		local seed = { coins = 1 }
		store:SetRaw("key", seed)
		seed.coins = 999

		local read = store:GetRaw("key")
		read.coins = 555

		expect(store:GetRaw("key").coins).toEqual(1)
	end)
end)
