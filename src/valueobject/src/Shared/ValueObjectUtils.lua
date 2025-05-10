--!strict
--[=[
	Utils that work with Roblox Value objects (and also ValueObject)
	@class ValueObjectUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local ValueObject = require("ValueObject")

local ValueObjectUtils = {}

--[=[
	Syncs the value from `from` to `to`.
	@param from ValueObject<T>
	@param to ValueObject<T>
	@return MaidTask
]=]
function ValueObjectUtils.syncValue<T>(from: ValueObject.ValueObject<T>, to: ValueObject.ValueObject<T>): Maid.Maid
	local maid = Maid.new()
	to.Value = from.Value

	maid:GiveTask(from.Changed:Connect(function()
		to.Value = from.Value
	end))

	return maid
end

--[=[
	Observes the current value of the ValueObject

	@deprecated 13.18.0
	@param valueObject ValueObject<T>
	@return Observable<T>
]=]
function ValueObjectUtils.observeValue<T>(valueObject: ValueObject.ValueObject<T>): Observable.Observable<T>
	assert(ValueObject.isValueObject(valueObject), "Bad valueObject")

	return valueObject:Observe()
end

--[=[
	Observes the current value of the ValueObject
	@param valueObject ValueObject<T>
	@return Observable<Brio<T>>
]=]
function ValueObjectUtils.observeValueBrio<T>(valueObject: ValueObject.ValueObject<T>): Observable.Observable<Brio.Brio<T>>
	assert(valueObject, "Bad valueObject")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function refire()
			local brio = Brio.new(valueObject.Value)
			maid._lastBrio = brio
			sub:Fire(brio)
		end

		maid:GiveTask(valueObject.Changed:Connect(refire))

		refire()

		return maid
	end) :: any
end

return ValueObjectUtils
