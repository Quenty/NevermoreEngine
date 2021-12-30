--[=[
	Utility functions involving attributes.
	@class RxAttributeUtils
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Maid = require("Maid")

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

		local function update()
			local value = instance:GetAttribute(attributeName)
			if value == nil then
				sub:Fire(defaultValue)
			else
				sub:Fire(value)
			end
		end

		maid:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(update))
		update()

		return maid
	end)
end

return RxAttributeUtils