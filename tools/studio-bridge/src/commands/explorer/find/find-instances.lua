--!strict
--[=[
	Action that searches the DataModel for instances by name, class and tag,
	answering with the first `limit` matches. Matching is the
	`instance-selection` library's, shared with `sampleInstances`.

	Request: `{ type: "findInstances", payload: { root?, names?, name?, exactName?, className?, tag?, limit? } }`
	Response: `{ type: "findInstancesResult", payload: { instances, searched, truncated } }`

	@class FindInstancesAction
]=]

local DEFAULT_LIMIT = 200
local YIELD_EVERY = 5000

local FindInstancesAction = {}

type FoundInstance = {
	path: string,
	name: string,
	className: string,
}

-- Filled in by the libraries, which may be pushed after this action
local libraries: { [string]: any } = {}

--[=[
	Registers the `findInstances` handler.
]=]
function FindInstancesAction.register(router: any)
	router._libraries = router._libraries or {}
	libraries = router._libraries

	router:setResponseType("findInstances", "findInstancesResult")
	router:register(
		"findInstances",
		function(payload: { [string]: any }, _requestId: string, _sessionId: string): { [string]: any }?
			return FindInstancesAction._find(payload)
		end
	)
end

function FindInstancesAction._find(payload: { [string]: any }): { [string]: any }
	local InstanceSelection = libraries["instance-selection"]
	if not InstanceSelection then
		return {
			success = false,
			code = "INTERNAL_ERROR",
			message = "The instance-selection library is not installed",
		}
	end

	local root, rootError = InstanceSelection.resolveRoot(payload.root)
	if not root then
		return {
			success = false,
			code = "INSTANCE_NOT_FOUND",
			message = rootError,
		}
	end

	local limit = if type(payload.limit) == "number" then payload.limit else DEFAULT_LIMIT
	local matches = InstanceSelection.createMatcher(payload)
	local instances, searched, truncated = InstanceSelection.find(root, matches, limit, YIELD_EVERY)

	local found: { FoundInstance } = {}
	for _, instance in instances do
		table.insert(found, {
			path = instance:GetFullName(),
			name = instance.Name,
			className = instance.ClassName,
		})
	end

	return {
		instances = found,
		searched = searched,
		truncated = truncated,
	}
end

return FindInstancesAction
