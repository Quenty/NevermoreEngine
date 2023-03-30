-- random.lua - Random Byte Generator
local sha256 = require(script.Parent.sha256)

local entropy = ""
local accumulator, accumulator_len = {}, 0

local function feed(data)
	accumulator_len += 1
	accumulator[accumulator_len] = tostring(data or "")
end

local function digest()
	entropy = tostring(sha256.digest(entropy .. table.concat(accumulator)))

	table.clear(accumulator)
	accumulator_len = 0
end

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
	feed(tostring({}):sub(-8))
end
digest()
feed(DateTime.now().UnixTimestampMillis)
digest()

local function save()
	feed("save")
	feed(DateTime.now().UnixTimestampMillis)
	feed({})
	digest()

	entropy = tostring(sha256.digest(entropy))
end
save()

local function seed(data)
	feed("seed")
	feed(DateTime.now().UnixTimestampMillis)
	feed({})
	feed(data)
	digest()
	save()
end

local function random()
	feed("random")
	feed(DateTime.now().UnixTimestampMillis)
	feed({})
	digest()
	save()

	local result = sha256.hmac("out", entropy)
	entropy = tostring(sha256.digest(entropy))

	return result
end

return {
	seed = seed,
	save = save,
	random = random,
}
