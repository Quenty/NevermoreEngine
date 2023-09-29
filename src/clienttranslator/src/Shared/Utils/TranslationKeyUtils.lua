--[=[
	@class TranslationKeyUtils
]=]

local require = require(script.Parent.loader).load(script)

local String = require("String")

local TranslationKeyUtils = {}

function TranslationKeyUtils.getTranslationKey(prefix, text)
	local firstWordsBeginning = string.sub(string.gsub(text, "%s", ""), 1, 20)
	local firstWords = String.toLowerCamelCase(firstWordsBeginning)

	return prefix .. "." .. firstWords
end

return TranslationKeyUtils