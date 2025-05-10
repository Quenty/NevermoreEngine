--!strict
--[=[
	Utility functions to do a cubic spline. Don't use this directly.
	@class CubicTweenUtils
]=]

local CubicTweenUtils = {}

--[=[
	Constants to be multiplied as p0*a0 + v0*a1 + p1*a2 + v1*a3
	@param l number
	@param t number
	@return number -- a0
	@return number -- a1
	@return number -- a2
	@return number -- a3
]=]
function CubicTweenUtils.getConstants(l: number, t: number): (number, number, number, number)
	local r = l - t
	local a0 = r * r * (r + 3 * t) / (l * l * l)
	local a1 = r * r * t / (l * l)
	local a2 = t * t * (t + 3 * r) / (l * l * l)
	local a3 = -t * t * r / (l * l)

	return a0, a1, a2, a3
end

--[=[
	@param l number
	@param t number
	@return number -- a0
	@return number -- a1
	@return number -- a2
	@return number -- a3
]=]
function CubicTweenUtils.getDerivativeConstants(l: number, t: number): (number, number, number, number)
	local r = l - t
	local b0 = -6 * r * t / (l * l * l)
	local b1 = r * (r - 2 * t) / (l * l)
	local b2 = 6 * r * t / (l * l * l)
	local b3 = t * (t - 2 * r) / (l * l)

	return b0, b1, b2, b3
end

--[=[
	Applies the constants for the given nodes
	@param c0 number
	@param c1 number
	@param c2 number
	@param c3 number
	@param a T
	@param u T
	@param b T
	@param v T
	@return T
]=]
function CubicTweenUtils.applyConstants<T>(c0: number, c1: number, c2: number, c3: number, a: T, u: T, b: T, v: T): T
	return c0 * (a :: any) + c1 * (u :: any) + c2 * (b :: any) + c3 * (v :: any)
end

--[=[
	Tweens betweeen nodes
	@param a T
	@param u T
	@param b T
	@param v T
	@param l number
	@param t number
	@return T
]=]
function CubicTweenUtils.tween<T>(a: T, u: T, b: T, v: T, l: number, t: number): T
	local a0, a1, a2, a3 = CubicTweenUtils.getConstants(l, t)

	return a0 * (a :: any) + a1 * (u :: any) + a2 * (b :: any) + a3 * (v :: any)
end

--[=[
	Computes acceleration
	@param a T
	@param u T
	@param b T
	@param v T
	@param l number
	@return T
]=]
function CubicTweenUtils.getAcceleration<T>(a: T, u: T, b: T, v: T, l: number): T
	local b0: any = b
	local u0: any = u
	local a0: any = a
	local v0: any = v

	return (12 * (b0 - a0) * (b0 - a0) - 12 * l * (b0 - a0) * (u0 + v0) + 4 * l * l * (u0 * u0 + u0 * v0 + v0 * v0))
		/ (l * l * l)
end

return CubicTweenUtils
