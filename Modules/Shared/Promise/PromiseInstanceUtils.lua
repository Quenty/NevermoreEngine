---
-- @module PromiseInstanceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local Maid = require("Maid")

local PromiseInstanceUtils = {}

function PromiseInstanceUtils.promiseRemoved(instance)
	assert(instance:IsDescendantOf(game))

	local maid = Maid.new()

	local promise = Promise.new()

	maid:GiveTask(instance.AncestryChanged:Connect(function(child, parent)
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