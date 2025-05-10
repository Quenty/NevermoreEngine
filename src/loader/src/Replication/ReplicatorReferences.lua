--!strict
--[=[
	Handles mapping of references to the new value.

	@class ReplicatorReferences
]=]

local ReplicatorReferences = {}
ReplicatorReferences.ClassName = "ReplicatorReferences"
ReplicatorReferences.__index = ReplicatorReferences

export type ListenerCallback = (Instance?) -> ()

export type ReplicatorReferences = typeof(setmetatable(
	{} :: {
		_lookup: { [Instance]: Instance },
		_listeners: { [Instance]: { ListenerCallback } },
	},
	{} :: typeof({ __index = ReplicatorReferences })
))

function ReplicatorReferences.new(): ReplicatorReferences
	local self = setmetatable({}, ReplicatorReferences)

	self._lookup = {}
	self._listeners = {} --[orig] = { callback }

	return self
end

--[=[
	Returns true if the argument is a replicator references

	@param replicatorReferences any?
	@return boolean
]=]
function ReplicatorReferences.isReplicatorReferences(replicatorReferences: any): boolean
	return type(replicatorReferences) == "table" and getmetatable(replicatorReferences :: any) == ReplicatorReferences
end

function ReplicatorReferences.SetReference(self: ReplicatorReferences, orig: Instance, replicated: Instance)
	assert(typeof(orig) == "Instance", "Bad orig")
	assert(typeof(replicated) == "Instance", "Bad replicated")

	if self._lookup[orig] ~= replicated then
		self._lookup[orig] = replicated
		self:_fireSubs(orig, replicated)
	end
end

function ReplicatorReferences.UnsetReference(self: ReplicatorReferences, orig: Instance, replicated: Instance)
	assert(typeof(orig) == "Instance", "Bad orig")
	assert(typeof(replicated) == "Instance", "Bad replicated")

	if self._lookup[orig] == replicated then
		self._lookup[orig] = nil
		self:_fireSubs(orig, nil)
	end
end

function ReplicatorReferences.GetReference(self: ReplicatorReferences, orig: Instance): Instance?
	return self._lookup[orig]
end

function ReplicatorReferences._fireSubs(self: ReplicatorReferences, orig: Instance, newValue: Instance?)
	assert(typeof(orig) == "Instance", "Bad orig")

	local listeners = self._listeners[orig]
	if not listeners then
		return
	end

	for _, callback in listeners do
		task.spawn(callback, newValue)
	end
end

--[=[
	Observes when a reference changes. Discount Rx observable since we're
	the loader and don't want a whole copy of Rx.

	@param orig Instance
	@param callback function
	@return () -> () -- Call to disconnect
]=]
function ReplicatorReferences.ObserveReferenceChanged(
	self: ReplicatorReferences,
	orig: Instance,
	callback: ListenerCallback
): () -> ()
	assert(typeof(orig) == "Instance", "Bad orig")
	assert(type(callback) == "function", "Bad callback")

	-- register
	do
		local listeners = self._listeners[orig]
		if not listeners then
			listeners = {} :: { ListenerCallback }
			self._listeners[orig] = listeners
		end

		table.insert(listeners, callback)
	end

	task.spawn(callback, self._lookup[orig])

	-- Unregister
	return function()
		local listeners = self._listeners[orig]
		if not listeners then
			return
		end

		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

return ReplicatorReferences
