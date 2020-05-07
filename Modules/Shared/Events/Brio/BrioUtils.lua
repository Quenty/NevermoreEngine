---
-- @module BrioUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local Brio = require("Brio")

local BrioUtils = {}

function BrioUtils.first(brios, ...)
	for _, brio in pairs(brios) do
		if brio:IsDead() then
			return Brio.DEAD
		end
	end

	local maid = Maid.new()
	local topBrio = Brio.new(...)

	for _, brio in pairs(brios) do
		maid:GiveTask(brio.Died:Connect(function()
			topBrio:Kill()
		end))
	end

	maid:GiveTask(topBrio.Died:Connect(function()
		maid:DoCleaning()
	end))

	return topBrio
end

function BrioUtils.toMaid(brio)
	assert(not brio:IsDead())

	local maid = Maid.new()

	maid:GiveTask(brio.Died:Connect(function()
		maid:DoCleaning()
	end))

	return maid
end

-- Makes a brio that is limited by the lifetime of its parent (but could be shorter)
-- and has the new values given
function BrioUtils.extend(brio, ...)
	if brio:IsDead() then
		return Brio.DEAD
	end

	local values = brio._values
	local current = {}
	for i=1, values.n do
		current[i] = values[i]
	end
	local otherValues = table.pack(...)
	for i=1, otherValues.n do
		current[values.n+i] = otherValues[i]
	end

	local maid = Maid.new()
	local newBrio = Brio.new(unpack(current, 1, values.n + otherValues.n))

	maid:GiveTask(brio.Died:Connect(function()
		newBrio:Kill()
	end))

	maid:GiveTask(newBrio.Died:Connect(function()
		maid:DoCleaning()
	end))

	return newBrio
end

function BrioUtils.merge(brio, otherBrio)
	if brio:IsDead() or otherBrio:IsDead() then
		return Brio.DEAD
	end

	local values = brio._values
	local current = {}
	for i=1, values.n do
		current[i] = values[i]
	end

	local otherValues = otherBrio._values
	for i=1, otherValues.n do
		current[values.n+i] = otherValues[i]
	end

	local maid = Maid.new()
	local newBrio = Brio.new(unpack(current, 1, values.n + otherValues.n))

	maid:GiveTask(brio.Died:Connect(function()
		newBrio:Kill()
	end))
	maid:GiveTask(otherBrio.Died:Connect(function()
		newBrio:Kill()
	end))

	maid:GiveTask(newBrio.Died:Connect(function()
		maid:DoCleaning()
	end))

	return newBrio
end

return BrioUtils