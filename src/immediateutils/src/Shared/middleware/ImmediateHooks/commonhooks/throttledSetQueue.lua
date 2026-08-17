--!nonstrict
--[=[
	@class throttledSetQueue

	Spreads work across ticks. Pass a jecs query or an array every call; each
	identity sits in the queue at most once, and only `maxCount` are emitted
	this tick (default 1). Emitted identities go to the back so a query that
	matches the same entities every tick still round-robins.

	```lua
	for entity in hooks.throttledSetQueue(world:query(C), 8) do
		-- expensive work
	end
	```
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Jecst = require("Jecst")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

type ThrottledSetQueueInput = { any } | Jecst.Query<any> | Jecst.Cached_Query<any>

local function forEachIdentity(input: ThrottledSetQueueInput?, onIdentity: (any) -> ())
	if typeof(input) ~= "table" then
		return
	end

	local mt = getmetatable(input :: any)
	if typeof(mt) == "table" and mt.__iter ~= nil then
		for identity in input :: Jecst.Query<any> do
			if identity ~= nil then
				onIdentity(identity)
			end
		end
		return
	end

	for _, identity in input :: { any } do
		if identity ~= nil then
			onIdentity(identity)
		end
	end
end

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(input: ThrottledSetQueueInput, maxCount: number?, dis: any?): () -> any?
		if maxCount ~= nil and typeof(maxCount) ~= "number" then
			dis = maxCount
			maxCount = nil
		end
		local hookState, hookMaid = getOrCreateHookState(rt, dis)

		if hookState.queue == nil then
			hookState.queue = {}
			hookState.inQueue = {}
			hookMaid:GiveTask(function()
				table.clear(hookState)
			end)
		end

		local seen = {}
		forEachIdentity(input, function(identity)
			seen[identity] = true
			if not hookState.inQueue[identity] then
				hookState.inQueue[identity] = true
				table.insert(hookState.queue, identity)
			end
		end)

		local kept = {}
		for _, identity in hookState.queue do
			if seen[identity] then
				table.insert(kept, identity)
			else
				hookState.inQueue[identity] = nil
			end
		end
		hookState.queue = kept

		local budget = if maxCount ~= nil then maxCount else 1
		local emitted = {}
		while budget > 0 and #hookState.queue > 0 do
			local identity = table.remove(hookState.queue, 1)
			hookState.inQueue[identity] = nil
			table.insert(emitted, identity)
			budget -= 1
		end

		for _, identity in emitted do
			if seen[identity] and not hookState.inQueue[identity] then
				hookState.inQueue[identity] = true
				table.insert(hookState.queue, identity)
			end
		end

		local index = 0
		return function()
			index += 1
			return emitted[index]
		end
	end
end
