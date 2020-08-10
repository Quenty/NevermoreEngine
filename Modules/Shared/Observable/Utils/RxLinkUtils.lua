---
-- @module RxLinkUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local RxBrioUtils = require("RxBrioUtils")

local RxLinkUtils = {}

-- Emits valid links in format Brio.new(link, linkValue)
function RxLinkUtils.observeValidLinksBrio(linkName, parent)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(parent) == "Instance", "Bad parent")

	return RxInstanceUtils.observeChildrenBrio(parent)
		:Pipe({
			Rx.flatMap(function(brio)
				local instance = brio:GetValue()
				if not instance:IsA("ObjectValue") then
					return Rx.EMPTY
				end

				return RxBrioUtils.completeOnDeath(brio, RxLinkUtils.observeValidityBrio(linkName, instance))
			end);
		})
end

-- Fires off everytime the link is reconfigured into a valid link
-- Fires with link, linkValue
function RxLinkUtils.observeValidityBrio(linkName, link)
	assert(typeof(link) == "Instance" and link:IsA("ObjectValue"))
	assert(type(linkName) == "string")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function updateValidity()
			if not ((link.Name == linkName) and link.Value) then
				maid._lastValid = nil
				return
			end

			local newValid = Brio.new(link, link.Value)
			maid._lastValid = newValid
			sub:Fire(newValid)
		end

		maid:GiveTask(link:GetPropertyChangedSignal("Value")
			:Connect(updateValidity))
		maid:GiveTask(link:GetPropertyChangedSignal("Name")
			:Connect(updateValidity))
		updateValidity()

		return maid
	end)
end


return RxLinkUtils