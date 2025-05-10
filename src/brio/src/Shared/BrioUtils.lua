--!strict
--[=[
	Utility functions affecting Brios.
	@class BrioUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Table = require("Table")

local BrioUtils = {}

--[=[
	Clones a brio, such that it may be killed without affecting the original
	brio.

	@param brio Brio<T>
	@return Brio<T>
]=]
function BrioUtils.clone<T...>(brio: Brio.Brio<T...>): Brio.Brio<T...>
	assert(brio, "Bad brio")

	if brio:IsDead() then
		return Brio.DEAD :: any
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
function BrioUtils.aliveOnly<T...>(brios: { Brio.Brio<T...> }): { Brio.Brio<T...> }
	local alive: { Brio.Brio<T...> } = {}
	for _, brio: any in brios do
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
function BrioUtils.firstAlive<T...>(brios: { Brio.Brio<T...> }): Brio.Brio<T...>?
	for _, brio: any in brios do
		if not brio:IsDead() then
			return brio
		end
	end
	return nil
end

--[=[
	Given a list of brios of brios, flattens that list into a brio with
	just one T value.

	@param brioTable { any: Brio<T> | T }
	@return Brio<{T}>
]=]
function BrioUtils.flatten<K, T>(brioTable: Table.Map<K, Brio.Brio<T> | T>): Brio.Brio<Table.Map<K, T>>
	local newValue = {}
	local brios = {}

	for key, brio: any in brioTable do
		if Brio.isBrio(brio) then
			if brio:IsDead() then
				return Brio.DEAD :: any
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
	@param ... U...
	@return Brio<U>
]=]
function BrioUtils.first<T..., U...>(brios: { Brio.Brio<T...> }, ...: U...): Brio.Brio<U...>
	for _, brio: any in brios do
		if Brio.isBrio(brio) then
			if brio:IsDead() then
				return Brio.DEAD :: any
			end
		end
	end

	local maid = Maid.new()
	local topBrio = Brio.new(...)

	for _, brio: any in brios do
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
function BrioUtils.withOtherValues<T..., U...>(brio: Brio.Brio<T...>, ...: U...): Brio.Brio<U...>
	assert(brio, "Bad brio")

	if brio:IsDead() then
		return Brio.DEAD :: any
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
	for i = 1, values.n do
		current[i] = values[i]
	end
	local otherValues = table.pack(...)
	for i = 1, otherValues.n do
		current[values.n + i] = otherValues[i]
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
	for i = 1, otherValues.n do
		current[i] = otherValues[i]
	end
	for i = 1, values.n do
		current[otherValues.n + i] = values[i]
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
function BrioUtils.merge<T, U>(brio: Brio.Brio<T>, otherBrio: Brio.Brio<U>): Brio.Brio<T & U>
	assert(Brio.isBrio(brio), "Not a brio")
	assert(Brio.isBrio(otherBrio), "Not a brio")

	if brio:IsDead() or otherBrio:IsDead() then
		return Brio.DEAD :: any
	end

	local values = brio:GetPackedValues()
	local current = {}
	for i = 1, values.n do
		current[i] = values[i]
	end

	local otherValues = otherBrio:GetPackedValues()
	for i = 1, otherValues.n do
		current[values.n + i] = otherValues[i]
	end

	local maid = Maid.new()
	local newBrio: Brio.Brio<T & U> = Brio.new(unpack(current, 1, values.n + otherValues.n)) :: any

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
