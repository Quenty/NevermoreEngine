--!strict
--[=[
	@class TranslationKeyUtils
]=]

local require = require(script.Parent.loader).load(script)

local String = require("String")

local TranslationKeyUtils = {}

--[=[
	Converts a string to a translation key in a fixed format, with a maximum length

	@param prefix string
	@param text string
	@return string
]=]
function TranslationKeyUtils.getTranslationKey(prefix: string, text: string): string
	-- Camel-case first so spaces act as word boundaries ("Play Now" -> "playNow"),
	-- then cap the result. Stripping whitespace up-front would collapse the boundaries
	-- and lowercase everything ("playnow").
	local firstWords = string.sub(String.toLowerCamelCase(text), 1, 20)

	return prefix .. "." .. firstWords
end

return TranslationKeyUtils
