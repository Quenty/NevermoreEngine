--[=[
	Utility functions involving attributes.
	@class RxAttributeUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
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
function RxAttributeUtils.observeAttribute(instance, attributeName, defaultValue)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(attributeName) == "string", "Bad attributeName")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleAttributeChanged()
			local attributeValue = instance:GetAttribute(attributeName)
			if attributeValue == nil then
				sub:Fire(defaultValue)
			else
				sub:Fire(attributeValue)
			end
		end

		maid:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(handleAttributeChanged))
		handleAttributeChanged()

		return maid
	end)
end

--[=[
	Observes an attribute on an instance with a conditional statement.
	@param instance Instance
	@param attributeName string
	@param condition function
	@return Observable<Brio<any>>
]=]
function RxAttributeUtils.observeAttributeBrio(instance, attributeName, condition)
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

				if not condition or condition(attributeValue) then
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
	end)
end

return RxAttributeUtils