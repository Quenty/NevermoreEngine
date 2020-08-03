---
-- @module ColorSequenceUtils

local ColorSequenceUtils = {}

local EPSILON = 1e-3

function ColorSequenceUtils.stripe(stripes, backgroundColor3, stripeColor3, percentStripeThickness, percentOffset)
	percentOffset = percentOffset or 0
	percentStripeThickness = math.clamp(percentStripeThickness or 0.5, 0, 1)

	if percentStripeThickness <= EPSILON then
		return ColorSequence.new(backgroundColor3)
	elseif percentStripeThickness >= 1 - EPSILON then
		return ColorSequence.new(stripeColor3)
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

		table.insert(waypoints, ColorSequenceKeypoint.new(timestampStart, backgroundColor3))
		table.insert(waypoints, ColorSequenceKeypoint.new(timeStampMiddle, stripeColor3))
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
			table.insert(fullWaypoints, ColorSequenceKeypoint.new(current.Time - EPSILON, previous.Value))
		end

		table.insert(fullWaypoints, current)
	end

	-- Add beginning
	local first = fullWaypoints[1]
	if first.Time >= EPSILON then
		local color
		if first.Value == backgroundColor3 then
			color = stripeColor3
		elseif first.Value == stripeColor3 then
			color = backgroundColor3
		else
			error("Bad comparison")
		end

		table.insert(fullWaypoints, 1, ColorSequenceKeypoint.new(first.Time - EPSILON, color))
		table.insert(fullWaypoints, 1, ColorSequenceKeypoint.new(0, color))
	else
		-- Force single entry to actually be at 0
		table.remove(fullWaypoints, 1)
		table.insert(fullWaypoints, 1, ColorSequenceKeypoint.new(0, first.Value))
	end

	local last = fullWaypoints[#fullWaypoints]
	if last.Time <= (1 - EPSILON) then
		table.insert(fullWaypoints, ColorSequenceKeypoint.new(1, last.Value))
	else
		-- Force single entry to actually be at 1
		table.remove(fullWaypoints)
		table.insert(fullWaypoints, ColorSequenceKeypoint.new(1, last.Value))
	end

	return ColorSequence.new(fullWaypoints)
end

return ColorSequenceUtils