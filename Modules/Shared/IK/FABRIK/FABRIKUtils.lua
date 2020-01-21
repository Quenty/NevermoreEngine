---
-- @module FABRIKUtils

local FABRIKUtils = {}

local CFA_90X = CFrame.Angles(math.pi/2, 0, 0)
local EPSILON = 1e-3

-- Constructs the points from attachment, relative to their rig parts groups, and ignoring any transforms.
-- Relative to the relativeCFrame
function FABRIKUtils.pointsFromAttachment(relativeCFrame, attachmentGroupsPerPart)
	local points = {}
	local offsets = {}

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

		-- HACK FOR ARMS, gets relative CFrame so we can have offsets proper
		local offset = (CFA_90X*(first.CFrame:inverse() * second.CFrame)).p
		offset = offset*Vector3.new(1, 1, 0)
		if offset.magnitude >= EPSILON then
			table.insert(offsets, offset)
		end

		lastAttachmentCFrame = second.WorldCFrame
	end

	return points, offsets
end

return FABRIKUtils