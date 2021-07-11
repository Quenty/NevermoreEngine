--- PolynomialUtils
-- @module PolynomialUtils

local PolynomialUtils = {}

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

return PolynomialUtils