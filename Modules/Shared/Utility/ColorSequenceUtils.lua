---
-- @module ColorSequenceUtils

local ColorSequenceUtils = {}

local EPSILON = 1e-3

function ColorSequenceUtils.stripe(stripes, backgroundColor3, stripeColor3, percentStripeThickness, percentOffset)
	percentOffset = percentOffset or 0.5
	percentStripeThickness = math.clamp(percentStripeThickness or 0.5, 0, 1)

	if percentStripeThickness == 0 then
		return ColorSequence.new(backgroundColor3)
	elseif percentStripeThickness == 1 then
		return ColorSequence.new(stripeColor3)
	end

	local waypoints = {}

	local timeWidth = 1/stripes
	local timeOffset = (percentOffset + timeWidth*(percentStripeThickness - 0.5) % 0.5)*timeWidth

	if percentOffset >= 0.5 then
		stripeColor3, backgroundColor3 = backgroundColor3, stripeColor3
	end

	table.insert(waypoints, ColorSequenceKeypoint.new(0, backgroundColor3))

	for i=0, stripes-1 do
		local timestampStart = i/stripes + timeOffset
		local timeStampMiddle = timestampStart + timeWidth*(1 - percentStripeThickness)
		local timestampEnd = math.min(timestampStart + timeWidth, 1)

		if timeStampMiddle+EPSILON < timestampEnd-EPSILON then
			table.insert(waypoints, ColorSequenceKeypoint.new(timeStampMiddle, backgroundColor3))
			table.insert(waypoints, ColorSequenceKeypoint.new(timeStampMiddle+EPSILON, stripeColor3))

			table.insert(waypoints, ColorSequenceKeypoint.new(timestampEnd-EPSILON, stripeColor3))
			table.insert(waypoints, ColorSequenceKeypoint.new(timestampEnd, backgroundColor3))
		else
			table.insert(waypoints, ColorSequenceKeypoint.new(1, backgroundColor3))
		end
	end

	return ColorSequence.new(waypoints)
end

return ColorSequenceUtils