--!strict
--[=[
	Rx utility methods involving [BinderGroup] API surface
	@class RxBinderGroupUtils
]=]

local require = require(script.Parent.loader).load(script)

local BinderGroup = require("BinderGroup")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")

local RxBinderGroupUtils = {}

--[=[
	Observes all binders in a binder group
	@param binderGroup BinderGroup<T>
	@return Observable<Binder<T>>
]=]
function RxBinderGroupUtils.observeBinders(binderGroup: BinderGroup.BinderGroup)
	assert(type(binderGroup) == "table", "Bad binderGroup")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(binderGroup.BinderAdded:Connect(function(binder)
			sub:Fire(binder)
		end))

		for _, binder in binderGroup:GetBinders() do
			sub:Fire(binder)
		end

		return maid
	end)
end

--[=[
	Observes all classes in a given binder group.
	@param binderGroup BinderGroup<T>
	@return Observable<Brio<T>>
]=]
function RxBinderGroupUtils.observeAllClassesBrio(binderGroup)
	assert(type(binderGroup) == "table", "Bad binderGroup")

	return RxBinderGroupUtils.observeBinders(binderGroup):Pipe({
		Rx.flatMap(RxBinderUtils.observeAllBrio) :: any,
	}) :: any
end

return RxBinderGroupUtils
