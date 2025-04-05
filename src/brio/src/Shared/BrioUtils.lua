--[=[
	Utility functions affecting Brios.
	@class BrioUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Brio = require("Brio")

local BrioUtils = {}

--[=[
	Clones a brio, such that it may be killed without affecting the original
	brio.

	@param brio Brio<T>
	@return Brio<T>
]=]
function BrioUtils.clone(brio)
	assert(brio, "Bad brio")

	if brio:IsDead() then
		return Brio.DEAD
	end

	local newBrio = Brio.new(brio:GetValue())

	local connection
	local otherConnection
	connection = brio:GetDiedSignal():Connect(function()
		connection:Disconnect()
		otherConnection:Disconnect()
		newBrio:Kill()
	end)

	otherConnection = newBrio:GetDiedSignal():Connect(function()
		otherConnection:Disconnect()
		connection:Disconnect()
	end)

	return newBrio
end

--[=[
	Returns a list of alive Brios only

	@param brios {Brio<T>}
	@return {Brio<T>}
]=]
function BrioUtils.aliveOnly(brios)
	local alive = {}
	for _, brio in brios do
		if not brio:IsDead() then
			table.insert(alive, brio)
		end
	end
	return alive
end

--[=[
	Returns the first alive Brio in a list

	@param brios {Brio<T>}
	@return Brio<T>
]=]
function BrioUtils.firstAlive(brios)
	for _, brio in brios do
		if not brio:IsDead() then
			return brio
		end
	end
	return nil
end

--[=[
	Given a list of brios of brios, flattens that list into a brio with
	just one T value.

	@param brioTable { any: Brio<Brio<T> | T>}
	@return Brio<{T}>
]=]
function BrioUtils.flatten(brioTable)
	local newValue = {}
	local brios = {}

	for key, brio in brioTable do
		if Brio.isBrio(brio) then
			if brio:IsDead() then
				return Brio.DEAD
			else
				table.insert(brios, brio)
				newValue[key] = brio:GetValue()
			end
		else
			newValue[key] = brio
		end
	end

	return BrioUtils.first(brios, newValue)
end

--[=[
	Returns a brio that dies whenever the first Brio in the list
	dies. The value of the Brio is the `...` value.

	@param brios {Brio<T>}
	@param ... U
	@return Brio<U>
]=]
function BrioUtils.first(brios, ...)
	for _, brio in brios do
		if Brio.isBrio(brio) then
			if brio:IsDead() then
				return Brio.DEAD
			end
		end
	end

	local maid = Maid.new()
	local topBrio = Brio.new(...)

	for _, brio in brios do
		if Brio.isBrio(brio) then
			maid:GiveTask(brio:GetDiedSignal():Connect(function()
				topBrio:Kill()
			end))
		end
	end

	maid:GiveTask(topBrio:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return topBrio
end

--[=[
	Clones a brio, such that it may be killed without affecting the original
	brio.

	@since 3.6.0
	@param brio Brio<T>
	@param ... U
	@return Brio<U>
]=]
function BrioUtils.withOtherValues(brio, ...)
	assert(brio, "Bad brio")

	if brio:IsDead() then
		return Brio.DEAD
	end

	local newBrio = Brio.new(...)

	newBrio:ToMaid():GiveTask(brio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))

	return newBrio
end

--[=[
	Makes a brio that is limited by the lifetime of its parent (but could be shorter)
	and has the new values given.

	@param brio Brio<U>
	@param ... T
	@return Brio<T>
]=]
function BrioUtils.extend(brio, ...)
	if brio:IsDead() then
		return Brio.DEAD
	end

	local values = brio:GetPackedValues()
	local current = {}
	for i=1, values.n do
		current[i] = values[i]
	end
	local otherValues = table.pack(...)
	for i=1, otherValues.n do
		current[values.n+i] = otherValues[i]
	end

	local maid = Maid.new()
	local newBrio = Brio.new(unpack(current, 1, values.n + otherValues.n))

	maid:GiveTask(brio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))

	maid:GiveTask(newBrio:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return newBrio
end

--[=[
	Makes a brio that is limited by the lifetime of its parent (but could be shorter)
	and has the new values given at the beginning of the result

	@since 3.6.0
	@param brio Brio<U>
	@param ... T
	@return Brio<T>
]=]
function BrioUtils.prepend(brio, ...)
	if brio:IsDead() then
		return Brio.DEAD
	end

	local values = brio:GetPackedValues()
	local current = {}
	local otherValues = table.pack(...)
	for i=1, otherValues.n do
		current[i] = otherValues[i]
	end
	for i=1, values.n do
		current[otherValues.n+i] = values[i]
	end

	local maid = Maid.new()
	local newBrio = Brio.new(unpack(current, 1, values.n + otherValues.n))

	maid:GiveTask(brio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))

	maid:GiveTask(newBrio:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return newBrio
end

--[=[
	Merges the existing brio value with the other brio

	@param brio Brio<{T}>
	@param otherBrio Brio<{U}>
	@return Brio<{T | U}>
]=]
function BrioUtils.merge(brio, otherBrio)
	assert(Brio.isBrio(brio), "Not a brio")
	assert(Brio.isBrio(otherBrio), "Not a brio")

	if brio:IsDead() or otherBrio:IsDead() then
		return Brio.DEAD
	end

	local values = brio:GetPackedValues()
	local current = {}
	for i=1, values.n do
		current[i] = values[i]
	end

	local otherValues = otherBrio:GetPackedValues()
	for i=1, otherValues.n do
		current[values.n+i] = otherValues[i]
	end

	local maid = Maid.new()
	local newBrio = Brio.new(unpack(current, 1, values.n + otherValues.n))

	maid:GiveTask(brio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))
	maid:GiveTask(otherBrio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))

	maid:GiveTask(newBrio:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return newBrio
end

return BrioUtils