--!strict
--[=[
	Utility functions involving attributes.
	@class RxAttributeUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local Symbol = require("Symbol")

local UNSET_VALUE = Symbol.named("unsetValue")

local RxAttributeUtils = {}

--[=[
	Observes an attribute on an instance.
	@param instance Instance
	@param attributeName string
	@param defaultValue any?
	@return Observable<any>
]=]
function RxAttributeUtils.observeAttribute<T>(
	instance: Instance,
	attributeName: string,
	defaultValue: T?
): Observable.Observable<T>
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(attributeName) == "string", "Bad attributeName")

	return Observable.new(function(sub)
		local function handleAttributeChanged()
			local attributeValue = instance:GetAttribute(attributeName)
			if attributeValue == nil then
				sub:Fire(defaultValue)
			else
				sub:Fire(attributeValue)
			end
		end

		local connection = instance:GetAttributeChangedSignal(attributeName):Connect(handleAttributeChanged)
		handleAttributeChanged()

		return connection
	end) :: any
end

--[=[
	Observes all the attribute keys that
	@param instance Instance
	@return Observable<Brio<string>>
]=]
function RxAttributeUtils.observeAttributeKeysBrio(instance: Instance): Observable.Observable<Brio.Brio<string>>
	assert(typeof(instance) == "Instance", "Bad instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local attributeNameToBrio: { [string]: any } = {}

		local function handleAttributeChanged(attributeName: string, attributeValue: any)
			if attributeValue == nil then
				local brio = attributeNameToBrio[attributeName]
				if brio then
					attributeNameToBrio[attributeName] = nil
					maid[brio] = nil
				end
			else
				if not attributeNameToBrio[attributeName] then
					local brio: any = Brio.new(attributeName)
					attributeNameToBrio[attributeName] = brio
					maid[brio] = brio
					sub:Fire(brio)
				end
			end
		end

		maid:GiveTask(instance.AttributeChanged:Connect(function(attributeName)
			handleAttributeChanged(attributeName, instance:GetAttribute(attributeName))
		end))

		for attributeName, attributeValue in pairs(instance:GetAttributes()) do
			if not sub:IsPending() then
				break
			end

			-- TODO: Maybe we technically need to requery here but it's expensive
			handleAttributeChanged(attributeName, attributeValue)
		end

		return maid
	end) :: any
end

--[=[
	Observes all the attribute keys for an instance

	@param instance Instance
	@return Observable<string>
]=]
function RxAttributeUtils.observeAttributeKeys(instance: Instance): Observable.Observable<string>
	assert(typeof(instance) == "Instance", "Bad instance")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(instance.AttributeChanged:Connect(function(attribute)
			sub:Fire(attribute)
		end))

		for attribute, _ in pairs(instance:GetAttributes()) do
			if not sub:IsPending() then
				break
			end

			sub:Fire(attribute)
		end

		return maid
	end) :: any
end

--[=[
	Observes an attribute on an instance with a conditional statement.
	@param instance Instance
	@param attributeName string
	@param condition function | nil
	@return Observable<Brio<any>>
]=]
function RxAttributeUtils.observeAttributeBrio<T>(
	instance: Instance,
	attributeName: string,
	condition: Rx.Predicate<T>?
): Observable.Observable<Brio.Brio<T>>
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(attributeName) == "string", "Bad attributeName")

	return Observable.new(function(sub)
		local maid = Maid.new()
		local lastValue = UNSET_VALUE

		local function handleAttributeChanged()
			local attributeValue = instance:GetAttribute(attributeName)

			-- Deferred events can cause multiple values to be queued at once
			-- but we operate at this post-deferred layer, so lets only output
			-- reflected values.
			if lastValue ~= attributeValue then
				lastValue = attributeValue

				if not condition or condition(attributeValue :: T) then
					local brio = Brio.new(attributeValue)
					maid._lastBrio = brio

					-- The above line can cause us to be overwritten so make sure before firing.
					if maid._lastBrio == brio then
						sub:Fire(brio)
					end
				else
					maid._lastBrio = nil
				end
			end
		end

		maid:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(handleAttributeChanged))
		handleAttributeChanged()

		return maid
	end) :: any
end

return RxAttributeUtils
