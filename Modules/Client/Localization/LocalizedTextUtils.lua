--- Localized text utils which changes translationKey structures to shared locations
-- @module LocalizedTextUtils

local LocalizedTextUtils = {}

function LocalizedTextUtils.create(translationKey, translationArgs)
	assert(type(translationKey) == "string")
	assert(type(translationArgs) == "table" or translationArgs == nil)

	return {
		translationKey = translationKey;
		translationArgs = translationArgs;
	}
end

function LocalizedTextUtils.isLocalizedText(data)
	return type(data) == "table"
		and type(data.translationKey) == "string"
		and (type(data.translationArgs) == "table"
			or data.translationArgs == nil)
end

function LocalizedTextUtils.formatByKeyRecursive(translator, translationKey, translationArgs)
	assert(translator)
	assert(translationKey)
	assert(translationArgs)

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

function LocalizedTextUtils.localizedTextToString(translator, localizedText)
	assert(translator)
	assert(localizedText, "No localizedText")
	assert(localizedText.translationKey, "No translationKey")
	assert(localizedText.translationArgs, "No translationArgs")

	return LocalizedTextUtils.formatByKeyRecursive(
		translator,
		localizedText.translationKey,
		localizedText.translationArgs)
end

return LocalizedTextUtils