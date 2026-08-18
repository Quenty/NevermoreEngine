--!nonstrict
--[=[
	@class filterDescendants

	Live filtered descendant list. observeDescendantsBrio already seeds current
	matches + tracks add/remove; brio death pulls the instance out of the array.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local RxInstanceUtils = require("RxInstanceUtils")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(
		dis: any?,
		instanceArg: Instance | { Instance },
		filterFunction: (Instance) -> boolean
	): { Instance }
		local hookState, hookMaid = getOrCreateHookState(rt, dis)
		assert(instanceArg, "instanceArg is nil")
		assert(
			typeof(instanceArg) == "Instance" or typeof(instanceArg) == "table",
			"instanceArg must be an Instance or a table of Instances"
		)

		if not hookState.instances then
			hookState.instances = if typeof(instanceArg) == "table" then table.clone(instanceArg) else { instanceArg }
			for _, instance in hookState.instances do
				assert(instance, "instance is nil")
				assert(instance:IsA("Instance"), "instance must be an Instance")
			end
		end

		if hookState.filteredDescendants == nil then
			local list: { Instance } = {}
			hookState.filteredDescendants = list
			for _, instance in hookState.instances do
				hookMaid:GiveTask(
					RxInstanceUtils.observeDescendantsBrio(instance, filterFunction):Subscribe(function(descendantBrio)
						if descendantBrio:IsDead() then
							return
						end

						local maid, descendant = descendantBrio:ToMaidAndValue()
						table.insert(list, descendant)
						maid:GiveTask(function()
							local index = table.find(list, descendant)
							if index then
								local last = #list
								list[index] = list[last]
								list[last] = nil
							end
						end)
					end)
				)
			end
		end
		return hookState.filteredDescendants
	end
end
