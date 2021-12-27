--[=[
	Localized text utils which changes translationKey structures to shared locations
	@class LocalizedTextUtils
]=]

local LocalizedTextUtils = {}

--[=[
	Valid translation args
	@type TranslationArgs { [string]: LocalizedTextData | number | string }
	@within LocalizedTextUtils
]=]

--[=[
	Valid localized text data
	@interface LocalizedTextData
	.translationKey string
	.translationArgs TranslationArgs
	@within LocalizedTextUtils
]=]

--[=[
	Creates a new localizedtextdata
	@param translationKey string
	@param translationArgs TranslationArgs
	@return LocalizedTextData
]=]
function LocalizedTextUtils.create(translationKey, translationArgs)
	assert(type(translationKey) == "string", "Bad translationKey")
	assert(type(translationArgs) == "table" or translationArgs == nil, "Bad translationArgs")

	return {
		translationKey = translationKey;
		translationArgs = translationArgs;
	}
end

--[=[
	Returns whether the given argument is localized text
	@param data any
	@return boolean
]=]
function LocalizedTextUtils.isLocalizedText(data)
	return type(data) == "table"
		and type(data.translationKey) == "string"
		and (type(data.translationArgs) == "table"
			or data.translationArgs == nil)
end

--[=[
	Recursively formats the translated text
	@param translator Translator | JSONTranslator
	@param translationKey string
	@param translationArgs TranslationArgs
	@return string
]=]
function LocalizedTextUtils.formatByKeyRecursive(translator, translationKey, translationArgs)
	assert(translator, "Bad translator")
	assert(translationKey, "Bad translationKey")
	assert(translationArgs, "Bad translationArgs")

	local formattedArgs = {}
	for name, value in pairs(translationArgs) do
		if type(value) == "table" then
			assert(value.translationKey, "Table, but no translationKey")

			if value.translationArgs then
				formattedArgs[name] = LocalizedTextUtils
					.formatByKeyRecursive(translator, value.translationKey, value.translationArgs)
			else
				formattedArgs[name] = translator:FormatByKey(value.translationKey)
			end
		else
			formattedArgs[name] = value
		end
	end

	return translator:FormatByKey(translationKey, formattedArgs)
end

--[=[
	Recursively formats the translated text
	@param translator Translator | JSONTranslator
	@param localizedText LocalizedTextData
	@return string
]=]
function LocalizedTextUtils.localizedTextToString(translator, localizedText)
	assert(translator, "Bad translator")
	assert(localizedText, "No localizedText")
	assert(localizedText.translationKey, "No translationKey")
	assert(localizedText.translationArgs, "No translationArgs")

	return LocalizedTextUtils.formatByKeyRecursive(
		translator,
		localizedText.translationKey,
		localizedText.translationArgs)
end

return LocalizedTextUtils