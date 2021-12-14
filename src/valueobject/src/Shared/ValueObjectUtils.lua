--- Utils that work with Roblox Value objects (and also ValueObject)
-- @module ValueObjectUtils

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Brio = require("Brio")
local Observable = require("Observable")
local ValueObject = require("ValueObject")

local ValueObjectUtils = {}

function ValueObjectUtils.syncValue(from, to)
	local maid = Maid.new()
	to.Value = from.Value

	maid:GiveTask(from.Changed:Connect(function()
		to.Value = from.Value
	end))

	return maid
end

function ValueObjectUtils.observeValue(valueObject)
	assert(ValueObject.isValueObject(valueObject), "Bad valueObject")

	return Observable.new(function(sub)
		if not valueObject.Destroy then
			warn("[ValueObjectUtils.observeValue] - Connecting to dead ValueObject")
			-- No firing, we're dead
			return
		end

		local maid = Maid.new()

		maid:GiveTask(valueObject.Changed:Connect(function()
			sub:Fire(valueObject.Value)
		end))

		sub:Fire(valueObject.Value)

		return maid
	end)
end

function ValueObjectUtils.observeValueBrio(valueObject)
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
	end)
end


return ValueObjectUtils