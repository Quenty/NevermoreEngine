--!native

--[=[
	Elliptic curve arithmetic

	## About the Curve Itself
	Field Size: 168 bits
	Field Modulus (p): 481 * 2^159 + 3
	Equation: x^2 + y^2 = 1 + 122 * x^2 * y^2
	Parameters: Edwards Curve with d = 122
	Curve Order (n): 351491143778082151827986174289773107581916088585564
	Cofactor (h): 4
	Generator Order (q): 87872785944520537956996543572443276895479022146391

	## About the Curve's Security
	Current best attack security: 81.777 bits (Small Subgroup + Rho)
	Rho Security: log2(0.884 * sqrt(q)) = 82.777 bits
	Transfer Security? Yes: p ~= q; k > 20
	Field Discriminant Security? Yes:
	   t = 27978492958645335688000168
	   s = 10
	   |D| = 6231685068753619775430107799412237267322159383147 > 2^100
	Rigidity? No, not at all.
	XZ/YZ Ladder Security? No: Single coordinate ladders are insecure.
	Small Subgroup Security? No.
	Invalid Curve Security? Yes: Points are checked before every operation.
	Invalid Curve Twist Security? No: Don't use single coordinate ladders.
	Completeness? Yes: The curve is complete.
	Indistinguishability? Yes (Elligator 2), but not implemented.

	@class curve
]=]

local util = require(script.Parent.util)
local arith = require(script.Parent.arith)
local modp = require(script.Parent.modp)
local modq = require(script.Parent.modq)

local isEqual = arith.isEqual
local NAF = arith.NAF
local encodeInt = arith.encodeInt
local decodeInt = arith.decodeInt
local multModP = modp.multModP
local squareModP = modp.squareModP
local addModP = modp.addModP
local subModP = modp.subModP
local montgomeryModP = modp.montgomeryModP
local expModP = modp.expModP
local inverseMontgomeryModQ = modq.inverseMontgomeryModQ

local pointMT
local ZERO = table.create(7, 0)
local ONE = montgomeryModP({ 1, 0, 0, 0, 0, 0, 0 })

-- Curve Parameters
local d = montgomeryModP({ 122, 0, 0, 0, 0, 0, 0 })
local p = { 3, 0, 0, 0, 0, 0, 15761408 }
local pMinusTwoBinary = table.create(168, 0)
pMinusTwoBinary[1] = 1
pMinusTwoBinary[160] = 1
pMinusTwoBinary[165] = 1
pMinusTwoBinary[166] = 1
pMinusTwoBinary[167] = 1
pMinusTwoBinary[168] = 1

local pMinusThreeOverFourBinary = table.create(166, 0)
pMinusThreeOverFourBinary[158] = 1
pMinusThreeOverFourBinary[163] = 1
pMinusThreeOverFourBinary[164] = 1
pMinusThreeOverFourBinary[165] = 1
pMinusThreeOverFourBinary[166] = 1

local G = {
	{ 6636044, 10381432, 15741790, 2914241, 5785600, 264923, 4550291 },
	{ 13512827, 8449886, 5647959, 1135556, 5489843, 7177356, 8002203 },
	{ table.unpack(ONE) },
}

local O = {
	table.create(7, 0),
	{ table.unpack(ONE) },
	{ table.unpack(ONE) },
}

-- Projective Coordinates for Edwards curves for point addition/doubling.
-- Points are represented as: (X:Y:Z) where x = X/Z and y = Y/Z
-- The identity element is represented by (0:1:1)
-- Point operation formulas are available on the EFD:
-- https://www.hyperelliptic.org/EFD/g1p/auto-edwards-projective.html
local function pointDouble(P1)
	-- 3M + 4S
	local X1, Y1, Z1 = P1[1], P1[2], P1[3]

	local b = addModP(X1, Y1)
	local B = squareModP(b)
	local C = squareModP(X1)
	local D = squareModP(Y1)
	local E = addModP(C, D)
	local H = squareModP(Z1)
	local J = subModP(E, addModP(H, H))
	local X3 = multModP(subModP(B, E), J)
	local Y3 = multModP(E, subModP(C, D))
	local Z3 = multModP(E, J)
	local P3 = { X3, Y3, Z3 }

	return setmetatable(P3, pointMT)
end

local function pointAdd(P1, P2)
	-- 10M + 1S
	local X1, Y1, Z1 = P1[1], P1[2], P1[3]
	local X2, Y2, Z2 = P2[1], P2[2], P2[3]

	local A = multModP(Z1, Z2)
	local B = squareModP(A)
	local C = multModP(X1, X2)
	local D = multModP(Y1, Y2)
	local E = multModP(d, multModP(C, D))
	local F = subModP(B, E)
	-- selene: allow(shadowing)
	local G = addModP(B, E)
	local X3 = multModP(A, multModP(F, subModP(multModP(addModP(X1, Y1), addModP(X2, Y2)), addModP(C, D))))
	local Y3 = multModP(A, multModP(G, subModP(D, C)))
	local Z3 = multModP(F, G)
	local P3 = { X3, Y3, Z3 }

	return setmetatable(P3, pointMT)
end

local function pointNeg(P1)
	local X1, Y1, Z1 = P1[1], P1[2], P1[3]

	local X3 = subModP(ZERO, X1)
	local Y3 = { table.unpack(Y1) }
	local Z3 = { table.unpack(Z1) }
	local P3 = { X3, Y3, Z3 }

	return setmetatable(P3, pointMT)
end

local function pointSub(P1, P2)
	return pointAdd(P1, pointNeg(P2))
end

-- Converts (X:Y:Z) into (X:Y:1) = (x:y:1)
local function pointScale(P1)
	local X1, Y1, Z1 = P1[1], P1[2], P1[3]

	local A = expModP(Z1, pMinusTwoBinary)
	local X3 = multModP(X1, A)
	local Y3 = multModP(Y1, A)
	local Z3 = { table.unpack(ONE) }
	local P3 = { X3, Y3, Z3 }

	return setmetatable(P3, pointMT)
end

local function pointIsEqual(P1, P2)
	local X1, Y1, Z1 = P1[1], P1[2], P1[3]
	local X2, Y2, Z2 = P2[1], P2[2], P2[3]

	local A1 = multModP(X1, Z2)
	local B1 = multModP(Y1, Z2)
	local A2 = multModP(X2, Z1)
	local B2 = multModP(Y2, Z1)

	return isEqual(A1, A2) and isEqual(B1, B2)
end

-- Checks if a projective point satisfies the curve equation
local function pointIsOnCurve(P1)
	local X1, Y1, Z1 = P1[1], P1[2], P1[3]

	local X12 = squareModP(X1)
	local Y12 = squareModP(Y1)
	local Z12 = squareModP(Z1)
	local Z14 = squareModP(Z12)
	local a = addModP(X12, Y12)
	a = multModP(a, Z12)
	local b = multModP(d, multModP(X12, Y12))
	b = addModP(Z14, b)

	return isEqual(a, b)
end

local function pointIsInf(P1)
	return isEqual(P1[1], ZERO)
end

-- W-ary Non-Adjacent Form (wNAF) method for scalar multiplication:
-- https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication#w-ary_non-adjacent_form_(wNAF)_method
local function scalarMult(multiplier, P1)
	-- w = 5
	local naf = NAF(multiplier, 5)
	local PTable = { P1 }
	local P2 = pointDouble(P1)
	local Q = { table.create(7, 0), { table.unpack(ONE) }, { table.unpack(ONE) } }

	for i = 3, 31, 2 do
		PTable[i] = pointAdd(PTable[i - 2], P2)
	end

	for i = #naf, 1, -1 do
		Q = pointDouble(Q)
		if naf[i] > 0 then
			Q = pointAdd(Q, PTable[naf[i]])
		elseif naf[i] < 0 then
			Q = pointSub(Q, PTable[-naf[i]])
		end
	end

	return setmetatable(Q, pointMT)
end

-- Lookup table 4-ary NAF method for scalar multiplication by G.
-- Precomputations for the regular NAF method are done before the multiplication.
local GTable = { G }
for i = 2, 168 do
	GTable[i] = pointDouble(GTable[i - 1])
end

local function scalarMultG(multiplier)
	local naf = NAF(multiplier, 2)
	local Q = { table.create(7, 0), { table.unpack(ONE) }, { table.unpack(ONE) } }

	for i = 1, 168 do
		if naf[i] == 1 then
			Q = pointAdd(Q, GTable[i])
		elseif naf[i] == -1 then
			Q = pointSub(Q, GTable[i])
		end
	end

	return setmetatable(Q, pointMT)
end

-- Point compression and encoding.
-- Compresses curve points to 22 bytes.
local function pointEncode(P1)
	P1 = pointScale(P1)
	local result = {}
	local x, y = P1[1], P1[2]

	-- Encode y
	result = encodeInt(y)
	-- Encode one bit from x
	result[22] = x[1] % 2

	return setmetatable(result, util.byteTableMT)
end

local function pointDecode(enc)
	enc = type(enc) == "table" and { table.unpack(enc, 1, 22) } or { string.byte(tostring(enc), 1, 22) }
	-- Decode y
	local y = decodeInt(enc)
	y[7] %= p[7]
	-- Find {x, -x} using curve equation
	local y2 = squareModP(y)
	local u = subModP(y2, ONE)
	local v = subModP(multModP(d, y2), ONE)
	local u2 = squareModP(u)
	local u3 = multModP(u, u2)
	local u5 = multModP(u3, u2)
	local v3 = multModP(v, squareModP(v))
	local w = multModP(u5, v3)
	local x = multModP(u3, multModP(v, expModP(w, pMinusThreeOverFourBinary)))
	-- Use enc[22] to find x from {x, -x}
	if x[1] % 2 ~= enc[22] then
		x = subModP(ZERO, x)
	end

	local P3 = { x, y, { table.unpack(ONE) } }

	return setmetatable(P3, pointMT)
end

pointMT = {
	__index = {
		isOnCurve = function(self)
			return pointIsOnCurve(self)
		end,

		isInf = function(self)
			return self:isOnCurve() and pointIsInf(self)
		end,

		encode = function(self)
			return pointEncode(self)
		end,
	},

	__tostring = function(self)
		return self:encode():toHex()
	end,

	__add = function(P1, P2)
		assert(P1:isOnCurve(), "invalid point")
		assert(P2:isOnCurve(), "invalid point")

		return pointAdd(P1, P2)
	end,

	__sub = function(P1, P2)
		assert(P1:isOnCurve(), "invalid point")
		assert(P2:isOnCurve(), "invalid point")

		return pointSub(P1, P2)
	end,

	__unm = function(self)
		assert(self:isOnCurve(), "invalid point")

		return pointNeg(self)
	end,

	__eq = function(P1, P2)
		assert(P1:isOnCurve(), "invalid point")
		assert(P2:isOnCurve(), "invalid point")

		return pointIsEqual(P1, P2)
	end,

	__mul = function(P1, s)
		if type(P1) == "number" then
			return s * P1
		end

		if type(s) == "number" then
			assert(s < 16777216, "number multiplier too big")
			s = { s, 0, 0, 0, 0, 0, 0 }
		else
			s = inverseMontgomeryModQ(s)
		end

		if P1 == G then
			return scalarMultG(s)
		else
			return scalarMult(s, P1)
		end
	end,
}

G = setmetatable(G, pointMT)
O = setmetatable(O, pointMT)

return {
	G = G,
	O = O,
	pointDecode = pointDecode,
}
