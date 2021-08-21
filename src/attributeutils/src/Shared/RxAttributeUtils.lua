---
-- @module RxAttributeUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Maid = require("Maid")

local RxAttributeUtils = {}

function RxAttributeUtils.observeAttribute(instance, attributeName)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(attributeName) == "string", "Bad attributeName")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(function()
			sub:Fire(instance:GetAttribute(attributeName))
		end))
		sub:Fire(instance:GetAttribute(attributeName))

		return maid
	end)
end

return RxAttributeUtils