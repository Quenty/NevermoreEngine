--!native

-- SHA-256, HMAC and PBKDF2 functions in ComputerCraft
-- By Anavrins
-- For help and details, you can PM me on the CC forums
-- You may use this code in your projects without asking me, as long as credit is given and this header is kept intact
-- http://www.computercraft.info/forums2/index.php?/user/12870-anavrins
-- http://pastebin.com/6UV4qfNF
-- Last update: October 10, 2017
-- Updated by Quenty December 4th, 2023

local twoPower = require(script.Parent.twoPower)
local util = require(script.Parent.util)

local mod32 = 2 ^ 32
local band = bit32.band
local bnot = bit32.bnot
local bxor = bit32.bxor
local blshift = bit32.lshift

local function rrotate(n, b)
	local s = n / twoPower[b]
	local f = s % 1
	return (s - f) + f * mod32
end

local function brshift(int, by) -- Thanks bit32 for bad rshift
	return math.floor(int / twoPower[by])
end

local H = {
	0x6a09e667,
	0xbb67ae85,
	0x3c6ef372,
	0xa54ff53a,
	0x510e527f,
	0x9b05688c,
	0x1f83d9ab,
	0x5be0cd19,
}

local K = {
	0x428a2f98,
	0x71374491,
	0xb5c0fbcf,
	0xe9b5dba5,
	0x3956c25b,
	0x59f111f1,
	0x923f82a4,
	0xab1c5ed5,
	0xd807aa98,
	0x12835b01,
	0x243185be,
	0x550c7dc3,
	0x72be5d74,
	0x80deb1fe,
	0x9bdc06a7,
	0xc19bf174,
	0xe49b69c1,
	0xefbe4786,
	0x0fc19dc6,
	0x240ca1cc,
	0x2de92c6f,
	0x4a7484aa,
	0x5cb0a9dc,
	0x76f988da,
	0x983e5152,
	0xa831c66d,
	0xb00327c8,
	0xbf597fc7,
	0xc6e00bf3,
	0xd5a79147,
	0x06ca6351,
	0x14292967,
	0x27b70a85,
	0x2e1b2138,
	0x4d2c6dfc,
	0x53380d13,
	0x650a7354,
	0x766a0abb,
	0x81c2c92e,
	0x92722c85,
	0xa2bfe8a1,
	0xa81a664b,
	0xc24b8b70,
	0xc76c51a3,
	0xd192e819,
	0xd6990624,
	0xf40e3585,
	0x106aa070,
	0x19a4c116,
	0x1e376c08,
	0x2748774c,
	0x34b0bcb5,
	0x391c0cb3,
	0x4ed8aa4a,
	0x5b9cca4f,
	0x682e6ff3,
	0x748f82ee,
	0x78a5636f,
	0x84c87814,
	0x8cc70208,
	0x90befffa,
	0xa4506ceb,
	0xbef9a3f7,
	0xc67178f2,
}

local function counter(incr)
	local t1, t2 = 0, 0
	if 0xFFFFFFFF - t1 < incr then
		t2 = t2 + 1
		t1 = incr - (0xFFFFFFFF - t1) - 1
	else
		t1 = t1 + incr
	end

	return t2, t1
end

local function BE_toInt(bs, i)
	return blshift((bs[i] or 0), 24) + blshift((bs[i + 1] or 0), 16) + blshift((bs[i + 2] or 0), 8) + (bs[i + 3] or 0)
end

local function preprocess(data)
	local len = #data
	local data_len = #data + 1

	data[data_len] = 0x80
	while data_len % 64 ~= 56 do
		data_len += 1
		data[data_len] = 0
	end

	local blocks = math.ceil(data_len / 64)

	local proc = table.create(blocks)
	for i = 1, blocks do
		local block = table.create(16)
		proc[i] = block
		for j = 1, 16 do
			block[j] = BE_toInt(data, 1 + ((i - 1) * 64) + ((j - 1) * 4))
		end
	end

	proc[blocks][15], proc[blocks][16] = counter(len * 8)
	return proc
end

local function digestblock(w, C)
	for j = 17, 64 do
		local s0 = bxor(bxor(rrotate(w[j - 15], 7), rrotate(w[j - 15], 18)), brshift(w[j - 15], 3))
		local s1 = bxor(bxor(rrotate(w[j - 2], 17), rrotate(w[j - 2], 19)), brshift(w[j - 2], 10))
		w[j] = (w[j - 16] + s0 + w[j - 7] + s1) % mod32
	end

	local a, b, c, d, e, f, g, h = C[1], C[2], C[3], C[4], C[5], C[6], C[7], C[8]
	for j = 1, 64 do
		local S1 = bxor(bxor(rrotate(e, 6), rrotate(e, 11)), rrotate(e, 25))
		local ch = bxor(band(e, f), band(bnot(e), g))
		local temp1 = (h + S1 + ch + K[j] + w[j]) % mod32
		local S0 = bxor(bxor(rrotate(a, 2), rrotate(a, 13)), rrotate(a, 22))
		local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
		local temp2 = (S0 + maj) % mod32
		h, g, f, e, d, c, b, a = g, f, e, (d + temp1) % mod32, c, b, a, (temp1 + temp2) % mod32
	end

	C[1] = (C[1] + a) % mod32
	C[2] = (C[2] + b) % mod32
	C[3] = (C[3] + c) % mod32
	C[4] = (C[4] + d) % mod32
	C[5] = (C[5] + e) % mod32
	C[6] = (C[6] + f) % mod32
	C[7] = (C[7] + g) % mod32
	C[8] = (C[8] + h) % mod32
	return C
end

local function toBytes(t, n)
	local b = table.create(n * 4)
	for i = 1, n do
		b[(i - 1) * 4 + 1] = band(brshift(t[i], 24), 0xFF)
		b[(i - 1) * 4 + 2] = band(brshift(t[i], 16), 0xFF)
		b[(i - 1) * 4 + 3] = band(brshift(t[i], 8), 0xFF)
		b[(i - 1) * 4 + 4] = band(t[i], 0xFF)
	end

	return setmetatable(b, util.byteTableMT)
end

local function digest(data)
	data = data or ""
	data = type(data) == "table" and { table.unpack(data) } or util.stringToByteArray(data)

	data = preprocess(data)
	local C = { table.unpack(H) }
	for _, value in ipairs(data) do
		C = digestblock(value, C)
	end

	return toBytes(C, 8)
end

local function hmac(data, key)
	local actualData = type(data) == "table" and { table.unpack(data) } or util.stringToByteArray(data)
	local actualKey = type(key) == "table" and { table.unpack(key) } or util.stringToByteArray(key)

	local blocksize = 64

	actualKey = #actualKey > blocksize and digest(actualKey) or actualKey

	local ipad = table.create(blocksize)
	local opad = table.create(blocksize)

	for i = 1, blocksize do
		ipad[i] = bxor(0x36, actualKey[i] or 0)
		opad[i] = bxor(0x5C, actualKey[i] or 0)
	end

	for i, value in ipairs(actualData) do
		ipad[blocksize + i] = value
	end

	ipad = digest(ipad)
	local padded_key = table.create(blocksize * 2)
	for i = 1, blocksize do
		padded_key[i] = opad[i]
		padded_key[blocksize + i] = ipad[i]
	end

	return digest(padded_key)
end

local function pbkdf2(pass, salt, iter, dklen)
	local actualSalt = type(salt) == "table" and salt or util.stringToByteArray(salt)
	local hashlen = 32
	local actualDklen = dklen or 32
	local block = 1
	local out = {}

	while actualDklen > 0 do
		local ikey = {}
		local isalt = { table.unpack(actualSalt) }
		local isalt_len = #isalt
		local clen = actualDklen > hashlen and hashlen or actualDklen

		isalt[isalt_len + 1] = band(brshift(block, 24), 0xFF)
		isalt[isalt_len + 2] = band(brshift(block, 16), 0xFF)
		isalt[isalt_len + 3] = band(brshift(block, 8), 0xFF)
		isalt[isalt_len + 4] = band(block, 0xFF)

		isalt_len += 4

		for _ = 1, iter do
			isalt = hmac(isalt, pass)
			for k = 1, clen do
				ikey[k] = bxor(isalt[k], ikey[k] or 0)
			end
			-- if j % 200 == 0 then
			-- 	coroutine.yield("PBKDF2")
			-- end
		end

		actualDklen = actualDklen - clen
		block = block + 1
		for k = 1, clen do
			out[k] = ikey[k]
		end
	end

	return setmetatable(out, util.byteTableMT)
end

return {
	digest = digest,
	hmac = hmac,
	pbkdf2 = pbkdf2,
}
