--[=[
	@class PromiseInstanceUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Maid = require("Maid")

local PromiseInstanceUtils = {}

--[=[
	@param instance Instance
	@return Promise
]=]
function PromiseInstanceUtils.promiseRemoved(instance)
	assert(instance:IsDescendantOf(game))

	local maid = Maid.new()

	local promise = Promise.new()

	maid:GiveTask(instance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			promise:Resolve()
		end
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

return PromiseInstanceUtils