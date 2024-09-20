--!native

-- random.lua - Random Byte Generator
local sha256 = require(script.Parent.sha256)

local entropy = ""
local accumulator, accumulator_len = {}, 0

local random = {}

local function feed(data)
	accumulator_len += 1
	accumulator[accumulator_len] = tostring(data or "")
end

local function digest()
	entropy = tostring(sha256.digest(entropy .. table.concat(accumulator)))

	table.clear(accumulator)
	accumulator_len = 0
end

local entropyInitialized = false

-- Defer this initialization until requested
local function ensureEntropyInit()
	if entropyInitialized then
		return
	end

	local startTime = os.clock()
	entropyInitialized = true

	-- This takes about 100ms

	feed("init")
	feed(math.random(1, 2 ^ 31 - 1))
	feed("|")
	feed(math.random(1, 2 ^ 31 - 1))
	feed("|")
	feed(math.random(1, 2 ^ 4))
	feed("|")
	feed(DateTime.now().UnixTimestampMillis)
	feed("|")
	for _ = 1, 10000 do
		feed(string.sub(tostring({}), -8))
	end
	digest()
	feed(DateTime.now().UnixTimestampMillis)
	digest()

	random.save()

	-- TODO: Suppress this warning
	warn(string.format("[EllipticCurveCryptography.random] - Generating entropy took %s ms", 1000*(os.clock() - startTime)))
end

function random.save()
	ensureEntropyInit()

	feed("save")
	feed(DateTime.now().UnixTimestampMillis)
	feed({})
	digest()

	entropy = tostring(sha256.digest(entropy))
end

function random.seed(data)
	ensureEntropyInit()

	feed("seed")
	feed(DateTime.now().UnixTimestampMillis)
	feed({})
	feed(data)
	digest()
	random.save()
end

function random.random()
	ensureEntropyInit()

	feed("random")
	feed(DateTime.now().UnixTimestampMillis)
	feed({})
	digest()
	random.save()

	local result = sha256.hmac("out", entropy)
	entropy = tostring(sha256.digest(entropy))

	return result
end

return random