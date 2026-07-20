--!nonstrict
--[[
	Characterizes how the datastore layer handles user-supplied saving callbacks that misbehave:
	throw, return a rejected promise, or yield forever. Several are genuine data-integrity failure
	modes, so pinning them documents the contract callers must honor. The removing-callback matrix
	lives with the manager it exercises in PlayerDataStoreManager.RemovalCallbacks.spec.lua.

	@class DataStoreHookErrors.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStore saving callbacks that misbehave", function()
	it("runs a well-behaved saving callback and completes the save", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")

		local ran = false
		dataStore:AddSavingCallback(function()
			ran = true
		end)
		dataStore:Store("x", 1)

		local promise = dataStore:Save()
		if not PromiseTestUtils.awaitSettled(promise, 5) then
			expect("hung").toEqual("settled")
			controller:destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)
		expect(ran).toEqual(true)

		controller:destroy()
	end)

	it("isolates a throwing saving callback into a clean save rejection, preserving the stack trace", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")

		dataStore:AddSavingCallback(function()
			error("saving callback boom")
		end)
		dataStore:Store("x", 1)

		local outcome, err = PromiseTestUtils.awaitOutcome(dataStore:Save(), 5)
		expect(outcome).toEqual("rejected")

		-- The rejection preserves the original message and the invoking frame, so the failure stays debuggable.
		expect(string.find(tostring(err), "saving callback boom", 1, true) ~= nil).toEqual(true)
		expect(string.find(tostring(err), "PromiseInvokeSavingCallbacks", 1, true) ~= nil).toEqual(true)

		controller:destroy()
	end)

	it("rejects the save when a saving callback returns a rejected promise (and does not persist)", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")

		dataStore:AddSavingCallback(function()
			return Promise.rejected("nope")
		end)
		dataStore:Store("x", 1)

		expect((PromiseTestUtils.awaitOutcome(dataStore:Save(), 5))).toEqual("rejected")
		expect(controller.mock:GetRaw("key")).toEqual(nil)

		controller:destroy()
	end)

	it("blocks the save while a saving callback yields (never resolves)", function()
		local controller = DataStoreTestUtils.setup()
		local dataStore = controller.newDataStore("key")

		dataStore:AddSavingCallback(function()
			return Promise.new()
		end)
		dataStore:Store("x", 1)

		local promise = dataStore:Save()
		expect(PromiseTestUtils.awaitSettled(promise, 2)).toEqual(false)

		controller:destroy()
	end)
end)
