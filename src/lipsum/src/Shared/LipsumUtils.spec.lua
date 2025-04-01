local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local LipsumUtils = require("LipsumUtils")

local it = Jest.Globals.it
local expect = Jest.Globals.expect

it("returns a randomly generated username", function()
	expect(LipsumUtils.username()).toEqual(expect.any("string"))
end)

it("returns a randomly generated word", function()
	expect(LipsumUtils.word()).toEqual(expect.any("string"))
end)

it("returns a fixed number of words", function()
	local randomWords = LipsumUtils.words(5)
	local words = string.split(randomWords, " ")

	expect(words).toHaveLength(5)
end)

it("returns a fixed number of words in a sentence", function()
	local randomSentence = LipsumUtils.sentence(10)
	local words = string.split(randomSentence, " ")

	expect(words).toHaveLength(10)
end)