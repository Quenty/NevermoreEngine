---
-- @module RxBinderUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local RxBrioUtils = require("RxBrioUtils")

local RxBinderUtils = {}

function RxBinderUtils.observeBoundChildClassBrio(binder, instance)
	assert(binder)
	assert(typeof(instance) == "Instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			Rx.flatMap(RxBrioUtils.mapBrio(function(child)
				return RxBinderUtils.observeBoundClassBrio(binder, child)
			end));
		})
end

function RxBinderUtils.observeBoundChildClassesBrio(binders, instance)
	assert(binders)
	assert(typeof(instance) == "Instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			Rx.flatMap(RxBrioUtils.mapBrio(function(child)
				return RxBinderUtils.observeBoundClassesBrio(binders, child)
			end))
		})
end


function RxBinderUtils.observeBoundClassBrio(binder, instance)
	assert(type(binder) == "table")
	assert(typeof(instance) == "Instance")

	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		local function handleClassChanged(class)
			if class then
				local brio = Brio.new(class)
				maid._lastBrio = brio

				fire(brio)
			else
				maid._lastBrio = nil
			end
		end

		maid:GiveTask(binder:ObserveInstance(instance, handleClassChanged))
		handleClassChanged(binder:Get(instance))

		return maid
	end)
end

function RxBinderUtils.observeBoundClassesBrio(binders, instance)
	assert(binders)
	assert(typeof(instance) == "Instance")

	local observables = {}

	for _, binder in pairs(binders) do
		table.insert(observables, RxBinderUtils.observeBoundClassBrio(binder, instance))
	end

	return Rx.mergeAll()(Rx.of(observables))
end

return RxBinderUtils