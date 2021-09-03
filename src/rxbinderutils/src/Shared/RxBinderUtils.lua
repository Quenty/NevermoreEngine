---
-- @module RxBinderUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxLinkUtils = require("RxLinkUtils")

local RxBinderUtils = {}

function RxBinderUtils.observeLinkedBoundClassBrio(linkName, parent, binder)
	assert(linkName, "Bad linkName")
	assert(parent, "Bad parent")
	assert(binder, "Bad binder")

	return RxLinkUtils.observeValidLinksBrio(linkName, parent)
		:Pipe({
			RxBrioUtils.flatMap(function(_, linkValue)
				return RxBinderUtils.observeBoundClassBrio(binder, linkValue)
			end);
		});
end

function RxBinderUtils.observeBoundChildClassBrio(binder, instance)
	assert(binder, "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			RxBrioUtils.flatMap(function(child)
				return RxBinderUtils.observeBoundClassBrio(binder, child)
			end);
		})
end

function RxBinderUtils.observeBoundChildClassesBrio(binders, instance)
	assert(binders, "Bad binders")
	assert(typeof(instance) == "Instance", "Bad instance")

	return RxInstanceUtils.observeChildrenBrio(instance)
		:Pipe({
			RxBrioUtils.flatMap(function(child)
				return RxBinderUtils.observeBoundClassesBrio(binders, child)
			end);
		})
end

function RxBinderUtils.observeBoundClass(binder, instance)
	assert(type(binder) == "table", "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")

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
	assert(type(binder) == "table", "Bad binder")
	assert(typeof(instance) == "Instance", "Bad instance")

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
	assert(binders, "Bad binders")
	assert(typeof(instance) == "Instance", "Bad instance")

	local observables = {}

	for _, binder in pairs(binders) do
		table.insert(observables, RxBinderUtils.observeBoundClassBrio(binder, instance))
	end

	return Rx.of(unpack(observables)):Pipe({
		Rx.mergeAll();
	})
end


function RxBinderUtils.observeAllBrio(binder)
	assert(type(binder) == "table", "Bad binder")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleNewClass(class)
			local brio = Brio.new(class)
			maid[class] = brio

			sub:Fire(brio)
		end

		maid:GiveTask(binder:GetClassAddedSignal():Connect(handleNewClass))
		maid:GiveTask(binder:GetClassRemovingSignal():Connect(function(class)
			maid[class] = nil
		end))

		for class, _ in pairs(binder:GetAllSet()) do
			handleNewClass(class)
		end

		return maid
	end)
end

return RxBinderUtils