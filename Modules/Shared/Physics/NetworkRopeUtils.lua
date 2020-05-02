---
-- @module NetworkRopeUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CollectionService = game:GetService("CollectionService")

local Maid = require("Maid")

local NETWORK_OWNER_ROPE_TAG = "NetworkRopeUtilCreatedObject"

local NetworkRopeUtils = {}

function NetworkRopeUtils.hintSharedMechanism(part0, part1)
	assert(typeof(part0) == "Instance")
	assert(typeof(part1) == "Instance")

	local maid = Maid.new()

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "NetworkOwnerHintAttachment0"
	attachment0.Parent = part0
	CollectionService:AddTag(attachment0, NETWORK_OWNER_ROPE_TAG)
	maid:GiveTask(attachment0)

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "NetworkOwnerHintAttachment1"
	attachment1.Parent = part1
	CollectionService:AddTag(attachment1, NETWORK_OWNER_ROPE_TAG)
	maid:GiveTask(attachment1)

	local ropeConstraint = Instance.new("RopeConstraint")
	ropeConstraint.Name = "NetworkOwnerHint"
	ropeConstraint.Restitution = 0
	ropeConstraint.Thickness = 0.25
	ropeConstraint.Visible = false
	ropeConstraint.Enabled = true
	ropeConstraint.Length = 100000
	ropeConstraint.Attachment0 = attachment0
	ropeConstraint.Attachment1 = attachment1
	ropeConstraint.Parent = part0
	CollectionService:AddTag(ropeConstraint, NETWORK_OWNER_ROPE_TAG)
	maid:GiveTask(ropeConstraint)

	return maid
end

function NetworkRopeUtils.clearNetworkOwnerHints(part)
	-- Preemptively clears the ownership of a part so we don't transfer ownership
	-- accidently

	for _, item in pairs(part:GetChildren()) do
		if CollectionService:HasTag(item, NETWORK_OWNER_ROPE_TAG) then
			item:Destroy()
		end
	end
end

return NetworkRopeUtils