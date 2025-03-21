--!strict
--[=[
	PolynomialUtils
	@class PolynomialUtils
]=]

local PolynomialUtils = {}

--[=[
    Solves a linear ordered equation
    @param a number
    @param b number
    @return number?
]=]
function PolynomialUtils.solveOrderedRealLinear(a: number, b: number): number?
	local z = -b / a
	if z ~= z then
		return -- return 0 solutions
	else
		return z
	end
end

--[=[
    Solves a quadratic polynomial

    @param a number
    @param b number
    @param c number
    @return number?
    @return number?
]=]
function PolynomialUtils.solveOrderedRealQuadratic(a: number, b: number, c: number): (number?, number?, number?)
	local d = (b * b - 4 * a * c) ^ 0.5
	if d ~= d then
		return -- return 0 solutions
	else
		local z0 = (-b - d) / (2 * a)
		local z1 = (-b + d) / (2 * a)
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

return PolynomialUtils
