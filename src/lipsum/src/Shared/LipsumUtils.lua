--!strict
--[=[
	Helpers to generate test text for a variety of situations, in the standard Lorem-Ipsum utility system.
	@class LipsumUtils
]=]

local require = require(script.Parent.loader).load(script)

local RandomUtils = require("RandomUtils")
local String = require("String")

local LipsumUtils = {}

-- stylua: ignore
local WORDS = {
	"lorem", "ipsum", "dolor", "sit", "amet", "consectetuer", "adipiscing", "elit", "sed", "diam", "nonummy",
	"nibh", "euismod", "tincidunt", "ut", "laoreet", "dolore", "magna", "aliquam", "erat"}

--[=[
	Generates a random username.

	```lua
	print(LipsumUtils.username()) --> LoremIpsum23
	```

	@param optionalRandom Random? -- Optional random
	@return string
]=]
function LipsumUtils.username(optionalRandom: Random?): string
	local random = optionalRandom or Random.new()

	local word = assert(RandomUtils.choice(WORDS, random), "Word list is empty")
	if random:NextNumber() <= 0.5 then
		word = String.uppercaseFirstLetter(word)
	end

	-- leet speak
	if random:NextNumber() <= 0.5 then
		if random:NextNumber() <= 0.75 then
			word = string.gsub(word, "o", "0")
		end
		if random:NextNumber() <= 0.75 then
			word = string.gsub(word, "i", "1")
		end
		if random:NextNumber() <= 0.75 then
			word = string.gsub(word, "l", "1")
		end
	end

	local number = random:NextNumber()
	if number <= 0.1 then
		return string.format("xXx%sxXx", word)
	elseif number <= 0.6 then
		return string.format("%s%03d", word, random:NextInteger(0, 999))
	else
		return word
	end
end

--[=[
	Generates a random word.

	```lua
	print(LipsumUtils.word()) --> Lipsum
	```

	@param random Random? -- Optional random
	@return string
]=]
function LipsumUtils.word(random: Random?): string
	return LipsumUtils.words(1, random)
end

--[=[
	Generates a random set of words space-separated.

	```lua
	print(LipsumUtils.words(5)) --> 5 words
	```

	@param numWords number
	@param random Random? -- Optional random
	@return string
]=]
function LipsumUtils.words(numWords: number, random: Random?): string
	local output = ""

	for w = 1, numWords do
		local word = assert(RandomUtils.choice(WORDS, random), "Word list is empty")

		if w == 1 then
			output ..= String.uppercaseFirstLetter(word)
		else
			output ..= " " .. word
		end
	end

	return output
end

--[=[
	Generates a random sentence.

	```lua
	print(LipsumUtils.sentence(7)) --> Sentence with 7 words.
	```

	@param numWords number? -- Defaults to a random number 6 to 12.
	@param optionalRandom Random? -- Optional random
	@return string
]=]
function LipsumUtils.sentence(numWords: number?, optionalRandom: Random?): string
	local random = optionalRandom or Random.new()
	local sentenceWords = numWords or random:NextInteger(6, 12)

	local output = ""

	local commaIndexes = {}
	if random:NextNumber() >= 0.3 and sentenceWords >= 8 then
		commaIndexes[random:NextInteger(4, 5)] = true
	end

	for w = 1, sentenceWords do
		local word = assert(RandomUtils.choice(WORDS, random), "Word list is empty")

		if w == 1 then
			output ..= String.uppercaseFirstLetter(word)
		else
			if commaIndexes[w] then
				output ..= ", " .. word
			else
				output ..= " " .. word
			end
		end
	end

	output ..= "."
	return output
end

export type GenerateCallback = () -> string

--[=[
	Generates a random paragraph.

	```lua
	print(LipsumUtils.paragraph(4)) --> Paragraph with 4 sentences.
	```

	@param numSentences number?
	@param createSentence (() -> string)? -- Optional createSentence
	@param optionalRandom Random? -- Optional random
	@return string
]=]
function LipsumUtils.paragraph(
	numSentences: number?,
	createSentence: GenerateCallback?,
	optionalRandom: Random?
): string
	local random = optionalRandom or Random.new()
	local paragraphnSentences = numSentences or random:NextInteger(5, 15)
	local generateSentence: GenerateCallback = createSentence
		or function()
			return LipsumUtils.sentence(nil, random)
		end

	local output = ""
	for s = 1, paragraphnSentences do
		output ..= generateSentence()

		if s ~= paragraphnSentences then
			output ..= " "
		end
	end
	return output
end

--[=[
	```lua
	print(LipsumUtils.document(3)) --> Document with 3 paragraphs
	```

	@param numParagraphs number?
	@param createParagraph (() -> string)? -- Optional createParagraph
	@param random Random? -- Optional random
	@return string
]=]
function LipsumUtils.document(numParagraphs: number?, createParagraph: GenerateCallback?, random: Random?): string
	random = random or Random.new()
	local paragraphCount = numParagraphs or 5
	local generateParagraph = createParagraph or function()
		return LipsumUtils.paragraph(nil, nil, random)
	end

	local output = ""
	for p=1, paragraphCount do
		output ..= generateParagraph()
		if p ~= paragraphCount then
			output ..= "\n\n"
		end
	end

	return output
end

return LipsumUtils