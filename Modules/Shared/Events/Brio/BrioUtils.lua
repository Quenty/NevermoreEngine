---
-- @module BrioUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local Brio = require("Brio")

local BrioUtils = {}

function BrioUtils.clone(brio)
	assert(brio)

	if brio:IsDead() then
		return Brio.DEAD
	end

	local newBrio = Brio.new(brio:GetValue())

	newBrio:ToMaid():GiveTask(brio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))

	return newBrio
end

function BrioUtils.aliveOnly(brios)
	local alive = {}
	for _, brio in pairs(brios) do
		if not brio:IsDead() then
			table.insert(alive, brio)
		end
	end
	return alive
end

function BrioUtils.firstAlive(brios)
	for _, brio in pairs(brios) do
		if not brio:IsDead() then
			return brio
		end
	end
	return nil
end

function BrioUtils.flatten(brioTable)
	local newValue = {}
	local brios = {}

	for key, brio in pairs(brioTable) do
		if Brio.isBrio(brio) then
			if brio:IsDead() then
				return Brio.DEAD
			else
				table.insert(brios, brio)
				newValue[key] = brio:GetValue()
			end
		else
			newValue[key] = brio
		end
	end

	return BrioUtils.first(brios, newValue)
end

function BrioUtils.first(brios, ...)
	for _, brio in pairs(brios) do
		if brio:IsDead() then
			return Brio.DEAD
		end
	end

	local maid = Maid.new()
	local topBrio = Brio.new(...)

	for _, brio in pairs(brios) do
		maid:GiveTask(brio:GetDiedSignal():Connect(function()
			topBrio:Kill()
		end))
	end

	maid:GiveTask(topBrio:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return topBrio
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

	maid:GiveTask(brio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))

	maid:GiveTask(newBrio:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return newBrio
end

function BrioUtils.merge(brio, otherBrio)
	assert(Brio.isBrio(brio), "Not a brio")
	assert(Brio.isBrio(otherBrio), "Not a brio")

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

	maid:GiveTask(brio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))
	maid:GiveTask(otherBrio:GetDiedSignal():Connect(function()
		newBrio:Kill()
	end))

	maid:GiveTask(newBrio:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return newBrio
end

return BrioUtils