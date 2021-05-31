-- Library that is capable of converting real world to Roblox units and visa versa.
-- @module UnitUtils

local UnitUtils = {}
-- ROBLOX equivalent of 9.81 m/s^2 as derived from the 'Realistic' setting in 'World Settings'
UnitUtils.NORMAL_GRAVITY = 35
-- Source: https://devforum.roblox.com/t/studs-to-metre-conversion/555264/2
UnitUtils.STUDS_IN_METER = 1 / 0.28

function UnitUtils._getRealMeter()
	-- Make the module work for every workspace.Gravity
	-- Always take the latest workspace.Gravity
	local gravityScale = workspace.Gravity / UnitUtils.NORMAL_GRAVITY

	return UnitUtils.STUDS_IN_METER * gravityScale
end

function UnitUtils.convertKiloGram(value, unitExponent)
	-- Roblox water has a density of 1, indicating that it is based of the density 1000 kg/m^3
	-- , so therefore divide by 1000
	local realKiloGram = UnitUtils._getRealMeter() ^ 3 / 1000

	return value * realKiloGram ^ unitExponent
end

function UnitUtils.convertMeter(value, unitExponent)
	return value * UnitUtils._getRealMeter() ^ unitExponent
end

-- A density of 997 kg/m^3 can be converted like 'UnitUtils.convertMeterAndKiloGram(997, -3, 1)'
function UnitUtils.convertMeterAndKiloGram(value, meterUnitExponent, kiloGramUnitExponent)
	return UnitUtils.convertKiloGram(UnitUtils.convertMeter(value, meterUnitExponent), kiloGramUnitExponent)
end

return UnitUtils
