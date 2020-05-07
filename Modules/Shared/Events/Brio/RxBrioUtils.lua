---
-- @module RxBrioUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BrioUtils = require("BrioUtils")
local Observable = require("Observable")
local Brio = require("Brio")
local Rx = require("Rx")

local RxBrioUtils = {}

function RxBrioUtils.completeOnDeath(brio, observable)
	assert(brio)
	assert(observable)

	return Observable.new(function(fire, fail, complete)
		if brio:IsDead() then
			complete()
			return
		end

		local maid = BrioUtils.toMaid(brio)

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

return RxBrioUtils