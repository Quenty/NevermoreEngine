--!strict
--[=[
	Helper functions for maids and promises

	@class PromiseMaidUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Promise = require("Promise")

local PromiseMaidUtils = {}

--[=[
	Calls the callback with a maid for the lifetime of the promise.
]=]
function PromiseMaidUtils.whilePromise<T...>(promise: Promise.Promise<T...>, callback: (Maid.Maid) -> ()): Maid.Maid
	assert(Promise.isPromise(promise), "Bad promise")
	assert(type(callback) == "function", "Bad callback")

	local maid = Maid.new()

	if not promise:IsPending() then
		return maid
	end

	promise:Finally(function()
		maid:DoCleaning()
	end)

	callback(maid)

	-- Cleanup immediately if the callback resolves the promise immeidately
	if not promise:IsPending() then
		maid:DoCleaning()
	end

	return maid
end

return PromiseMaidUtils
