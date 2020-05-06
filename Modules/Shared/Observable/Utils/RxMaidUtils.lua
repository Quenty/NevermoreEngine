---
-- @module RxMaidUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Observable = require("Observable")
local Maid = require("Maid")

local RxMaidUtils = {}

function RxMaidUtils.maidUntil(notifier)
	return function(source)
		return Observable.new(function(fire, fail, complete)
			local outerMaid = Maid.new()
			local cancelled = false

			local function cancel()
				outerMaid:DoCleaning()
				cancelled = true
			end

			-- Any value emitted will cancel (complete without any values allows all values to pass)
			outerMaid:GiveTask(notifier:Subscribe(cancel, cancel))

			-- Cancelled immediately? Oh boy.
			if cancelled then
				print("Cancelled immediately")
				outerMaid:DoCleaning()
				return nil
			end

			-- Subscribe!
			outerMaid:GiveTask(
				source:Subscribe(function(...)
					local maid = Maid.new()
					outerMaid:GiveTask(maid)
					fire(maid, ...)
				end),
				fail,
				complete)

			return outerMaid
		end)
	end
end

function RxMaidUtils.maidWhilePending()
	return function(source)
		return Observable.new(function(fire, fail, complete)
			local outerMaid = Maid.new()

			outerMaid:GiveTask(source:Subscribe(
				function(...)
					local maid = Maid.new()
					outerMaid:GiveTask(maid)
					fire(maid, ...)
				end,
				function(...)
					fail(...)
					outerMaid:DoCleaning()
				end,
				function()
					complete()
					outerMaid:DoCleaning()
				end))

			return outerMaid
		end)
	end
end

function RxMaidUtils.uniqueMaid()
	return function(source)
		return Observable.new(function(fire, fail, complete)
			local outerMaid = Maid.new()

			outerMaid:GiveTask(source:Subscribe(
				function(...)
					outerMaid._unique = nil
					local maid = Maid.new()
					outerMaid._unique = maid
					fire(maid, ...)
				end,
				function(...)
					fail(...)
					outerMaid:DoCleaning()
				end,
				function()
					complete()
					outerMaid:DoCleaning()
				end))

			return outerMaid
		end)
	end
end


return RxMaidUtils