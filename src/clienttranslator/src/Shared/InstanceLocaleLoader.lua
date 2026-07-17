--!strict
--[=[
	Owns the lazy per-locale loading state for an instance-decoded [JSONTranslator]
	(a folder of per-locale JSON StringValues / ModuleScripts): which locales are
	available, which have already been loaded, and the accumulated entry lookup.

	Decodes and writes a locale's entries to the given writer only the first time that
	locale is needed. The writer is anything with `SetEntryValue` and `SetEntryExample`
	(i.e. [TranslatorService]), passed per call so this object never has to hold it.

	@class InstanceLocaleLoader
]=]

local require = require(script.Parent.loader).load(script)

local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")
local ResolveLocaleUtils = require("ResolveLocaleUtils")

local InstanceLocaleLoader = {}
InstanceLocaleLoader.ClassName = "InstanceLocaleLoader"
InstanceLocaleLoader.__index = InstanceLocaleLoader

export type Writer = {
	SetEntryValue: (
		self: any,
		translationKey: string,
		source: string,
		context: string,
		localeId: string,
		text: string
	) -> (),
	SetEntryExample: (self: any, translationKey: string, source: string, context: string, example: string) -> (),
}

export type InstanceLocaleLoader = typeof(setmetatable(
	{} :: {
		_translatorName: string,
		_sourceLocaleId: string,
		_folder: Instance,
		_lookupTable: { [string]: any },
		_loadedLocales: { [string]: true },
		_availableLocales: { [string]: true },
	},
	{} :: typeof({ __index = InstanceLocaleLoader })
))

--[=[
	@param translatorName string
	@param sourceLocaleId string -- always loaded, the fallback for every key
	@param folder Instance -- holds the per-locale StringValue/ModuleScript children
	@return InstanceLocaleLoader
]=]
function InstanceLocaleLoader.new(
	translatorName: string,
	sourceLocaleId: string,
	folder: Instance
): InstanceLocaleLoader
	assert(type(translatorName) == "string", "Bad translatorName")
	assert(type(sourceLocaleId) == "string", "Bad sourceLocaleId")
	assert(typeof(folder) == "Instance", "Bad folder")

	local self = setmetatable({}, InstanceLocaleLoader)

	self._translatorName = translatorName
	self._sourceLocaleId = sourceLocaleId
	self._folder = folder
	self._lookupTable = {}
	self._loadedLocales = {}
	self._availableLocales = LocalizationEntryParserUtils.getAvailableLocales(folder)

	return self :: any
end

--[=[
	The source locale this loader always loads.
	@return string
]=]
function InstanceLocaleLoader.GetSourceLocaleId(self: InstanceLocaleLoader): string
	return self._sourceLocaleId
end

--[=[
	Returns whether the given locale (after resolution) has already been loaded.
	@param localeId string
	@return boolean
]=]
function InstanceLocaleLoader.IsLoaded(self: InstanceLocaleLoader, localeId: string): boolean
	local resolved = ResolveLocaleUtils.resolveClosestKey(localeId, self._availableLocales)
	return resolved ~= nil and self._loadedLocales[resolved] == true
end

--[=[
	Loads the source locale. See [InstanceLocaleLoader.LoadLocale].

	@param writer Writer
	@return string? -- the locale actually loaded, or nil if already loaded
]=]
function InstanceLocaleLoader.LoadSourceLocale(self: InstanceLocaleLoader, writer: Writer): string?
	return self:LoadLocale(self._sourceLocaleId, writer)
end

--[=[
	Loads every available locale (source first). Used off the client where there is no
	single target locale.

	@param writer Writer
]=]
function InstanceLocaleLoader.LoadAllLocales(self: InstanceLocaleLoader, writer: Writer)
	self:LoadLocale(self._sourceLocaleId, writer)
	for localeId in self._availableLocales do
		self:LoadLocale(localeId, writer)
	end
end

--[=[
	Resolves localeId to the closest available file and, the first time it is seen,
	decodes and writes its entries through the writer. Idempotent -- an already-loaded
	locale is never decoded or written again.

	@param localeId string
	@param writer Writer
	@return string? -- the resolved locale that was loaded, or nil if none matched or it was already loaded
]=]
function InstanceLocaleLoader.LoadLocale(self: InstanceLocaleLoader, localeId: string, writer: Writer): string?
	assert(type(localeId) == "string", "Bad localeId")

	local resolved = ResolveLocaleUtils.resolveClosestKey(localeId, self._availableLocales)
	if not resolved or self._loadedLocales[resolved] then
		return nil
	end
	self._loadedLocales[resolved] = true

	local entries = LocalizationEntryParserUtils.decodeLocaleFromInstance(
		self._translatorName,
		self._sourceLocaleId,
		resolved,
		self._folder,
		self._lookupTable
	)

	for _, item in entries do
		local text = item.Values[resolved]
		if text ~= nil then
			writer:SetEntryValue(item.Key, item.Source, item.Context, resolved, text)
		end
		-- The example only comes from the source locale.
		if resolved == self._sourceLocaleId then
			writer:SetEntryExample(item.Key, item.Source, item.Context, item.Example)
		end
	end

	return resolved
end

return InstanceLocaleLoader
