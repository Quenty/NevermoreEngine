local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local ecc = require(script.Parent)

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- helper function
local function generateTestData(size)
    local data = table.create(size)
    for x = 1, size do
        data[x] = math.random(35, 120)
    end
    return string.char(table.unpack(data))
end

describe("EllipticCurveCryptography Performance", function()
    local N, S = 500, 100 -- N iterations, S bytes per payload

    it(string.format("should efficiently process %d payloads of %d bytes", N, S), function()
        local serverPrivate, serverPublic = ecc.keypair(DateTime.now().UnixTimestamp)
        local clientPrivate, clientPublic = ecc.keypair(DateTime.now().UnixTimestamp)
        local serverSecret = ecc.exchange(serverPrivate, clientPublic)
        local clientSecret = ecc.exchange(clientPrivate, serverPublic)

        -- verify shared secret matches before benchmarking
        expect(tostring(serverSecret)).toEqual(tostring(clientSecret))

        local encryptSum, decryptSum = 0, 0

        for _ = 1, N do
            local payload = generateTestData(S)

            -- measure encryption + signing
            local start = os.clock()
            local ciphertext = ecc.encrypt(payload, clientSecret)
            local sig = ecc.sign(clientPrivate, payload)
            encryptSum += os.clock() - start

            -- measure decryption + verification
            start = os.clock()
            local plaintext = ecc.decrypt(ciphertext, serverSecret)
            ecc.verify(clientPublic, plaintext, sig)
            decryptSum += os.clock() - start
        end

        -- calculate metrics
        local encryptTotal = encryptSum * 1000 -- convert to ms
        local encryptAvg = (encryptSum / N) * 1000
        local decryptTotal = decryptSum * 1000
        local decryptAvg = (decryptSum / N) * 1000

        -- performance expectations
        -- expect(encryptAvg).toBeLessThan(1) -- expect sub-1ms average for encryption
        -- expect(decryptAvg).toBeLessThan(1) -- expect sub-1ms average for decryption

        -- log performance results (optional, but useful for debugging)
        print(string.format(
            "benchmark results:\n" ..
            "encrypt & sign: %.2fms total, %.2fms avg\n" ..
            "decrypt & verify: %.2fms total, %.2fms avg",
            encryptTotal, encryptAvg, decryptTotal, decryptAvg
        ))
    end, 30000)
end)