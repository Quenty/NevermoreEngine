--!native
local ecc = require(script.Parent)

warn("Running EllipticCurveCryptography benchmark...")

-- selene: allow(unused_variable)
local function printBytes(byteTable)
	return table.concat(byteTable, "-")
end

-- Each machine generates their tokens
local serverPrivate, serverPublic = ecc.keypair(ecc.random.random())
local clientPrivate, clientPublic = ecc.keypair(ecc.random.random())

-- print("\nserverPrivate:",printBytes(serverPrivate),"\nserverPublic:",printBytes(serverPublic))
-- print("\nclientPrivate:",printBytes(clientPrivate),"\nclientPublic:",printBytes(clientPublic))

-- They share their publics and exchange to shared secret
local serverSecret = ecc.exchange(serverPrivate, clientPublic)
local clientSecret = ecc.exchange(clientPrivate, serverPublic)

--print("\nsharedSecret:", printBytes(serverSecret))

assert(tostring(serverSecret) == tostring(clientSecret), "sharedSecret must be identical to both parties")

-- warn("encrypting and signing payload(s)")

local N, S = 500, 100
local encryptSum, decryptSum = 0, 0
local data = table.create(S)
for _ = 1, N do
	for x = 1, S do
		data[x] = math.random(35, 120)
	end
	local payload = string.char(table.unpack(data))

	local start = os.clock()
	local ciphertext = ecc.encrypt(payload, clientSecret)
	local sig = ecc.sign(clientPrivate, payload)
	encryptSum += os.clock() - start

	start = os.clock()
	local plaintext = ecc.decrypt(ciphertext, serverSecret)
	ecc.verify(clientPublic, plaintext, sig)

	decryptSum += os.clock() - start

	--print("    Bench run %d done", i)
end

print(
	string.format(
		"    Dataset: %d payloads of %d bytes of random data.\nResults:\n       Encrypt & Sign took %.2fms in total with a %.2fms avg.\n       Decrypt & Verify took %.2fms in total with a %.2fms avg.",
		N,
		S,
		encryptSum * 1000,
		(encryptSum / N) * 1000,
		decryptSum * 1000,
		(decryptSum / N) * 1000
	)
)

return true
