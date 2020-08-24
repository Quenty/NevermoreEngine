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
	stripes, backgroundTransparency, stripeTransparency, percentStripeThickness, percentOffset)

	percentOffset = percentOffset or 0
	percentStripeThickness = math.clamp(percentStripeThickness or 0.5, 0, 1)

	if percentStripeThickness <= EPSILON then
		return NumberSequence.new(backgroundTransparency)
	elseif percentStripeThickness >= 1 - EPSILON then
		return NumberSequence.new(stripeTransparency)
	end

	local timeWidth = 1/stripes
	local timeOffset = percentOffset*timeWidth
	timeOffset = timeOffset + percentStripeThickness*timeWidth*0.5 -- We add thickness to center
	timeOffset = timeOffset % timeWidth

	-- Generate initialial points
	local waypoints = {}
	for i=0, stripes-1 do
		local timestampStart = (i/stripes + timeOffset) % 1
		local timeStampMiddle = (timestampStart + timeWidth*(1 - percentStripeThickness)) % 1

		table.insert(waypoints, NumberSequenceKeypoint.new(timestampStart, backgroundTransparency))
		table.insert(waypoints, NumberSequenceKeypoint.new(timeStampMiddle, stripeTransparency))
	end

	table.sort(waypoints, function(a, b)
		return a.Time < b.Time
	end)

	local fullWaypoints = {}

	-- Handle first!
	table.insert(fullWaypoints, waypoints[1])

	for i=2, #waypoints do
		local previous = waypoints[i-1]
		local current = waypoints[i]

		if current.Time - EPSILON > previous.Time then
			table.insert(fullWaypoints, NumberSequenceKeypoint.new(current.Time - EPSILON, previous.Value))
		end

		table.insert(fullWaypoints, current)
	end

	-- Add beginning
	local first = fullWaypoints[1]
	if first.Time >= EPSILON then
		local transparency
		if first.Value == backgroundTransparency then
			transparency = stripeTransparency
		elseif first.Value == stripeTransparency then
			transparency = backgroundTransparency
		else
			error("Bad comparison")
		end

		table.insert(fullWaypoints, 1, NumberSequenceKeypoint.new(first.Time - EPSILON, transparency))
		table.insert(fullWaypoints, 1, NumberSequenceKeypoint.new(0, transparency))
	else
		-- Force single entry to actually be at 0
		table.remove(fullWaypoints, 1)
		table.insert(fullWaypoints, 1, NumberSequenceKeypoint.new(0, first.Value))
	end

	local last = fullWaypoints[#fullWaypoints]
	if last.Time <= (1 - EPSILON) then
		table.insert(fullWaypoints, NumberSequenceKeypoint.new(1, last.Value))
	else
		-- Force single entry to actually be at 1
		table.remove(fullWaypoints)
		table.insert(fullWaypoints, NumberSequenceKeypoint.new(1, last.Value))
	end

	return NumberSequence.new(fullWaypoints)
end

return NumberSequenceUtils