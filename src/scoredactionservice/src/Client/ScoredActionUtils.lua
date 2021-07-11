---
-- @module ScoredActionUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local ScoredActionUtils = {}

function ScoredActionUtils.connectToPreferred(scoredAction, callback)
	local topMaid = Maid.new()

	local function onPreferredChanged()
		if scoredAction:IsPreferred() then
			local maid = Maid.new()
			topMaid._preferredMaid = maid
			callback(maid)
		else
			topMaid._preferredMaid = nil
		end
	end

	topMaid:GiveTask(scoredAction.PreferredChanged:Connect(onPreferredChanged))

	onPreferredChanged()

	return topMaid
end

return ScoredActionUtils