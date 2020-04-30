--- Utils that work with Roblox Value objects (and also ValueObject)
-- @module ValueObjectUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local ValueObjectUtils = {}

function ValueObjectUtils.syncValue(from, to)
	local maid = Maid.new()
	to.Value = from.Value

	maid:GiveTask(from.Changed:Connect(function()
		to.Value = from.Value
	end))

	return maid
end

return ValueObjectUtils