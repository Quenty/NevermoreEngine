---
-- @module FABRIKUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local FABRIKBone = require("FABRIKBone")

local FABRIKUtils = {}

-- Constructs the points from attachment, relative to their rig parts groups, and ignoring any transforms.
-- Relative to the relativeCFrame
function FABRIKUtils.pointsFromAttachment(relativeCFrame, attachmentGroupsPerPart)
	local points = {}

	local lastAttachmentCFrame
	for index, group in pairs(attachmentGroupsPerPart) do
		-- assume that the group are in the same part
		local first = group[1] or error("Group must have first attachment")
		local second = group[2] or error("Group must have second attachment")

		if not lastAttachmentCFrame then
			lastAttachmentCFrame = first.WorldCFrame
		end

		-- self._lowerTorso.CFrame * waist.C0 * estimated_transform * waist.C1:inverse()
		local partCFrame = lastAttachmentCFrame * first.CFrame:inverse()

		table.insert(points, relativeCFrame:pointToObjectSpace(partCFrame:pointToWorldSpace(first.Position)))

		-- Add last point
		if index == #attachmentGroupsPerPart then
			table.insert(points, relativeCFrame:pointToObjectSpace(partCFrame:pointToWorldSpace(second.Position)))
		end

		lastAttachmentCFrame = second.WorldCFrame
	end

	return points
end

return FABRIKUtils