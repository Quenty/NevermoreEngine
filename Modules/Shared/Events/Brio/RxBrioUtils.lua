---
-- @module RxBrioUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Observable = require("Observable")
local Brio = require("Brio")
local Rx = require("Rx")
local Maid = require("Maid")
local BrioUtils = require("BrioUtils")

local RxBrioUtils = {}

function RxBrioUtils.completeOnDeath(brio, observable)
	assert(Brio.isBrio(brio))
	assert(Observable.isObservable(observable))

	return Observable.new(function(fire, fail, complete)
		if brio:IsDead() then
			complete()
			return
		end

		local maid = brio:ToMaid()

		maid:GiveTask(complete)
		maid:GiveTask(observable:Subscribe(fire, fail, complete))

		return maid
	end)
end

-- This can't be cheap. Consider deeply if you want this or not.
function RxBrioUtils.reduceToAliveList(selectFromBrio)
	assert(type(selectFromBrio) == "function")

	return function(source)
		return Observable.new(function(fire, fail, complete)
			local topMaid = Maid.new()

			local subscribed = true
			topMaid:GiveTask(function()
				subscribed = false
			end)
			local aliveBrios = {}

			local function updateBrios()
				if not subscribed then -- No work if we don't need to.
					return
				end

				aliveBrios = BrioUtils.aliveOnly(aliveBrios)
				local values = {}
				if selectFromBrio then
					for _, brio in pairs(aliveBrios) do
						-- Hope for no side effects
						table.insert(values, assert(selectFromBrio(brio:GetValue())))
					end
				end

				local newBrio = BrioUtils.first(aliveBrios, values)
				topMaid._lastBrio = newBrio

				fire(newBrio)
			end

			local function handleNewBrio(brio)
				-- Could happen due to throttle or delay...
				if brio:IsDead() then
					return
				end

				local maid = Maid.new()
				topMaid[maid] = maid -- Use maid as key so it's unique (reemitted brio)

				maid:GiveTask(function() -- GC properly
					topMaid[maid] = nil
					updateBrios()
				end)
				maid:GiveTask(brio.Died:Connect(function()
					topMaid[maid] = nil
				end))

				table.insert(aliveBrios, brio)
				updateBrios()
			end

			topMaid:GiveTask(source:Subscribe(function(brio)
				if not Brio.isBrio(brio) then
					warn(("[RxBrioUtils.mergeToAliveList] - Not a brio, %q"):format(tostring(brio)))
					topMaid._lastBrio = nil
					fail("Not a brio")
					return
				end

				handleNewBrio(brio)
			end, fail, complete))

			return topMaid
		end)
	end
end

function RxBrioUtils.mapBrio(project)
	assert(type(project) == "function")

	return function(brio)
		assert(Brio.isBrio(brio), "Not a brio")

		if brio:IsDead() then
			return Rx.EMPTY
		end

		local observable = project(brio:GetValue())
		assert(Observable.isObservable(observable), "Not an observable")

		return RxBrioUtils.completeOnDeath(brio, observable)
	end
end

function RxBrioUtils.onlyLastBrioSurvives()
	return function(source)
		return Observable.new(function(fire, fail, complete)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(function(brio)
				if not Brio.isBrio(brio) then
					warn(("[RxBrioUtils.onlyLastBrioSurvives] - Not a brio, %q"):format(tostring(brio)))
					maid._lastBrio = nil
					fail("Not a brio")
					return
				end

				local wrapperBrio = BrioUtils.clone(brio)
				maid._lastBrio = wrapperBrio

				fire(wrapperBrio)
			end, fail, complete))

			return maid
		end)
	end
end

return RxBrioUtils