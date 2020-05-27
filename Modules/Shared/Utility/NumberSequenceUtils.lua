---
-- @module NumberSequenceUtils

local NumberSequenceUtils = {}

local EPSILON = 1e-3

function NumberSequenceUtils.scale(sequence, scale)
	local waypoints = {}

	local keypoints = sequence.Keypoints
	for _, keypoint in pairs(keypoints) do
		table.insert(waypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value*scale, keypoint.Envelope*scale))
	end

	return NumberSequence.new(waypoints)
end

function NumberSequenceUtils.stripe(
	stripes, backgroundTransparency, strikeTransparency, percentStripeThickness, percentOffset)
	percentOffset = percentOffset or 0.5
	percentStripeThickness = math.clamp(percentStripeThickness or 0.5, 0, 1)

	if percentStripeThickness == 0 then
		return NumberSequence.new(backgroundTransparency)
	elseif percentStripeThickness == 1 then
		return NumberSequence.new(strikeTransparency)
	end

	local waypoints = {}

	local timeWidth = 1/stripes
	local timeOffset = (percentOffset + timeWidth*(percentStripeThickness - 0.5) % 0.5)*timeWidth

	if percentOffset >= 0.5 then
		strikeTransparency, backgroundTransparency = backgroundTransparency, strikeTransparency
	end

	table.insert(waypoints, NumberSequenceKeypoint.new(0, backgroundTransparency))

	for i=0, stripes-1 do
		local timestampStart = i/stripes + timeOffset
		local timeStampMiddle = timestampStart + timeWidth*(1 - percentStripeThickness)
		local timestampEnd = math.min(timestampStart + timeWidth, 1)

		if timeStampMiddle+EPSILON < timestampEnd-EPSILON then
			table.insert(waypoints, NumberSequenceKeypoint.new(timeStampMiddle, backgroundTransparency))
			table.insert(waypoints, NumberSequenceKeypoint.new(timeStampMiddle+EPSILON, strikeTransparency))

			table.insert(waypoints, NumberSequenceKeypoint.new(timestampEnd-EPSILON, strikeTransparency))
			table.insert(waypoints, NumberSequenceKeypoint.new(timestampEnd, backgroundTransparency))
		else
			table.insert(waypoints, NumberSequenceKeypoint.new(1, backgroundTransparency))
		end
	end

	return NumberSequence.new(waypoints)
end

return NumberSequenceUtils