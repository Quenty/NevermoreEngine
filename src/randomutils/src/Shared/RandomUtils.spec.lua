local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local RandomUtils = require("RandomUtils")

local it = Jest.Globals.it
local expect = Jest.Globals.expect

it("returns one option from the list", function()
	local options = { "apples", "oranges", "bananas" }
	local choice = RandomUtils.choice(options)

	expect(choice).never.toBeNil()
end)

it("returns a shuffled copy of the table", function()
	local options = { "apples", "oranges", "bananas" }
	local shuffled = RandomUtils.shuffledCopy(options)

	expect(options).never.toBe(shuffled) -- make sure it's a copy
	expect(shuffled).toHaveLength(#options)
end)

it("shuffles the table", function()
	local options = { "apples", "oranges", "bananas" }
	RandomUtils.shuffle(options)

	expect(options).never.toBeNil()
end)

it("computes the gaussian random function", function()
	local random = Random.new()
	local computed = RandomUtils.gaussianRandom(random)

	expect(computed).toEqual(expect.any("number"))
end)

it("returns a random unit Vector3", function()
	local randomUnitVector = RandomUtils.randomUnitVector3(Random.new())

	expect(randomUnitVector).toEqual(expect.any("Vector3"))
end)
