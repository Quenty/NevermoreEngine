--!native

-- Chacha20 cipher in ComputerCraft
-- By Anavrins
-- For help and details, you can PM me on the CC forums
-- You may use this code in your projects without asking me, as long as credit is given and this header is kept intact
-- http://www.computercraft.info/forums2/index.php?/user/12870-anavrins
-- http://pastebin.com/GPzf9JSa
-- Last update: April 17, 2017
local twoPower = require(script.Parent.twoPower)
local util = require(script.Parent.util)

local bxor = bit32.bxor
local band = bit32.band
local blshift = bit32.lshift
local brshift = bit32.arshift

local mod = 2 ^ 32
local tau = table.pack(string.byte("expand 16-byte k", 1, -1))
local sigma = table.pack(string.byte("expand 32-byte k", 1, -1))

local function rotl(n, b)
	local s = n / twoPower[32 - b]
	local f = s % 1
	return (s - f) + f * mod
end

local function quarterRound(s, a, b, c, d)
	s[a] = (s[a] + s[b]) % mod
	s[d] = rotl(bxor(s[d], s[a]), 16)
	s[c] = (s[c] + s[d]) % mod
	s[b] = rotl(bxor(s[b], s[c]), 12)
	s[a] = (s[a] + s[b]) % mod
	s[d] = rotl(bxor(s[d], s[a]), 8)
	s[c] = (s[c] + s[d]) % mod
	s[b] = rotl(bxor(s[b], s[c]), 7)
	return s
end

local function hashBlock(state, rnd)
	local s = { table.unpack(state) }
	for i = 1, rnd do
		local r = i % 2 == 1
		s = r and quarterRound(s, 1, 5, 9, 13) or quarterRound(s, 1, 6, 11, 16)
		s = r and quarterRound(s, 2, 6, 10, 14) or quarterRound(s, 2, 7, 12, 13)
		s = r and quarterRound(s, 3, 7, 11, 15) or quarterRound(s, 3, 8, 9, 14)
		s = r and quarterRound(s, 4, 8, 12, 16) or quarterRound(s, 4, 5, 10, 15)
	end

	for i = 1, 16 do
		s[i] = (s[i] + state[i]) % mod
	end

	return s
end

local function LE_toInt(bs, i)
	return (bs[i + 1] or 0)
		+ blshift((bs[i + 2] or 0), 8)
		+ blshift((bs[i + 3] or 0), 16)
		+ blshift((bs[i + 4] or 0), 24)
end

local function initState(key, nonce, counter)
	local isKey256 = #key == 32
	local const = isKey256 and sigma or tau
	local state = table.create(16)

	state[1] = LE_toInt(const, 0)
	state[2] = LE_toInt(const, 4)
	state[3] = LE_toInt(const, 8)
	state[4] = LE_toInt(const, 12)

	state[5] = LE_toInt(key, 0)
	state[6] = LE_toInt(key, 4)
	state[7] = LE_toInt(key, 8)
	state[8] = LE_toInt(key, 12)
	state[9] = LE_toInt(key, isKey256 and 16 or 0)
	state[10] = LE_toInt(key, isKey256 and 20 or 4)
	state[11] = LE_toInt(key, isKey256 and 24 or 8)
	state[12] = LE_toInt(key, isKey256 and 28 or 12)

	state[13] = counter
	state[14] = LE_toInt(nonce, 0)
	state[15] = LE_toInt(nonce, 4)
	state[16] = LE_toInt(nonce, 8)

	return state
end

local function serialize(state)
	local r, len_r = table.create(16), 0
	for i = 1, 16 do
		r[len_r + 1] = band(state[i], 0xFF)
		r[len_r + 2] = band(brshift(state[i], 8), 0xFF)
		r[len_r + 3] = band(brshift(state[i], 16), 0xFF)
		r[len_r + 4] = band(brshift(state[i], 24), 0xFF)
		len_r += 4
	end

	return r
end

local function crypt(data, key, nonce, cntr, round)
	assert(type(key) == "table", "ChaCha20: Invalid key format (" .. type(key) .. "), must be table")
	assert(type(nonce) == "table", "ChaCha20: Invalid nonce format (" .. type(nonce) .. "), must be table")
	assert(#key == 16 or #key == 32, "ChaCha20: Invalid key length (" .. #key .. "), must be 16 or 32")
	assert(#nonce == 12, "ChaCha20: Invalid nonce length (" .. #nonce .. "), must be 12")

	local newData = type(data) == "table" and { table.unpack(data) } or util.stringToByteArray(data)
	cntr = tonumber(cntr) or 1
	round = tonumber(round) or 20

	local out, out_len = {}, 0
	local state = initState(key, nonce, cntr)
	local blockAmt = math.floor(#newData / 64)
	for i = 0, blockAmt do
		local ks = serialize(hashBlock(state, round))
		state[13] = (state[13] + 1) % mod

		local block = table.create(64)
		for j = 1, 64 do
			block[j] = newData[(i * 64) + j]
		end

		for j = 1, #block do
			out_len += 1
			out[out_len] = bxor(block[j], ks[j])
		end

		if i % 2500 == 0 then
			task.wait()
		end
	end

	return setmetatable(out, util.byteTableMT)
end

return {
	crypt = crypt,
}
