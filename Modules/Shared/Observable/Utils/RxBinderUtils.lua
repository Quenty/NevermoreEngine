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
local RxLinkUtils = require("RxLinkUtils")

local RxBinderUtils = {}

function RxBinderUtils.observeLinkedBoundClassBrio(linkName, parent, binder)
	assert(linkName)
	assert(parent)
	assert(binder)

	return RxLinkUtils.observeValidLinksBrio(linkName, parent)
		:Pipe({
			RxBrioUtils.flatMap(function(link, linkValue)
				return RxBinderUtils.observeBoundClassBrio(binder, linkValue)
			end);
		});
end

function RxBinderUtils.observeBoundChildClassBrio(binder, instance)
	assert(binder)
	assert(typeof(instance) == "Instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			RxBrioUtils.flatMap(function(child)
				return RxBinderUtils.observeBoundClassBrio(binder, child)
			end);
		})
end

function RxBinderUtils.observeBoundChildClassesBrio(binders, instance)
	assert(binders)
	assert(typeof(instance) == "Instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			RxBrioUtils.flatMap(function(child)
				return RxBinderUtils.observeBoundClassesBrio(binders, child)
			end);
		})
end

function RxBinderUtils.observeBoundClass(binder, instance)
	assert(type(binder) == "table")
	assert(typeof(instance) == "Instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(binder:ObserveInstance(instance, function(...)
			sub:Fire(...)
		end))
		sub:Fire(binder:Get(instance))

		return maid
	end)
end

function RxBinderUtils.observeBoundClassBrio(binder, instance)
	assert(type(binder) == "table")
	assert(typeof(instance) == "Instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleClassChanged(class)
			if class then
				local brio = Brio.new(class)
				maid._lastBrio = brio

				sub:Fire(brio)
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

	return Rx.of(unpack(observables)):Pipe({
		Rx.mergeAll();
	})
end

return RxBinderUtils