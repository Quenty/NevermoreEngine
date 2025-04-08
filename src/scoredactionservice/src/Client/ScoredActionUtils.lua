--!strict
--[=[
	@class ScoredActionUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local ScoredActionUtils = {}

function ScoredActionUtils.connectToPreferred(scoredAction, callback: (Maid.Maid) -> ()): Maid.Maid
	local topMaid = Maid.new()

	local function onPreferredChanged()
		if scoredAction:IsPreferred() then
			local maid = Maid.new()
			topMaid._preferredMaid = maid
			callback(maid)

			if topMaid._preferredMaid ~= maid then
				warn("[ScoredActionUtils.connectToPreferred] - Already cleaned up while executing callback")
				maid:DoCleaning()
			end
		else
			topMaid._preferredMaid = nil
		end
	end

	topMaid:GiveTask(scoredAction.PreferredChanged:Connect(onPreferredChanged))

	onPreferredChanged()

	return topMaid
end

return ScoredActionUtils