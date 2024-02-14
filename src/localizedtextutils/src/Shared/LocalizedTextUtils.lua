--[=[
	Localized text utils which changes translationKey structures to shared locations
	@class LocalizedTextUtils
]=]

local HttpService = game:GetService("HttpService")

local require = require(script.Parent.loader).load(script)

local RxAttributeUtils = require("RxAttributeUtils")
local Rx = require("Rx")

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
	Recursively formats the translated text.
	@param translator Translator | JSONTranslator
	@param translationKey string
	@param translationArgs TranslationArgs?
	@param extraArgs table?
	@return string
]=]
function LocalizedTextUtils.formatByKeyRecursive(translator, translationKey, translationArgs, extraArgs)
	assert(translator, "Bad translator")
	assert(type(translationKey) == "string", "Bad translationKey")
	assert(type(translationArgs) == "table" or translationArgs == nil, "Bad translationArgs")

	local formattedArgs = {}
	if translationArgs then
		for name, value in pairs(translationArgs) do
			if type(value) == "table" then
				assert(value.translationKey, "Table, but no translationKey")

				if value.translationArgs then
					formattedArgs[name] = LocalizedTextUtils
						.formatByKeyRecursive(translator, value.translationKey, value.translationArgs, extraArgs)
				else
					formattedArgs[name] = translator:FormatByKey(value.translationKey)
				end
			else
				formattedArgs[name] = value
			end
		end
	end

	if extraArgs then
		for key, value in pairs(extraArgs) do
			formattedArgs[key] = value
		end
	end

	return translator:FormatByKey(translationKey, formattedArgs)
end

--[=[
	Observes the recursively formatted translated text.

	@param translator Translator | JSONTranslator
	@param translationKey string
	@param translationArgs TranslationArgs?
	@param extraArgs table?
	@return Observable<string>
]=]
function LocalizedTextUtils.observeFormatByKeyRecursive(translator, translationKey, translationArgs, extraArgs)
	assert(translator, "Bad translator")
	assert(type(translationKey) == "string", "Bad translationKey")
	assert(type(translationArgs) == "table" or translationArgs == nil, "Bad translationArgs")

	local observableFormattedArgs = {}
	if translationArgs then
		for name, value in pairs(translationArgs) do
			if type(value) == "table" then
				assert(value.translationKey, "Table, but no translationKey")

				if value.translationArgs then
					observableFormattedArgs[name] = LocalizedTextUtils
						.observeFormatByKeyRecursive(translator, value.translationKey, value.translationArgs, extraArgs)
				else
					observableFormattedArgs[name] = translator:ObserveFormatByKey(value.translationKey)
				end
			else
				observableFormattedArgs[name] = value
			end
		end
	end

	if extraArgs then
		for key, value in pairs(extraArgs) do
			observableFormattedArgs[key] = value
		end
	end

	return translator:ObserveFormatByKey(translationKey, observableFormattedArgs)
end

--[=[
	Observes the translations by string recursively

	@param translator Translator | JSONTranslator
	@param localizedText LocalizedTextData
	@param extraArgs table?
	@return Observable<string>
]=]
function LocalizedTextUtils.observeLocalizedTextToString(translator, localizedText, extraArgs)
	assert(translator, "Bad translator")
	assert(LocalizedTextUtils.isLocalizedText(localizedText), "No localizedText")

	return LocalizedTextUtils.observeFormatByKeyRecursive(
		translator,
		localizedText.translationKey,
		localizedText.translationArgs,
		extraArgs)
end

--[=[
	Recursively formats the translated text

	:::tip
	Use LocalizedTextUtils.observeLocalizedTextToString(translator, localizedText, extraArgs)
	:::

	@param translator Translator | JSONTranslator
	@param localizedText LocalizedTextData
	@param extraArgs table?
	@return string
]=]
function LocalizedTextUtils.localizedTextToString(translator, localizedText, extraArgs)
	assert(translator, "Bad translator")
	assert(LocalizedTextUtils.isLocalizedText(localizedText), "No localizedText")

	return LocalizedTextUtils.formatByKeyRecursive(
		translator,
		localizedText.translationKey,
		localizedText.translationArgs,
		extraArgs)
end

--[=[
	Converts from JSON
	@param text string
	@return LocalizedTextData?
]=]
function LocalizedTextUtils.fromJSON(text)
	assert(type(text) == "string", "Bad text")

	local decoded
	local ok = pcall(function()
		decoded = HttpService:JSONDecode(text)
	end)
	if not ok then
		return nil
	end

	return decoded
end

--[=[
	Converts to JSON
	@param localizedText LocalizedTextData
	@return string?
]=]
function LocalizedTextUtils.toJSON(localizedText)
	assert(LocalizedTextUtils.isLocalizedText(localizedText), "Bad localizedText")

	local localized = HttpService:JSONEncode(localizedText)
	return localized
end

--[=[
	Sets the translation data as an attribute on an instance.
	@param obj Instance
	@param attributeName string
	@param translationKey string
	@param translationArgs TranslationArgs
	@return LocalizedTextData
]=]
function LocalizedTextUtils.setFromAttribute(obj, attributeName, translationKey, translationArgs)
	assert(typeof(obj) == "Instance", "Bad obj")
	assert(type(attributeName) == "string", "Bad attributeName")

	local localizedText = LocalizedTextUtils.create(translationKey, translationArgs)
	obj:SetAttribute(attributeName, LocalizedTextUtils.toJSON(localizedText))
end

--[=[
	Reads the data from the attribute
	@param obj Instance
	@param attributeName string
	@return LocalizedTextData
]=]
function LocalizedTextUtils.getFromAttribute(obj, attributeName)
	assert(typeof(obj) == "Instance", "Bad obj")
	assert(type(attributeName) == "string", "Bad attributeName")

	local value = obj:GetAttribute(attributeName)
	if type(value) == "string" then
		return LocalizedTextUtils.fromJSON(value)
	end

	return nil
end

--[=[
	Gets the translation from a given object's attribute
	@param translator Translator | JSONTranslator
	@param obj Instance
	@param attributeName string
	@param extraArgs table?
	@return string?
]=]
function LocalizedTextUtils.getTranslationFromAttribute(translator, obj, attributeName, extraArgs)
	assert(translator, "Bad translator")
	assert(typeof(obj) == "Instance", "Bad obj")
	assert(type(attributeName) == "string", "Bad attributeName")

	local data = LocalizedTextUtils.getFromAttribute(obj, attributeName)
	if data then
		return LocalizedTextUtils.localizedTextToString(translator, data, extraArgs)
	else
		return nil
	end
end

--[=[
	Ensures an attribute is defined if nothing is there
	@param obj Instance
	@param attributeName string
	@param defaultTranslationKey string
	@param defaultTranslationArgs table?
]=]
function LocalizedTextUtils.initializeAttribute(obj, attributeName, defaultTranslationKey, defaultTranslationArgs)
	assert(typeof(obj) == "Instance", "Bad obj")
	assert(type(attributeName) == "string", "Bad attributeName")
	assert(type(defaultTranslationKey) == "string", "Bad defaultTranslationKey")
	assert(type(defaultTranslationArgs) == "table", "Bad defaultTranslationArgs")

	if LocalizedTextUtils.getFromAttribute(obj, attributeName) then
		return
	end

	LocalizedTextUtils.setFromAttribute(obj, attributeName, defaultTranslationKey, defaultTranslationArgs)
end

--[=[
	Returns the translated string from the given object
	@param translator Translator | JSONTranslator
	@param obj Instance
	@param attributeName string
	@param extraArgs table?
	@return Observable<string?>
]=]
function LocalizedTextUtils.observeTranslation(translator, obj, attributeName, extraArgs)
	assert(translator, "Bad translator")
	assert(typeof(obj) == "Instance", "Bad obj")
	assert(type(attributeName) == "string", "Bad attributeName")

	return RxAttributeUtils.observeAttribute(obj, attributeName, nil)
		:Pipe({
			Rx.switchMap(function(encodedText)
				if type(encodedText) == "string" then
					local localizedText = LocalizedTextUtils.fromJSON(encodedText)
					if localizedText then
						return LocalizedTextUtils.observeFormatByKeyRecursive(
							translator,
							localizedText.translationKey,
							localizedText.translationArgs,
							extraArgs)
					else
						return Rx.of(nil)
					end
				else
					return Rx.of(nil)
				end
			end);
		})
end

return LocalizedTextUtils