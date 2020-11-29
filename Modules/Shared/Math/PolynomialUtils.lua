--- PolynomialUtils
-- @module PolynomialUtils

local PolynomialUtils = {}
local EPS = 1e-4

local function cubeRoot(x)
	if x < 0 then
		return -(-x)^(1/3)
	else
		return x^(1/3)
	end
end

function PolynomialUtils.solveOrderedRealLinear(a, b)
	local z = -b/a
	if z ~= z then
		return -- return 0 solutions
	else
		return z
	end
end

function PolynomialUtils.solveOrderedRealQuadratic(a, b, c)
	local d = (b*b - 4*a*c)^0.5
	if d ~= d then
		return -- return 0 solutions
	else
		local z0 = (-b - d)/(2*a)
		local z1 = (-b + d)/(2*a)
		if z0 ~= z0 or z1 ~= z1 then
			return PolynomialUtils.solveOrderedRealLinear(b, c)
		elseif z0 == z1 then
			return z0 -- returns only one solution
		elseif z1 < z0 then
			return z1, z0
		else
			return z0, z1
		end
	end
end

-- http://www2.trinity.unimelb.edu.au/~rbroekst/MathX/Cubic%20Formula.pdf
function PolynomialUtils.solveOrderedRealCubic(a, b, c, d)
	if math.abs(a) < EPS then
		if math.abs(b) < EPS then
			return PolynomialUtils.solveOrderedRealLinear(c, d)
		else
			return PolynomialUtils.solveOrderedRealQuadratic(b, c, d)
		end
	end

	local A = b / a
	local B = c / a
	local P = B - A^2 / 3
	local Q = 2*A^3/27 - A*B/3 + d/a
	local D = Q^2/4 + P^3/27 -- discriminant

	if D > EPS then -- one real root
		return cubeRoot(-Q/2 + math.sqrt(D)) + cubeRoot(-Q/2 - math.sqrt(D)) - A/3
	elseif D < -EPS then -- thee real distinct roots
		local coeff = 2 * math.sqrt(-P) / math.sqrt(3)
		local theta = math.asin(math.clamp(3/2/math.sqrt(-P)^3 * math.sqrt(3) * Q, -1, 1)) / 3
		local z0 = coeff * math.sin(theta) - A/3
		local z1 = -coeff * math.sin(theta + math.pi / 3) - A/3
		local z2 = coeff * math.cos(theta + math.pi / 6) - A/3
		local solutions = table.create(3)
		solutions[1], solutions[2], solutions[3] = z0, z1, z2
		table.sort(solutions)
		return table.unpack(solutions)
	else -- three real repeated roots (either two or three are the same)
		local z0 = -2 * cubeRoot(Q/2) - A/3
		local zRepeated = cubeRoot(Q/2) - A/3
		if z0 > zRepeated then
			return zRepeated, zRepeated, z0
		else
			return z0, zRepeated, zRepeated
		end
	end
end

return PolynomialUtils
