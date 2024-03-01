--[=[
	Handles mapping of references to the new value.

	@class ReplicatorReferences
]=]

local ReplicatorReferences = {}
ReplicatorReferences.ClassName = "ReplicatorReferences"
ReplicatorReferences.__index = ReplicatorReferences

function ReplicatorReferences.new()
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
function ReplicatorReferences.isReplicatorReferences(replicatorReferences)
	return type(replicatorReferences) == "table" and
		getmetatable(replicatorReferences) == ReplicatorReferences
end

function ReplicatorReferences:SetReference(orig, replicated)
	assert(typeof(orig) == "Instance", "Bad orig")
	assert(typeof(replicated) == "Instance", "Bad replicated")

	if self._lookup[orig] ~= replicated then
		self._lookup[orig] = replicated
		self:_fireSubs(orig, replicated)
	end
end

function ReplicatorReferences:UnsetReference(orig, replicated)
	assert(typeof(orig) == "Instance", "Bad orig")
	assert(typeof(replicated) == "Instance", "Bad replicated")

	if self._lookup[orig] == replicated then
		self._lookup[orig] = nil
		self:_fireSubs(orig, nil)
	end
end

function ReplicatorReferences:_fireSubs(orig, newValue)
	assert(typeof(orig) == "Instance", "Bad orig")

	local listeners = self._listeners[orig]
	if not listeners then
		return
	end

	for _, callback in pairs(listeners) do
		task.spawn(callback, newValue)
	end
end

--[=[
	Observes when a reference changes. Discount Rx observable since we're
	the loader and don't want a whole copy of Rx.

	@param orig Instance
	@param callback function
	@return function -- Call to disconnect
]=]
function ReplicatorReferences:ObserveReferenceChanged(orig, callback)
	assert(typeof(orig) == "Instance", "Bad orig")
	assert(type(callback) == "function", "Bad callback")

	-- register
	do
		local listeners = self._listeners[orig]
		if not listeners then
			listeners = {}
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