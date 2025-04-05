--!strict
--[=[
	@class RxCollectionServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")

local RxCollectionServiceUtils = {}

--[=[
	Observes tagged instances

	@param tagName string
	@return Observable<Brio<Instance>>
]=]
function RxCollectionServiceUtils.observeTaggedBrio(tagName: string): Observable.Observable<Brio.Brio<Instance>>
	assert(type(tagName) == "string", "Bad tagName")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleItemAdded(inst)
			local brio = Brio.new(inst)
			maid[inst] = brio
			sub:Fire(brio)
		end

		maid:GiveTask(CollectionService:GetInstanceAddedSignal(tagName):Connect(handleItemAdded))
		maid:GiveTask(CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(inst)
			maid[inst] = nil
		end))

		for _, inst in CollectionService:GetTagged(tagName) do
			task.spawn(handleItemAdded, inst)
		end

		return maid
	end) :: any
end

--[=[
	Observes tagged instances without a brio (so just when the item is added or on-init

	@param tagName string
	@return Observable<Instance>
]=]
function RxCollectionServiceUtils.observeTagged(tagName: string): Observable.Observable<Instance>
	assert(type(tagName) == "string", "Bad tagName")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleItemAdded(inst: Instance)
			sub:Fire(inst)
		end

		maid:GiveTask(CollectionService:GetInstanceAddedSignal(tagName):Connect(handleItemAdded))

		for _, inst in CollectionService:GetTagged(tagName) do
			task.spawn(handleItemAdded, inst)
		end

		return maid
	end) :: any
end

return RxCollectionServiceUtils