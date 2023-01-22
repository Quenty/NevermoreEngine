--[=[
	Utility functions that let you score a proximity prompt (i.e. a Hint)
	based upon its relation to a character in 3D space.

	@class HintScoringUtils
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local AdorneeUtils = require("AdorneeUtils")
local BoundingBoxUtils = require("BoundingBoxUtils")
local CameraUtils = require("CameraUtils")
local Draw = require("Draw")
local Maid = require("Maid")
local Math = require("Math")
local Region3Utils = require("Region3Utils")
local Vector3Utils = require("Vector3Utils")

local MAX_PARTS_IN_REGION3 = 150
local MAX_DIST_FOR_ATTACHMENTS = 2
local DEBUG_ENABLED = false

local debugMaid
if DEBUG_ENABLED then
	debugMaid = Maid.new()

	RunService.Stepped:Connect(function()
		debugMaid:DoCleaning()
	end)
end

local HintScoringUtils = {}

--[=[
	Gets humanoid position and direction.
	@param humanoid Humanoid
	@return Vector3? -- Position
	@return Vector3? -- LookVector
]=]
function HintScoringUtils.getHumanoidPositionDirection(humanoid)
	local rootPart = humanoid.RootPart
	if not rootPart then
		return nil, nil
	end

	local rootCFrame = rootPart.CFrame
	return rootCFrame.Position, rootCFrame.lookVector
end

--[=[
	Finds adornees in a region
	@param position Vector3
	@param radius number
	@param ignoreList { Instance }
	@param getAdorneeFunction (Instance) -> Instance?
	@return { [Instance]: true }
]=]
function HintScoringUtils.getAdorneeInRegionSet(position, radius, ignoreList, getAdorneeFunction)
	assert(type(getAdorneeFunction) == "function", "Bad getAdorneeFunction")

	local region3 = Region3Utils.fromRadius(position, radius)
	local adorneesSet = {}

	for _, part in pairs(Workspace:FindPartsInRegion3WithIgnoreList(region3, ignoreList, MAX_PARTS_IN_REGION3)) do
		local adornee = getAdorneeFunction(part)
		if adornee then
			adorneesSet[adornee] = true
		end
	end

	return adorneesSet
end

if DEBUG_ENABLED then
--[=[
	Draws the score in debug mode
	@param adornee Instance
	@param score number
]=]
	function HintScoringUtils.debugScore(adornee, score)
		assert(adornee, "Bad adornee")

		debugMaid:GiveTask(Draw.text(AdorneeUtils.getCenter(adornee), ("%0.6f"):format(score)))
	end
else
	function HintScoringUtils.debugScore(_, _)
		-- nothing
	end
end

--[=[
	Raycasts to adornee

	@param raycaster Raycaster
	@param humanoidCenter Vector3
	@param adornee Instance
	@param closestBoundingBoxPoint Vector3
	@param extraDistance number
	@return Vector3 -- Hit position
]=]
function HintScoringUtils.raycastToAdornee(raycaster, humanoidCenter, adornee, closestBoundingBoxPoint, extraDistance)
	local offset = closestBoundingBoxPoint - humanoidCenter
	if offset.magnitude == 0 then
		return nil
	end

	local ray = Ray.new(humanoidCenter, offset.unit*(offset.magnitude + extraDistance))
	local hitData = raycaster:FindPartOnRay(ray)

	if DEBUG_ENABLED then
		debugMaid:GiveTask(Draw.ray(ray))
		raycaster:Ignore(Workspace.CurrentCamera)
	end

	if adornee:IsA("Attachment") then
		if hitData then
			if (hitData.Position - closestBoundingBoxPoint).magnitude > MAX_DIST_FOR_ATTACHMENTS then
				return nil
			else
				return closestBoundingBoxPoint
			end
		else
			return closestBoundingBoxPoint
		end
	end

	if not hitData then
		return nil
	end

	if not AdorneeUtils.isPartOfAdornee(adornee, hitData.Part) then
		return nil
	end

	return hitData.Position
end

--[=[
	Clamps the humanoid center to the adornee bounding box, finding the nearest point.

	:::info
	We do this because we want to raycast to the closest point on the adornee, which will
	ensure we hit it, especially for larger adornees.
	:::

	@param adornee Instance
	@param humanoidCenter Vector3
	@return Vector3? -- clamped point
	@return Vector3? -- center of bounding box
]=]
function HintScoringUtils.clampToBoundingBox(adornee, humanoidCenter)
	if adornee:IsA("Attachment") then
		return adornee.WorldPosition, adornee.WorldPosition
	end

	local cframe, size = AdorneeUtils.getBoundingBox(adornee)
	if not cframe then
		return nil, nil
	end

	return BoundingBoxUtils.clampPointToBoundingBox(cframe, size, humanoidCenter)
end

--[=[
	Scores the adornee as a target for showing as a target in terms of priority.
	@param adornee Instance
	@param raycaster Raycaster
	@param humanoidCenter Vector3
	@param humanoidLookVector Vector3
	@param maxViewRadius number
	@param maxTriggerRadius number
	@param maxViewAngle number
	@param maxTriggerAngle number
	@param isLineOfSightRequired boolean
	@return boolean | number -- [0, 1]
]=]
function HintScoringUtils.scoreAdornee(
	adornee,
	raycaster,
	humanoidCenter,
	humanoidLookVector,
	maxViewRadius,
	maxTriggerRadius,
	maxViewAngle,
	maxTriggerAngle,
	isLineOfSightRequired)
	assert(maxTriggerAngle, "Bad maxTriggerAngle")

	-- local center = AdorneeUtils.getCenter(adornee)
	-- if not center then
	-- 	return false
	-- end

	local boundingBoxPoint, center = HintScoringUtils.clampToBoundingBox(adornee, humanoidCenter)
	if not boundingBoxPoint then
		return false
	end

	local isOnScreen = CameraUtils.isOnScreen(Workspace.CurrentCamera, boundingBoxPoint)
	if not isOnScreen then
		return false
	end

	local extraDistance = 10

	local closestPoint = HintScoringUtils.raycastToAdornee(
		raycaster, humanoidCenter, adornee, boundingBoxPoint, extraDistance)

	-- Round objects be sad
	if not closestPoint then
		closestPoint = HintScoringUtils.raycastToAdornee(
			raycaster, humanoidCenter, adornee, center, 4)
	end

	if not closestPoint then
		if isLineOfSightRequired then
			return false
		else
			-- just pretend like we're here, and all good
			closestPoint = boundingBoxPoint
		end
	end

	-- if (boundingBoxPoint - humanoidCenter).magnitude <= (closestPoint - humanoidCenter).magnitude then
	-- 	closestPoint = (closestPoint + boundingBoxPoint)/2 -- Weight this!
	-- end

	closestPoint = (boundingBoxPoint + center + closestPoint)/3

	if DEBUG_ENABLED then
		debugMaid:GiveTask(Draw.point(closestPoint))
	end

	local humanoidOffset = closestPoint - humanoidCenter
	local flatHumanoidOffset = humanoidOffset * Vector3.new(1, 0, 1)
	local angleOffset = center - humanoidCenter
	local flatOffset = angleOffset * Vector3.new(1, 0, 1)
	local angle = Vector3Utils.angleBetweenVectors(flatOffset.Unit, humanoidLookVector * Vector3.new(1, 0, 1))
	if not angle then
		return false
	end

	local distScore = HintScoringUtils.scoreDist(flatHumanoidOffset.magnitude, maxViewRadius, maxTriggerRadius)
	if not distScore then
		return false
	end

	local angleScore = HintScoringUtils.scoreAngle(angle, maxViewAngle, maxTriggerAngle)
	if not angleScore then
		return false
	end

	return (distScore + angleScore)/2
end

--[=[
	Scores the distance based upon a variety of mechanics

	@param distance number
	@param maxViewDistance number
	@param maxTriggerRadius number
	@return number -- [0, 1]
]=]
function HintScoringUtils.scoreDist(distance, maxViewDistance, maxTriggerRadius)
	assert(maxViewDistance >= maxTriggerRadius, "maxViewDistance < maxTriggerRadius")

	if distance > maxViewDistance then
		return false
	end

	if distance > maxTriggerRadius then
		return -math.huge
	end

	local inverseDistProportion = Math.map(distance, 0, maxTriggerRadius, 1, 0)
	return inverseDistProportion*inverseDistProportion
end

--[=[
	Scores the angle based upon parameters

	@param angle number
	@param maxViewAngle number
	@param maxTriggerAngle number
	@return number -- [0, 1]
]=]
function HintScoringUtils.scoreAngle(angle, maxViewAngle, maxTriggerAngle)
	assert(maxViewAngle >= maxTriggerAngle, "maxViewDistance < maxTriggerRadius")

	if angle > maxViewAngle then
		return false
	end
	if angle > maxTriggerAngle then
		return -math.huge
	end

	return Math.map(angle, 0, maxTriggerAngle, 1, 0)
end

return HintScoringUtils