--!strict
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

local chacha20 = require(script.chacha20)
local curve = require(script.curve)
local modq = require(script.modq)
local random = require(script.random)
local sha256 = require(script.sha256)
local util = require(script.util)

type ByteTable = typeof(setmetatable({} :: { number }, {} :: typeof(util.byteTableMT)))

local EllipticCurveCryptography = {}

EllipticCurveCryptography.chacha20 = chacha20
EllipticCurveCryptography.sha256 = sha256
EllipticCurveCryptography.random = random
EllipticCurveCryptography._byteMetatable = assert(util.byteTableMT, "No byteTable")

--[=[
	Returns true if it's an ByteTable

	@param key any
	@return boolean
]=]
function EllipticCurveCryptography.isByteTable(key: any): boolean
	return type(key) == "table" and getmetatable(key) == EllipticCurveCryptography._byteMetatable
end

--[=[
	Adds the byte table to the value

	@param value any
]=]
function EllipticCurveCryptography.createByteTable(value: { number }): ByteTable
	assert(type(value) == "table", "Bad value")

	return setmetatable(table.clone(value), EllipticCurveCryptography._byteMetatable)
end

function EllipticCurveCryptography._getNonceFromEpoch(): { number }
	local nonce: { number } = table.create(12)
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
function EllipticCurveCryptography.encrypt(data: string | ByteTable, key: ByteTable): ByteTable
	assert(type(data) == "string" or EllipticCurveCryptography.isByteTable(data), "Bad data")
	assert(EllipticCurveCryptography.isByteTable(key), "Bad key")

	local encKey = sha256.hmac("encKey", (key :: any) :: { number })
	local macKey = sha256.hmac("macKey", (key :: any) :: { number })
	local nonce = EllipticCurveCryptography._getNonceFromEpoch()

	local ciphertext = chacha20.crypt(data :: any, (encKey :: any) :: { number }, nonce)

	local result: { number } = nonce
	for _, value in ipairs(ciphertext :: any) do
		table.insert(result, value)
	end

	local mac = sha256.hmac(result, (macKey :: any) :: { number })
	for _, value in ipairs((mac :: any) :: { number }) do
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
function EllipticCurveCryptography.decrypt(data: string | ByteTable, key: ByteTable): ByteTable
	assert(type(data) == "string" or EllipticCurveCryptography.isByteTable(data), "Bad data")
	assert(EllipticCurveCryptography.isByteTable(key), "Bad key")

	local actualData: { number } = type(data) == "table" and { table.unpack(data :: any) }
		or { string.byte(tostring(data), 1, -1) }
	local encKey = sha256.hmac("encKey", (key :: any) :: { number })
	local macKey = sha256.hmac("macKey", (key :: any) :: { number })
	local mac = sha256.hmac({ table.unpack(actualData, 1, #actualData - 32) }, (macKey :: any) :: { number })
	local messageMac = { table.unpack(actualData, #actualData - 31) }
	assert((mac :: any):isEqual(messageMac), "invalid mac")
	local nonce = { table.unpack(actualData, 1, 12) }
	local ciphertext = { table.unpack(actualData, 13, #actualData - 32) }
	local result: ByteTable = chacha20.crypt(ciphertext, (encKey :: any) :: { number }, nonce)

	return result
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
function EllipticCurveCryptography.keypair(seed: number): (ByteTable, ByteTable)
	assert(type(seed) == "number", "Bad seed")

	local x: any
	if seed then
		x = modq.hashModQ(seed)
	else
		x = modq.randomModQ()
	end

	local Y = curve.G * x

	local privateKey: ByteTable = x:encode()
	local publicKey: ByteTable = Y:encode()

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
function EllipticCurveCryptography.exchange(privateKey: ByteTable, publicKey: ByteTable): ByteTable
	assert(EllipticCurveCryptography.isByteTable(privateKey), "Bad privateKey")
	assert(EllipticCurveCryptography.isByteTable(publicKey), "Bad publicKey")

	local x = modq.decodeModQ(privateKey)
	local Y = curve.pointDecode(publicKey :: any)
	local Z = Y * x

	local sharedSecret: ByteTable = sha256.digest(Z:encode())

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
function EllipticCurveCryptography.sign(privateKey: ByteTable, message: string | ByteTable): ByteTable
	assert(EllipticCurveCryptography.isByteTable(privateKey), "Bad privateKey")
	assert(type(message) == "string" or EllipticCurveCryptography.isByteTable(message), "Bad message")

	local actualMessage = type(message) == "table" and string.char(table.unpack(message :: any))
		or tostring(message)
	local actualPrivateKey = type(privateKey) == "table" and string.char(table.unpack(privateKey :: any))
		or tostring(privateKey)

	local x: any = modq.decodeModQ(actualPrivateKey)
	local k: any = modq.randomModQ()
	local R = curve.G * k
	local e: any = modq.hashModQ(actualMessage .. tostring(R))
	local s = k - x * e

	e = e:encode()
	s = s:encode()

	local result: { number } = e
	local result_len = #e
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
function EllipticCurveCryptography.verify(publicKey: ByteTable, message: string | ByteTable, signature: ByteTable): boolean
	assert(EllipticCurveCryptography.isByteTable(publicKey), "Bad privateKey")
	assert(type(message) == "string" or EllipticCurveCryptography.isByteTable(message), "Bad message")
	assert(EllipticCurveCryptography.isByteTable(signature), "Bad signature")

	local actualMessage = type(message) == "table" and string.char(table.unpack(message :: any))
		or tostring(message)
	local sigLen = #signature
	local Y = curve.pointDecode(publicKey :: any)
	local e = modq.decodeModQ({ table.unpack(signature :: any, 1, sigLen / 2) })
	local s = modq.decodeModQ({ table.unpack(signature :: any, sigLen / 2 + 1) })
	local Rv = curve.G * s + Y * e
	local ev = modq.hashModQ(actualMessage .. tostring(Rv))

	return ev == e
end

return EllipticCurveCryptography
