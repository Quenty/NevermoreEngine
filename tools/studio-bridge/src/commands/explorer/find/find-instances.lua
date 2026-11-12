--!strict
--[=[
	@class FindInstancesAction
]=]

local require = require(script.Parent.loader).load(script)

local InstanceQuery = require("InstanceQuery")
local InstanceRef = require("InstanceRef")

local DEFAULT_LIMIT = 200
local YIELD_EVERY = 5000

local FindInstancesAction = {}

--[=[
	Registers the `findInstances` handler.
]=]
function FindInstancesAction.register(router: any)
	router:setResponseType("findInstances", "findInstancesResult")
	router:register(
		"findInstances",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			return FindInstancesAction._find(payload)
		end
	)
end

function FindInstancesAction._find(payload: { [string]: any }): { [string]: any }
	local prepared, failure = InstanceQuery.prepare(payload)
	if not prepared then
		return failure :: any
	end

	local limit = if type(payload.limit) == "number" then payload.limit else DEFAULT_LIMIT
	local instances, searched, total = InstanceQuery.find(prepared, limit, YIELD_EVERY)

	return {
		instances = InstanceRef.fromList(instances),
		searched = searched,
		total = total,
		truncated = total > #instances,
	}
end

return FindInstancesAction
