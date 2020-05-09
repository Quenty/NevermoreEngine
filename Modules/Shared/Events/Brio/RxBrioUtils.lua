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