--[=[
	@class RxUIConverterUtils
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Maid = require("Maid")

local RxUIConverterUtils = {}

function RxUIConverterUtils.observeAnyChangedBelowInst(inst)
	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local function handleDescendant(descendant)
			local maid = Maid.new()

			maid:GiveTask(descendant.Changed:Connect(function()
				sub:Fire()
			end))

			maid:GiveTask(inst.Changed:Connect(function()
				sub:Fire()
			end))

			maid[descendant] = maid
		end

		topMaid:GiveTask(inst.DescendantAdded:Connect(function(descendant)
			handleDescendant(descendant)
		end))
		topMaid:GiveTask(inst.DescendantRemoving:Connect(function(descendant)
			topMaid[descendant] = nil
		end))

		handleDescendant(inst)
		for _, descendant in inst:GetDescendants() do
			handleDescendant(descendant)
		end

		return topMaid
	end)
end

return RxUIConverterUtils