
-- Big integer arithmetic for 168-bit (and 336-bit) numbers
-- Numbers are represented as little-endian tables of 24-bit integers
local twoPower = require(script.Parent.twoPower)

local function isEqual(a, b)
	return a[1] == b[1]
		and a[2] == b[2]
		and a[3] == b[3]
		and a[4] == b[4]
		and a[5] == b[5]
		and a[6] == b[6]
		and a[7] == b[7]
end

local function compare(a, b)
	for i = 7, 1, -1 do
		if a[i] > b[i] then
			return 1
		elseif a[i] < b[i] then
			return -1
		end
	end

	return 0
end

local function add(a, b)
	-- c7 may be greater than 2^24 before reduction
	local c1 = a[1] + b[1]
	local c2 = a[2] + b[2]
	local c3 = a[3] + b[3]
	local c4 = a[4] + b[4]
	local c5 = a[5] + b[5]
	local c6 = a[6] + b[6]
	local c7 = a[7] + b[7]

	if c1 > 0xffffff then
		c2 = c2 + 1
		c1 = c1 - 0x1000000
	end
	if c2 > 0xffffff then
		c3 = c3 + 1
		c2 = c2 - 0x1000000
	end
	if c3 > 0xffffff then
		c4 = c4 + 1
		c3 = c3 - 0x1000000
	end
	if c4 > 0xffffff then
		c5 = c5 + 1
		c4 = c4 - 0x1000000
	end
	if c5 > 0xffffff then
		c6 = c6 + 1
		c5 = c5 - 0x1000000
	end
	if c6 > 0xffffff then
		c7 = c7 + 1
		c6 = c6 - 0x1000000
	end

	return { c1, c2, c3, c4, c5, c6, c7 }
end

local function sub(a, b)
	-- c7 may be negative before reduction
	local c1 = a[1] - b[1]
	local c2 = a[2] - b[2]
	local c3 = a[3] - b[3]
	local c4 = a[4] - b[4]
	local c5 = a[5] - b[5]
	local c6 = a[6] - b[6]
	local c7 = a[7] - b[7]

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

local function rShift(a)
	local c1 = a[1]
	local c2 = a[2]
	local c3 = a[3]
	local c4 = a[4]
	local c5 = a[5]
	local c6 = a[6]
	local c7 = a[7]

	c1 = c1 / 2
	c1 = c1 - c1 % 1
	c1 = c1 + (c2 % 2) * 0x800000
	c2 = c2 / 2
	c2 = c2 - c2 % 1
	c2 = c2 + (c3 % 2) * 0x800000
	c3 = c3 / 2
	c3 = c3 - c3 % 1
	c3 = c3 + (c4 % 2) * 0x800000
	c4 = c4 / 2
	c4 = c4 - c4 % 1
	c4 = c4 + (c5 % 2) * 0x800000
	c5 = c5 / 2
	c5 = c5 - c5 % 1
	c5 = c5 + (c6 % 2) * 0x800000
	c6 = c6 / 2
	c6 = c6 - c6 % 1
	c6 = c6 + (c7 % 2) * 0x800000
	c7 = c7 / 2
	c7 = c7 - c7 % 1

	return { c1, c2, c3, c4, c5, c6, c7 }
end

local function addDouble(a, b)
	-- a and b are 336-bit integers (14 words)
	local c1 = a[1] + b[1]
	local c2 = a[2] + b[2]
	local c3 = a[3] + b[3]
	local c4 = a[4] + b[4]
	local c5 = a[5] + b[5]
	local c6 = a[6] + b[6]
	local c7 = a[7] + b[7]
	local c8 = a[8] + b[8]
	local c9 = a[9] + b[9]
	local c10 = a[10] + b[10]
	local c11 = a[11] + b[11]
	local c12 = a[12] + b[12]
	local c13 = a[13] + b[13]
	local c14 = a[14] + b[14]

	if c1 > 0xffffff then
		c2 = c2 + 1
		c1 = c1 - 0x1000000
	end
	if c2 > 0xffffff then
		c3 = c3 + 1
		c2 = c2 - 0x1000000
	end
	if c3 > 0xffffff then
		c4 = c4 + 1
		c3 = c3 - 0x1000000
	end
	if c4 > 0xffffff then
		c5 = c5 + 1
		c4 = c4 - 0x1000000
	end
	if c5 > 0xffffff then
		c6 = c6 + 1
		c5 = c5 - 0x1000000
	end
	if c6 > 0xffffff then
		c7 = c7 + 1
		c6 = c6 - 0x1000000
	end
	if c7 > 0xffffff then
		c8 = c8 + 1
		c7 = c7 - 0x1000000
	end
	if c8 > 0xffffff then
		c9 = c9 + 1
		c8 = c8 - 0x1000000
	end
	if c9 > 0xffffff then
		c10 = c10 + 1
		c9 = c9 - 0x1000000
	end
	if c10 > 0xffffff then
		c11 = c11 + 1
		c10 = c10 - 0x1000000
	end
	if c11 > 0xffffff then
		c12 = c12 + 1
		c11 = c11 - 0x1000000
	end
	if c12 > 0xffffff then
		c13 = c13 + 1
		c12 = c12 - 0x1000000
	end
	if c13 > 0xffffff then
		c14 = c14 + 1
		c13 = c13 - 0x1000000
	end

	return { c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14 }
end

local function mult(a, b, half_multiply)
	local a1, a2, a3, a4, a5, a6, a7 = a[1], a[2], a[3], a[4], a[5], a[6], a[7]
	local b1, b2, b3, b4, b5, b6, b7 = b[1], b[2], b[3], b[4], b[5], b[6], b[7]

	local c1 = a1 * b1
	local c2 = a1 * b2 + a2 * b1
	local c3 = a1 * b3 + a2 * b2 + a3 * b1
	local c4 = a1 * b4 + a2 * b3 + a3 * b2 + a4 * b1
	local c5 = a1 * b5 + a2 * b4 + a3 * b3 + a4 * b2 + a5 * b1
	local c6 = a1 * b6 + a2 * b5 + a3 * b4 + a4 * b3 + a5 * b2 + a6 * b1
	local c7 = a1 * b7 + a2 * b6 + a3 * b5 + a4 * b4 + a5 * b3 + a6 * b2 + a7 * b1
	local c8, c9, c10, c11, c12, c13, c14
	if not half_multiply then
		c8 = a2 * b7 + a3 * b6 + a4 * b5 + a5 * b4 + a6 * b3 + a7 * b2
		c9 = a3 * b7 + a4 * b6 + a5 * b5 + a6 * b4 + a7 * b3
		c10 = a4 * b7 + a5 * b6 + a6 * b5 + a7 * b4
		c11 = a5 * b7 + a6 * b6 + a7 * b5
		c12 = a6 * b7 + a7 * b6
		c13 = a7 * b7
		c14 = 0
	else
		c8 = 0
	end

	local temp
	temp = c1
	c1 = c1 % 0x1000000
	c2 = c2 + (temp - c1) / 0x1000000
	temp = c2
	c2 = c2 % 0x1000000
	c3 = c3 + (temp - c2) / 0x1000000
	temp = c3
	c3 = c3 % 0x1000000
	c4 = c4 + (temp - c3) / 0x1000000
	temp = c4
	c4 = c4 % 0x1000000
	c5 = c5 + (temp - c4) / 0x1000000
	temp = c5
	c5 = c5 % 0x1000000
	c6 = c6 + (temp - c5) / 0x1000000
	temp = c6
	c6 = c6 % 0x1000000
	c7 = c7 + (temp - c6) / 0x1000000
	temp = c7
	c7 = c7 % 0x1000000
	if not half_multiply then
		c8 = c8 + (temp - c7) / 0x1000000
		temp = c8
		c8 = c8 % 0x1000000
		c9 = c9 + (temp - c8) / 0x1000000
		temp = c9
		c9 = c9 % 0x1000000
		c10 = c10 + (temp - c9) / 0x1000000
		temp = c10
		c10 = c10 % 0x1000000
		c11 = c11 + (temp - c10) / 0x1000000
		temp = c11
		c11 = c11 % 0x1000000
		c12 = c12 + (temp - c11) / 0x1000000
		temp = c12
		c12 = c12 % 0x1000000
		c13 = c13 + (temp - c12) / 0x1000000
		temp = c13
		c13 = c13 % 0x1000000
		c14 = c14 + (temp - c13) / 0x1000000
	end

	return { c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14 }
end

local function square(a)
	-- returns a 336-bit integer (14 words)
	local a1, a2, a3, a4, a5, a6, a7 = a[1], a[2], a[3], a[4], a[5], a[6], a[7]

	local c1 = a1 * a1
	local c2 = a1 * a2 * 2
	local c3 = a1 * a3 * 2 + a2 * a2
	local c4 = a1 * a4 * 2 + a2 * a3 * 2
	local c5 = a1 * a5 * 2 + a2 * a4 * 2 + a3 * a3
	local c6 = a1 * a6 * 2 + a2 * a5 * 2 + a3 * a4 * 2
	local c7 = a1 * a7 * 2 + a2 * a6 * 2 + a3 * a5 * 2 + a4 * a4
	local c8 = a2 * a7 * 2 + a3 * a6 * 2 + a4 * a5 * 2
	local c9 = a3 * a7 * 2 + a4 * a6 * 2 + a5 * a5
	local c10 = a4 * a7 * 2 + a5 * a6 * 2
	local c11 = a5 * a7 * 2 + a6 * a6
	local c12 = a6 * a7 * 2
	local c13 = a7 * a7
	local c14 = 0

	local temp
	temp = c1
	c1 = c1 % 0x1000000
	c2 = c2 + (temp - c1) / 0x1000000
	temp = c2
	c2 = c2 % 0x1000000
	c3 = c3 + (temp - c2) / 0x1000000
	temp = c3
	c3 = c3 % 0x1000000
	c4 = c4 + (temp - c3) / 0x1000000
	temp = c4
	c4 = c4 % 0x1000000
	c5 = c5 + (temp - c4) / 0x1000000
	temp = c5
	c5 = c5 % 0x1000000
	c6 = c6 + (temp - c5) / 0x1000000
	temp = c6
	c6 = c6 % 0x1000000
	c7 = c7 + (temp - c6) / 0x1000000
	temp = c7
	c7 = c7 % 0x1000000
	c8 = c8 + (temp - c7) / 0x1000000
	temp = c8
	c8 = c8 % 0x1000000
	c9 = c9 + (temp - c8) / 0x1000000
	temp = c9
	c9 = c9 % 0x1000000
	c10 = c10 + (temp - c9) / 0x1000000
	temp = c10
	c10 = c10 % 0x1000000
	c11 = c11 + (temp - c10) / 0x1000000
	temp = c11
	c11 = c11 % 0x1000000
	c12 = c12 + (temp - c11) / 0x1000000
	temp = c12
	c12 = c12 % 0x1000000
	c13 = c13 + (temp - c12) / 0x1000000
	temp = c13
	c13 = c13 % 0x1000000
	c14 = c14 + (temp - c13) / 0x1000000

	return { c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14 }
end

local function encodeInt(a)
	local enc = table.create(21)

	for i = 1, 7 do
		local word = a[i]
		for _ = 1, 3 do
			table.insert(enc, word % 256)
			word = math.floor(word / 256)
		end
	end

	return enc
end

local function decodeInt(enc)
	local a = {}
	local encCopy = table.create(21)

	for i = 1, 21 do
		local byte = enc[i]
		assert(type(byte) == "number", "integer decoding failure")
		assert(byte >= 0 and byte <= 255, "integer decoding failure")
		assert(byte % 1 == 0, "integer decoding failure")
		encCopy[i] = byte
	end

	for i = 1, 21, 3 do
		local word = 0
		for j = 2, 0, -1 do
			word *= 256
			word += encCopy[i + j]
		end

		table.insert(a, word)
	end

	return a
end

local function mods(d, w)
	local result = d[1] % twoPower[w]

	if result >= twoPower[w - 1] then
		result -= twoPower[w]
	end

	return result
end

-- Represents a 168-bit number as the (2^w)-ary Non-Adjacent Form
local function NAF(d, w)
	local t, t_len = {}, 0
	local newD = { table.unpack(d) }

	for _ = 1, 168 do
		if newD[1] % 2 == 1 then
			t_len += 1
			t[t_len] = mods(newD, w)
			newD = sub(newD, { t[#t], 0, 0, 0, 0, 0, 0 })
		else
			t_len += 1
			t[t_len] = 0
		end

		newD = rShift(newD)
	end

	return t
end

return {
	isEqual = isEqual,
	compare = compare,
	add = add,
	sub = sub,
	addDouble = addDouble,
	mult = mult,
	square = square,
	encodeInt = encodeInt,
	decodeInt = decodeInt,
	NAF = NAF,
}
