
-- Arithmetic on the finite field of integers modulo p
-- Where p is the finite field modulus
local arith = require(script.Parent.arith)
local add = arith.add
local sub = arith.sub
local addDouble = arith.addDouble
local mult = arith.mult
local square = arith.square

local p = { 3, 0, 0, 0, 0, 0, 15761408 }

-- We're using the Montgomery Reduction for fast modular multiplication.
-- https://en.wikipedia.org/wiki/Montgomery_modular_multiplication
-- r = 2^168
-- p * pInverse = -1 (mod r)
-- r2 = r * r (mod p)
local pInverse = { 5592405, 5592405, 5592405, 5592405, 5592405, 5592405, 14800213 }
local r2 = { 13533400, 837116, 6278376, 13533388, 837116, 6278376, 7504076 }

local function multByP(a)
	local a1, a2, a3, a4, a5, a6, a7 = a[1], a[2], a[3], a[4], a[5], a[6], a[7]

	local c1 = a1 * 3
	local c2 = a2 * 3
	local c3 = a3 * 3
	local c4 = a4 * 3
	local c5 = a5 * 3
	local c6 = a6 * 3
	local c7 = a1 * 15761408
	c7 = c7 + a7 * 3
	local c8 = a2 * 15761408
	local c9 = a3 * 15761408
	local c10 = a4 * 15761408
	local c11 = a5 * 15761408
	local c12 = a6 * 15761408
	local c13 = a7 * 15761408
	local c14 = 0

	local temp
	temp = c1 / 0x1000000
	c2 = c2 + (temp - temp % 1)
	c1 = c1 % 0x1000000
	temp = c2 / 0x1000000
	c3 = c3 + (temp - temp % 1)
	c2 = c2 % 0x1000000
	temp = c3 / 0x1000000
	c4 = c4 + (temp - temp % 1)
	c3 = c3 % 0x1000000
	temp = c4 / 0x1000000
	c5 = c5 + (temp - temp % 1)
	c4 = c4 % 0x1000000
	temp = c5 / 0x1000000
	c6 = c6 + (temp - temp % 1)
	c5 = c5 % 0x1000000
	temp = c6 / 0x1000000
	c7 = c7 + (temp - temp % 1)
	c6 = c6 % 0x1000000
	temp = c7 / 0x1000000
	c8 = c8 + (temp - temp % 1)
	c7 = c7 % 0x1000000
	temp = c8 / 0x1000000
	c9 = c9 + (temp - temp % 1)
	c8 = c8 % 0x1000000
	temp = c9 / 0x1000000
	c10 = c10 + (temp - temp % 1)
	c9 = c9 % 0x1000000
	temp = c10 / 0x1000000
	c11 = c11 + (temp - temp % 1)
	c10 = c10 % 0x1000000
	temp = c11 / 0x1000000
	c12 = c12 + (temp - temp % 1)
	c11 = c11 % 0x1000000
	temp = c12 / 0x1000000
	c13 = c13 + (temp - temp % 1)
	c12 = c12 % 0x1000000
	temp = c13 / 0x1000000
	c14 = c14 + (temp - temp % 1)
	c13 = c13 % 0x1000000

	return { c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14 }
end

-- Reduces a number from [0, 2p - 1] to [0, p - 1]
local function reduceModP(a)
	-- a < p
	if a[7] < 15761408 or a[7] == 15761408 and a[1] < 3 then
		return { table.unpack(a) }
	end

	-- a > p
	local c1 = a[1]
	local c2 = a[2]
	local c3 = a[3]
	local c4 = a[4]
	local c5 = a[5]
	local c6 = a[6]
	local c7 = a[7]

	c1 = c1 - 3
	c7 = c7 - 15761408

	if c1 < 0 then
		c2 = c2 - 1
		c1 = c1 + 0x1000000
	end

	if c2 < 0 then
		c3 = c3 - 1
		c2 = c2 + 0x1000000
	end

	if c3 < 0 then
		c4 = c4 - 1
		c3 = c3 + 0x1000000
	end

	if c4 < 0 then
		c5 = c5 - 1
		c4 = c4 + 0x1000000
	end

	if c5 < 0 then
		c6 = c6 - 1
		c5 = c5 + 0x1000000
	end

	if c6 < 0 then
		c7 = c7 - 1
		c6 = c6 + 0x1000000
	end

	return { c1, c2, c3, c4, c5, c6, c7 }
end

local function addModP(a, b)
	return reduceModP(add(a, b))
end

local function subModP(a, b)
	local result = sub(a, b)

	if result[7] < 0 then
		result = add(result, p)
	end

	return result
end

-- Montgomery REDC algorithn
-- Reduces a number from [0, p^2 - 1] to [0, p - 1]
local function REDC(T)
	local m = mult(T, pInverse, true)
	local t = { table.unpack(addDouble(T, multByP(m)), 8, 14) }

	return reduceModP(t)
end

local function multModP(a, b)
	-- Only works with a, b in Montgomery form
	return REDC(mult(a, b))
end

local function squareModP(a)
	-- Only works with a in Montgomery form
	return REDC(square(a))
end

local function montgomeryModP(a)
	return multModP(a, r2)
end

local function inverseMontgomeryModP(a)
	local newA = { table.unpack(a) }

	for i = 8, 14 do
		newA[i] = 0
	end

	return REDC(newA)
end

local ONE = montgomeryModP({ 1, 0, 0, 0, 0, 0, 0 })

local function expModP(base, exponentBinary)
	local newBase = { table.unpack(base) }
	local result = { table.unpack(ONE) }

	for i = 1, 168 do
		if exponentBinary[i] == 1 then
			result = multModP(result, newBase)
		end

		newBase = squareModP(newBase)
	end

	return result
end

return {
	addModP = addModP,
	subModP = subModP,
	multModP = multModP,
	squareModP = squareModP,
	montgomeryModP = montgomeryModP,
	inverseMontgomeryModP = inverseMontgomeryModP,
	expModP = expModP,
}
