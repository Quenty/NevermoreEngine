local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local ecc = require(script.Parent)

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function generateTestData(size: number)
    local data = table.create(size)
    for x = 1, size do
        data[x] = math.random(35, 120)
    end
    return string.char(table.unpack(data))
end

describe("EllipticCurveCryptography", function()
    it("should generate matching shared secrets", function()
        local serverPrivate, serverPublic = ecc.keypair(DateTime.now().UnixTimestamp)
        local clientPrivate, clientPublic = ecc.keypair(DateTime.now().UnixTimestamp)

        local serverSecret = ecc.exchange(serverPrivate, clientPublic)
        local clientSecret = ecc.exchange(clientPrivate, serverPublic)

        expect(tostring(serverSecret)).toEqual(tostring(clientSecret))
    end)

    it("should successfully encrypt, decrypt, and verify multiple payloads", function()
        local serverPrivate, serverPublic = ecc.keypair(DateTime.now().UnixTimestamp)
        local clientPrivate, clientPublic = ecc.keypair(DateTime.now().UnixTimestamp)
        local serverSecret = ecc.exchange(serverPrivate, clientPublic)
        local clientSecret = ecc.exchange(clientPrivate, serverPublic)

        for _ = 1, 100 do
            local payload = generateTestData(50)

            -- encrypt and sign
            local ciphertext = ecc.encrypt(payload, clientSecret)
            local sig = ecc.sign(clientPrivate, payload)

            -- decrypt and verify
            local plaintext = ecc.decrypt(ciphertext, serverSecret)
            local validate = ecc.verify(clientPublic, plaintext, sig)

            expect(payload).never.toEqual(tostring(ciphertext))
            expect(payload).toEqual(tostring(plaintext))
            expect(validate).toBe(true)
        end
    end)
end)
