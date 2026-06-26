--!strict
--!native

-- Arithmetic on the Finite Field of Integers modulo q
-- Where q is the generator's subgroup order.
local arith = require(script.Parent.arith)
local random = require(script.Parent.random)
local sha256 = require(script.Parent.sha256)
local util = require(script.Parent.util)

type BigInt = { number }

local isEqual = arith.isEqual
local compare = arith.compare
local add = arith.add
local sub = arith.sub
local addDouble = arith.addDouble
local mult = arith.mult
local square = arith.square
local encodeInt = arith.encodeInt
local decodeInt = arith.decodeInt

local modQMT: any

local q: BigInt = { 9622359, 6699217, 13940450, 16775734, 16777215, 16777215, 3940351 }
-- this isn't an optimization, it just shortens the amount of time I have to scroll
local qMinusTwoBinary: { number } = table.create(166, 1)
qMinusTwoBinary[2] = 0
qMinusTwoBinary[4] = 0
qMinusTwoBinary[6] = 0
qMinusTwoBinary[8] = 0
qMinusTwoBinary[11] = 0
qMinusTwoBinary[12] = 0
qMinusTwoBinary[14] = 0
qMinusTwoBinary[17] = 0
qMinusTwoBinary[19] = 0
qMinusTwoBinary[20] = 0
qMinusTwoBinary[22] = 0
qMinusTwoBinary[23] = 0
qMinusTwoBinary[26] = 0
qMinusTwoBinary[27] = 0
qMinusTwoBinary[28] = 0
qMinusTwoBinary[30] = 0
qMinusTwoBinary[33] = 0
qMinusTwoBinary[34] = 0
qMinusTwoBinary[35] = 0
qMinusTwoBinary[39] = 0
qMinusTwoBinary[40] = 0
qMinusTwoBinary[41] = 0
qMinusTwoBinary[44] = 0
qMinusTwoBinary[45] = 0
qMinusTwoBinary[48] = 0
qMinusTwoBinary[49] = 0
qMinusTwoBinary[51] = 0
qMinusTwoBinary[52] = 0
qMinusTwoBinary[53] = 0
qMinusTwoBinary[57] = 0
qMinusTwoBinary[60] = 0
qMinusTwoBinary[63] = 0
qMinusTwoBinary[65] = 0
qMinusTwoBinary[66] = 0
qMinusTwoBinary[68] = 0
qMinusTwoBinary[70] = 0
qMinusTwoBinary[73] = 0
qMinusTwoBinary[76] = 0
qMinusTwoBinary[79] = 0
qMinusTwoBinary[80] = 0
qMinusTwoBinary[81] = 0
qMinusTwoBinary[83] = 0
qMinusTwoBinary[158] = 0
qMinusTwoBinary[159] = 0
qMinusTwoBinary[160] = 0
qMinusTwoBinary[161] = 0
qMinusTwoBinary[162] = 0

-- We're using the Montgomery Reduction for fast modular multiplication.
-- https://en.wikipedia.org/wiki/Montgomery_modular_multiplication
-- r = 2^168
-- q * qInverse = -1 (mod r)
-- r2 = r * r (mod q)
local qInverse: BigInt = { 15218585, 5740955, 3271338, 9903997, 9067368, 7173545, 6988392 }
local r2: BigInt = { 1336213, 11071705, 9716828, 11083885, 9188643, 1494868, 3306114 }

-- Reduces a number from [0, 2q - 1] to [0, q - 1]
local function reduceModQ(a: BigInt): BigInt
	local result: BigInt = { table.unpack(a) }

	if compare(result, q) >= 0 then
		result = sub(result, q)
	end

	return setmetatable(result, modQMT) :: any
end

local function addModQ(a: BigInt, b: BigInt): BigInt
	return reduceModQ(add(a, b))
end

local function subModQ(a: BigInt, b: BigInt): BigInt
	local result: BigInt = sub(a, b)

	if result[7] < 0 then
		result = add(result, q)
	end

	return setmetatable(result, modQMT) :: any
end

-- Montgomery REDC algorithn
-- Reduces a number from [0, q^2 - 1] to [0, q - 1]
local function REDC(T: { number }): BigInt
	local m: BigInt = { table.unpack(mult({ table.unpack(T, 1, 7) }, qInverse, true), 1, 7) }
	local t: BigInt = { table.unpack(addDouble(T, mult(m, q, false)), 8, 14) }

	return reduceModQ(t)
end

local function multModQ(a: BigInt, b: BigInt): BigInt
	-- Only works with a, b in Montgomery form
	return REDC(mult(a, b, false))
end

local function squareModQ(a: BigInt): BigInt
	-- Only works with a in Montgomery form
	return REDC(square(a))
end

local function montgomeryModQ(a: BigInt): BigInt
	return multModQ(a, r2)
end

local function inverseMontgomeryModQ(a: BigInt): BigInt
	local newA: { number } = { table.unpack(a) }

	for i = 8, 14 do
		newA[i] = 0
	end

	return REDC(newA)
end

local ONE: BigInt = montgomeryModQ({ 1, 0, 0, 0, 0, 0, 0 })

local function expModQ(base: BigInt, exponentBinary: { number }): BigInt
	local newBase: BigInt = { table.unpack(base) }
	local result: BigInt = { table.unpack(ONE) }

	for i = 1, 168 do
		if exponentBinary[i] == 1 then
			result = multModQ(result, newBase)
		end

		newBase = squareModQ(newBase)
	end

	return result
end

local function intExpModQ(base: BigInt, exponent: number): BigInt
	local newBase: BigInt = { table.unpack(base) }
	local result: BigInt = setmetatable({ table.unpack(ONE) }, modQMT) :: any

	if exponent < 0 then
		newBase = expModQ(newBase, qMinusTwoBinary)
		exponent = -exponent
	end

	while exponent > 0 do
		if exponent % 2 == 1 then
			result = multModQ(result, newBase)
		end

		newBase = squareModQ(newBase)
		exponent = math.floor(exponent / 2)
	end

	return result
end

local function encodeModQ(a: BigInt): { number }
	local result = encodeInt(a)

	return setmetatable(result, util.byteTableMT) :: any
end

local function decodeModQ(s: any): BigInt
	s = type(s) == "table" and { table.unpack(s :: { number }, 1, 21) } or { string.byte(tostring(s), 1, 21) }
	local result: BigInt = decodeInt(s)
	result[7] %= q[7]

	return setmetatable(result, modQMT) :: any
end

local function randomModQ(): BigInt
	while true do
		local s: { number } = { table.unpack((random.random() :: any), 1, 21) }
		local result: BigInt = decodeInt(s)
		if result[7] < q[7] then
			return setmetatable(result, modQMT) :: any
		end
	end
end

local function hashModQ(data: any): BigInt
	return decodeModQ(sha256.digest(data))
end

modQMT = {
	__index = {
		encode = function(self: BigInt): { number }
			return encodeModQ(self)
		end,
	},

	__tostring = function(self: BigInt): string
		return (self :: any):encode():toHex()
	end,

	__add = function(self: any, other: any): BigInt
		if type(self) == "number" then
			return other + self
		end

		if type(other) == "number" then
			assert(other < 16777216, "number operand too big")
			other = montgomeryModQ({ other, 0, 0, 0, 0, 0, 0 })
		end

		return addModQ(self, other)
	end,

	__sub = function(a: any, b: any): BigInt
		if type(a) == "number" then
			assert(a < 16777216, "number operand too big")
			a = montgomeryModQ({ a, 0, 0, 0, 0, 0, 0 })
		end

		if type(b) == "number" then
			assert(b < 16777216, "number operand too big")
			b = montgomeryModQ({ b, 0, 0, 0, 0, 0, 0 })
		end

		return subModQ(a, b)
	end,

	__unm = function(self: BigInt): BigInt
		return subModQ(q, self)
	end,

	__eq = function(self: BigInt, other: BigInt): boolean
		return isEqual(self, other)
	end,

	__mul = function(self: any, other: any): BigInt
		if type(self) == "number" then
			return other * self
		end

		-- EC point
		-- Use the point's metatable to handle multiplication
		if type(other) == "table" and type(other[1]) == "table" then
			return other * self
		end

		if type(other) == "number" then
			assert(other < 16777216, "number operand too big")
			other = montgomeryModQ({ other, 0, 0, 0, 0, 0, 0 })
		end

		return multModQ(self, other)
	end,

	__div = function(a: any, b: any): BigInt
		if type(a) == "number" then
			assert(a < 16777216, "number operand too big")
			a = montgomeryModQ({ a, 0, 0, 0, 0, 0, 0 })
		end

		if type(b) == "number" then
			assert(b < 16777216, "number operand too big")
			b = montgomeryModQ({ b, 0, 0, 0, 0, 0, 0 })
		end

		local bInv: BigInt = expModQ(b, qMinusTwoBinary)

		return multModQ(a, bInv)
	end,

	__pow = function(self: BigInt, other: number): BigInt
		return intExpModQ(self, other)
	end,
}

return {
	hashModQ = hashModQ,
	randomModQ = randomModQ,
	decodeModQ = decodeModQ,
	inverseMontgomeryModQ = inverseMontgomeryModQ,
}
