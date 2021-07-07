--- PolynomialUtils
-- @module PolynomialUtils

local PolynomialUtils = {}

local function cubeRoot(x)
	return math.sign(x) * math.abs(x) ^ (1/3)
end

function PolynomialUtils.solveOrderedRealLinear(a, b)
	if a == 0 then -- either 0 or infinitely many solutions
		return
	end

	local z = -b/a
	if z ~= z then
		return -- return 0 solutions
	else
		return z
	end
end

function PolynomialUtils.solveOrderedRealQuadratic(a, b, c)
	if a == 0 then
		return PolynomialUtils.solveOrderedRealLinear(b, c)
	end

	local d = (b*b - 4*a*c)^0.5
	if d ~= d then -- 2 complex solutions
		return -- return 0 solutions
	else -- 2 real solutions
		local z0 = (-b - d)/(2*a)
		local z1 = (-b + d)/(2*a)
		if z0 == z1 then
			return z0, z0 -- 1 solution with multiplicity 2
		elseif z1 < z0 then
			return z1, z0
		else
			return z0, z1
		end
	end
end

-- http://www2.trinity.unimelb.edu.au/~rbroekst/MathX/Cubic%20Formula.pdf
function PolynomialUtils.solveOrderedRealCubic(a, b, c, d)
	if a == 0 then
		return PolynomialUtils.solveOrderedRealQuadratic(b, c, d)
	end

	b = b / a
	c = c / a
	d = d / a
	local p = c - b^2 / 3
	local q = (2/27*b^3 - b*c/3 + d) / 2
	local discriminant = q^2 + p^3/27
	local offset = b / 3

	if discriminant > 0 then -- return 1 real root
		local sqrtDisc = math.sqrt(discriminant)
		return cubeRoot(-q + sqrtDisc) + cubeRoot(-q - sqrtDisc) - offset
	elseif discriminant < 0 then -- return 3 real distinct roots
		local coeff = 2 * math.sqrt(-p) / math.sqrt(3)
		local theta = math.asin(math.clamp(math.sqrt(3)*3/math.sqrt(-p)^3 * q, -1, 1)) / 3
		local z0 = coeff * math.sin(theta) - offset
		local z1 = -coeff * math.sin(theta + math.pi / 3) - offset
		local z2 = coeff * math.cos(theta + math.pi / 6) - offset
		if z0 < z1 then
			if z2 < z0 then
				return z2, z0, z1
			elseif z2 < z1 then
				return z0, z2, z1
			else
				return z0, z1, z2
			end
		else
			if z2 < z1 then
				return z2, z1, z0
			elseif z2 < z0 then
				return z1, z2, z0
			else
				return z1, z0, z2
			end
		end
	else -- return 3 real repeated roots (either 2 or 3 are equal)
		local cubeRootQ = cubeRoot(q)
		local z0 = -2 * cubeRootQ - offset
		local zRepeated = cubeRootQ - offset
		if z0 < zRepeated then
			return z0, zRepeated, zRepeated
		else
			return zRepeated, zRepeated, z0
		end
	end
end

return PolynomialUtils