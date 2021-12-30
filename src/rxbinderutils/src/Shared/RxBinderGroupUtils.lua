--[=[
	Rx utility methods involving [BinderGroup] API surface
	@class RxBinderGroupUtils
]=]

local require = require(script.Parent.loader).load(script)

local RxBinderUtils = require("RxBinderUtils")
local Observable = require("Observable")
local Maid = require("Maid")
local Rx = require("Rx")

local RxBinderGroupUtils = {}

--[=[
	Observes all binders in a binder group
	@param binderGroup BinderGroup<T>
	@return Observable<Binder<T>>
]=]
function RxBinderGroupUtils.observeBinders(binderGroup)
	assert(type(binderGroup) == "table", "Bad binderGroup")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(binderGroup.BinderAdded:Connect(function(binder)
			sub:Fire(binder)
		end))

		for _, binder in pairs(binderGroup:GetBinders()) do
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

	return RxBinderGroupUtils.observeBinders(binderGroup)
		:Pipe({
			Rx.flatMap(RxBinderUtils.observeAllBrio)
		})
end

return RxBinderGroupUtils