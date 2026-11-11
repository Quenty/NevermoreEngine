--!strict
--[=[
	Joints a mesh of wedge parts together with [BallSocketConstraint] objects so it simulates as
	fabric. Sails, flags, capes, and banners are all rigged this way.

	Wedges are jointed wherever their corners meet, so the fabric has to be built with its wedges
	lined up corner to corner. Parts that are not wedges are left alone.

	```lua
	FabricBallSocketUtils.create(sailModel)
	```

	@class FabricBallSocketUtils
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeUtils = require("AdorneeUtils")
local NoCollisionConstraintUtils = require("NoCollisionConstraintUtils")
local Vector3Utils = require("Vector3Utils")

local WEDGE_CORNER_SCALES: { Vector3 } = {
	Vector3.new(0, 0.5, 0.5),
	Vector3.new(0, -0.5, 0.5),
	Vector3.new(0, -0.5, -0.5),
}

local CORNER_GRID_PRECISION = 1

local MAX_FRICTION_TORQUE = 0.5
local UPPER_ANGLE_DEGREES = 165

type CornerAttachment = {
	part: WedgePart,
	attachment: Attachment,
}

local FabricBallSocketUtils = {}

--[=[
	Joints every wedge in the adornee to the wedges it shares corners with, and unanchors them,
	leaving the adornee free to simulate.

	@param adornee Instance
	@return { BallSocketConstraint } -- One joint per pair of touching corners
]=]
function FabricBallSocketUtils.create(adornee: Instance): { BallSocketConstraint }
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local boundingBoxCFrame = AdorneeUtils.getBoundingBox(adornee)
	if not boundingBoxCFrame then
		return {}
	end

	local wedges = {}
	for _, part in AdorneeUtils.getParts(adornee) do
		if part:IsA("WedgePart") then
			table.insert(wedges, part)
		end
	end

	local joints = {}
	local atCorner: { [string]: { CornerAttachment } } = {}
	local jointed: { [BasePart]: { [BasePart]: boolean } } = {}

	for _, wedge in wedges do
		for _, attachment in FabricBallSocketUtils._createCornerAttachments(wedge, boundingBoxCFrame) do
			local key = tostring(Vector3Utils.round(attachment.WorldPosition, CORNER_GRID_PRECISION))

			local sharing = atCorner[key]
			if sharing then
				for _, other in sharing do
					table.insert(joints, FabricBallSocketUtils._createBallSocket(attachment, other.attachment))

					if FabricBallSocketUtils._markJointed(jointed, wedge, other.part) then
						NoCollisionConstraintUtils.create(wedge, other.part, wedge)
					end
				end
			else
				sharing = {}
				atCorner[key] = sharing
			end

			table.insert(sharing, {
				part = wedge,
				attachment = attachment,
			})
		end
	end

	for _, wedge in wedges do
		wedge.Anchored = false
	end

	return joints
end

--[=[
	Creates an [Attachment] at each corner of the wedge. Every attachment is given the adornee's
	orientation rather than its own part's, so the joint limits line up across the whole fabric.

	@private
	@param part WedgePart
	@param boundingBoxCFrame CFrame
	@return { Attachment }
]=]
function FabricBallSocketUtils._createCornerAttachments(part: WedgePart, boundingBoxCFrame: CFrame): { Attachment }
	local rotation = part.CFrame:ToObjectSpace(boundingBoxCFrame).Rotation

	local attachments = {}

	for _, scale in WEDGE_CORNER_SCALES do
		local attachment = Instance.new("Attachment")
		attachment.Name = "FabricCorner" .. tostring(scale)
		attachment.CFrame = rotation + part.Size * scale
		attachment.Parent = part

		table.insert(attachments, attachment)
	end

	return attachments
end

--[=[
	@private
	@param attachment0 Attachment
	@param attachment1 Attachment
	@return BallSocketConstraint
]=]
function FabricBallSocketUtils._createBallSocket(attachment0: Attachment, attachment1: Attachment): BallSocketConstraint
	local ballSocket = Instance.new("BallSocketConstraint")
	ballSocket.Attachment0 = attachment0
	ballSocket.Attachment1 = attachment1
	ballSocket.MaxFrictionTorque = MAX_FRICTION_TORQUE
	ballSocket.LimitsEnabled = true
	ballSocket.UpperAngle = UPPER_ANGLE_DEGREES
	ballSocket.Restitution = 0
	ballSocket.Parent = attachment0.Parent

	return ballSocket
end

--[=[
	Records that the two parts are jointed together, so touching wedges only get one
	[NoCollisionConstraint] between them however many corners they share.

	@private
	@param jointed { [BasePart]: { [BasePart]: boolean } }
	@param part0 BasePart
	@param part1 BasePart
	@return boolean -- True if this is the first joint between the two parts
]=]
function FabricBallSocketUtils._markJointed(
	jointed: { [BasePart]: { [BasePart]: boolean } },
	part0: BasePart,
	part1: BasePart
): boolean
	local jointedToPart0 = jointed[part0]
	if jointedToPart0 then
		if jointedToPart0[part1] then
			return false
		end
	else
		jointedToPart0 = {}
		jointed[part0] = jointedToPart0
	end
	jointedToPart0[part1] = true

	local jointedToPart1 = jointed[part1]
	if not jointedToPart1 then
		jointedToPart1 = {}
		jointed[part1] = jointedToPart1
	end
	jointedToPart1[part0] = true

	return true
end

return FabricBallSocketUtils
