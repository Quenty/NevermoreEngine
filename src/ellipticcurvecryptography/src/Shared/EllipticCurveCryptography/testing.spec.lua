local ecc = require(script.Parent)

warn("Running EllipticCurveCryptography tests...")

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

local data = table.create(50)
for _ = 1, 100 do
	for x = 1, 50 do
		data[x] = math.random(35, 120)
	end
	local payload = string.char(table.unpack(data))

	-- Client encrypts and signs their password payload
	local ciphertext = ecc.encrypt(payload, clientSecret)
	local sig = ecc.sign(clientPrivate, payload)

	-- print("\nencryptedPayload:",printBytes(ciphertext),"\nsignature:",printBytes(sig))

	-- warn("decrypting and verifying payload")
	-- Server recieves and validates
	local plaintext = ecc.decrypt(ciphertext, serverSecret)
	local validate = ecc.verify(clientPublic, plaintext, sig)

	-- print("\ndecryptedPayload:",plaintext,"\nverified:",validate)

	assert(payload ~= tostring(ciphertext), "Encrypted payload must be different from plaintext")
	assert(payload == tostring(plaintext), "Decrypted data must equal the original payload")
	assert(validate, "Signature must verify decrypted data")

	--print("    Test run %d passed", i)
end

print("    EllipticCurveCryptography tests passed")

return true
