--!native

--[=[
	Elliptic Curve Cryptography

	Guessing the source is here: https://www.computercraft.info/forums2/index.php?/topic/29803-elliptic-curve-cryptography/
	@class EllipticCurveCryptography
]=]

--[[
MIT License

Copyright (c) 2022 boatbomber
Copyright (c) 2023 Quenty

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local util = require(script.util)
local sha256 = require(script.sha256)
local chacha20 = require(script.chacha20)
local random = require(script.random)
local modq = require(script.modq)
local curve = require(script.curve)
local EllipticCurveCryptography = {}

EllipticCurveCryptography.chacha20 = chacha20;
EllipticCurveCryptography.sha256 = sha256;
EllipticCurveCryptography.random = random;
EllipticCurveCryptography._byteMetatable = assert(util.byteTableMT, "No byteTable");

--[=[
	Returns true if it's an ByteTable

	@param key any
	@return boolean
]=]
function EllipticCurveCryptography.isByteTable(key)
	return type(key) == "table" and getmetatable(key) == EllipticCurveCryptography._byteMetatable
end

--[=[
	Adds the byte table to the value

	@param value any
]=]
function EllipticCurveCryptography.createByteTable(value)
	assert(type(value) == "table", "Bad value")

	return setmetatable(table.clone(value), EllipticCurveCryptography._byteMetatable)
end

function EllipticCurveCryptography._getNonceFromEpoch()
	local nonce = table.create(12)
	local epoch = DateTime.now().UnixTimestampMillis
	for i = 1, 12 do
		nonce[i] = epoch % 256
		epoch = math.floor(epoch / 256)
	end

	return nonce
end

--[=[
	Encrypts the data using the shared secret

	```lua
	local data = "Hello"

	local sharedSecret = ECC.exchange(serverPrivate, clientPublic)
	local encryptedData = ECC.encrypt(data, sharedSecret)

	-- Ensures the output is consistent
	local signature = ECC.sign(clientPrivate, data)

	-- These 2 items are the output
	print(encryptedData, signature)
	```

	@param data string | ByteTable
	@param key ByteTable
	@return ByteTable
]=]
function EllipticCurveCryptography.encrypt(data, key)
	assert(type(data) == "string" or EllipticCurveCryptography.isByteTable(data), "Bad data")
	assert(EllipticCurveCryptography.isByteTable(key), "Bad key")

	local encKey = sha256.hmac("encKey", key)
	local macKey = sha256.hmac("macKey", key)
	local nonce = EllipticCurveCryptography._getNonceFromEpoch()

	local ciphertext = chacha20.crypt(data, encKey, nonce)

	local result = nonce
	for _, value in ipairs(ciphertext) do
		table.insert(result, value)
	end

	local mac = sha256.hmac(result, macKey)
	for _, value in ipairs(mac) do
		table.insert(result, value)
	end

	return setmetatable(result, util.byteTableMT)
end

--[=[
	Decrypts the data using the shared secret

	```lua
	local sharedSecret = ECC.exchange(serverPrivate, clientPublic)
	local data = ECC.decrypt(encryptedData, sharedSecret)

	print(tostring(data))
	```

	@param data string | ByteTable
	@param key ByteTable
	@return ByteTable
]=]
function EllipticCurveCryptography.decrypt(data, key)
	assert(type(data) == "string" or EllipticCurveCryptography.isByteTable(data), "Bad data")
	assert(EllipticCurveCryptography.isByteTable(key), "Bad key")

	local actualData = type(data) == "table" and { table.unpack(data) } or { string.byte(tostring(data), 1, -1) }
	local encKey = sha256.hmac("encKey", key)
	local macKey = sha256.hmac("macKey", key)
	local mac = sha256.hmac({ table.unpack(actualData, 1, #actualData - 32) }, macKey)
	local messageMac = { table.unpack(actualData, #actualData - 31) }
	assert(mac:isEqual(messageMac), "invalid mac")
	local nonce = { table.unpack(actualData, 1, 12) }
	local ciphertext = { table.unpack(actualData, 13, #actualData - 32) }
	local result = chacha20.crypt(ciphertext, encKey, nonce)

	return setmetatable(result, util.byteTableMT)
end

--[=[
	Exchanges a private and public key to get a shared secret from two
	public keys.

	```lua
	local ECC = require("EllipticCurveCryptography")

	local serverPrivate, serverPublic = ECC.keypair(ECC.random.random())
	local sharedSecret = ECC.exchange(serverPrivate, clientPublic)
	```

	@param seed number
	@return ByteTable -- privateKey
	@return ByteTable -- publicKey
]=]
function EllipticCurveCryptography.keypair(seed)
	assert(type(seed) == "number", "Bad seed")

	local x
	if seed then
		x = modq.hashModQ(seed)
	else
		x = modq.randomModQ()
	end

	local Y = curve.G * x

	local privateKey = x:encode()
	local publicKey = Y:encode()

	return privateKey, publicKey
end

--[=[
	Exchanges a private and public key to get a shared secret from two
	public keys.

	This allows for each the client and the server to encrypt and
	send data to each other securely.

	```lua
	local ECC = require("EllipticCurveCryptography")

	local serverPrivate, serverPublic = ECC.keypair(ECC.random.random())
	local sharedSecret = ECC.exchange(serverPrivate, clientPublic),
	```

	@param privateKey ByteTable
	@param publicKey ByteTable
	@return ByteTable
]=]
function EllipticCurveCryptography.exchange(privateKey, publicKey)
	assert(EllipticCurveCryptography.isByteTable(privateKey), "Bad privateKey")
	assert(EllipticCurveCryptography.isByteTable(publicKey), "Bad publicKey")

	local x = modq.decodeModQ(privateKey)
	local Y = curve.pointDecode(publicKey)
	local Z = Y * x

	local sharedSecret = sha256.digest(Z:encode())

	return sharedSecret
end

--[=[
	Signs the message with a private key

	```lua
	local signature = ECC.sign(clientPrivate, data)
	```

	@param privateKey ByteTable
	@param message string | EncodedMessage
	@return ByteTable
]=]
function EllipticCurveCryptography.sign(privateKey, message)
	assert(EllipticCurveCryptography.isByteTable(privateKey), "Bad privateKey")
	assert(type(message) == "string" or EllipticCurveCryptography.isByteTable(message), "Bad message")

	local actualMessage = type(message) == "table" and string.char(table.unpack(message)) or tostring(message)
	local actualPrivateKey = type(privateKey) == "table" and string.char(table.unpack(privateKey))
		or tostring(privateKey)

	local x = modq.decodeModQ(actualPrivateKey)
	local k = modq.randomModQ()
	local R = curve.G * k
	local e = modq.hashModQ(actualMessage .. tostring(R))
	local s = k - x * e

	e = e:encode()
	s = s:encode()

	local result, result_len = e, #e
	for index, value in ipairs(s) do
		result[result_len + index] = value
	end

	return setmetatable(result, util.byteTableMT)
end

--[=[
	Verifies that the message was signed with the public key and signature and ensures
	that the value is safe

	```lua
	local data = ECC.decrypt(encryptedData, sharedSecret)
	local verified = ECC.verify(clientPublic, data, signature)
	```

	@param publicKey ByteTable
	@param message ByteTable | string
	@param signature ByteTable
]=]
function EllipticCurveCryptography.verify(publicKey, message, signature)
	assert(EllipticCurveCryptography.isByteTable(publicKey), "Bad privateKey")
	assert(type(message) == "string" or EllipticCurveCryptography.isByteTable(message), "Bad message")
	assert(EllipticCurveCryptography.isByteTable(signature), "Bad signature")

	local actualMessage = type(message) == "table" and string.char(table.unpack(message)) or tostring(message)
	local sigLen = #signature
	local Y = curve.pointDecode(publicKey)
	local e = modq.decodeModQ({ table.unpack(signature, 1, sigLen / 2) })
	local s = modq.decodeModQ({ table.unpack(signature, sigLen / 2 + 1) })
	local Rv = curve.G * s + Y * e
	local ev = modq.hashModQ(actualMessage .. tostring(Rv))

	return ev == e
end

return EllipticCurveCryptography