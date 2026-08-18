--!strict
--[=[
	@class value

	Creates a ValueObject on first call, parented to the hook maid.
	Later calls return the same object; the initial value is not reapplied.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local ValueObject = require("ValueObject")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(initialValue: any, dis: any?): ValueObject.ValueObject<any>
		local hookState, hookMaid = getOrCreateHookState(rt, dis)
		if hookState.valueObject == nil then
			hookState.valueObject = hookMaid:Add(ValueObject.new(initialValue))
		end
		return hookState.valueObject
	end
end
