--!strict
--[=[
	Owns the lazy per-locale loading state for an instance-decoded [JSONTranslator]
	(a folder of per-locale JSON StringValues / ModuleScripts): which locales are
	available, which have already been loaded, and the accumulated entry lookup.

	Decodes and writes a locale's entries to the [TranslatorService] only the first time
	that locale is needed. The service is resolved from the [ServiceBag] passed to the
	constructor, so callers never have to thread a writer through each load call.

	@class InstanceLocaleLoader
]=]

local require = require(script.Parent.loader).load(script)

local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")
local ResolveLocaleUtils = require("ResolveLocaleUtils")
local ServiceBag = require("ServiceBag")
local TranslatorService = require("TranslatorService")

local InstanceLocaleLoader = {}
InstanceLocaleLoader.ClassName = "InstanceLocaleLoader"
InstanceLocaleLoader.__index = InstanceLocaleLoader

export type InstanceLocaleLoader = typeof(setmetatable(
	{} :: {
		_translatorService: TranslatorService.TranslatorService,
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
	@param serviceBag ServiceBag -- provides the [TranslatorService] writes land on
	@param translatorName string
	@param sourceLocaleId string -- always loaded, the fallback for every key
	@param folder Instance -- holds the per-locale StringValue/ModuleScript children
	@return InstanceLocaleLoader
]=]
function InstanceLocaleLoader.new(
	serviceBag: ServiceBag.ServiceBag,
	translatorName: string,
	sourceLocaleId: string,
	folder: Instance
): InstanceLocaleLoader
	assert(serviceBag, "Bad serviceBag")
	assert(type(translatorName) == "string", "Bad translatorName")
	assert(type(sourceLocaleId) == "string", "Bad sourceLocaleId")
	assert(typeof(folder) == "Instance", "Bad folder")

	local self = setmetatable({}, InstanceLocaleLoader)

	self._translatorService = serviceBag:GetService(TranslatorService) :: any
	self._translatorName = translatorName
	self._sourceLocaleId = sourceLocaleId
	self._folder = folder
	self._lookupTable = {}
	self._loadedLocales = {}
	self._availableLocales = LocalizationEntryParserUtils.getAvailableLocales(folder)

	return self :: any
end

--[=[
	Loads the source locale. Always call this first -- it establishes the Source/Context
	that other locales' values merge onto, and it is the ultimate fallback for every key.
]=]
function InstanceLocaleLoader.LoadSourceLocale(self: InstanceLocaleLoader)
	self:_loadFile(self._sourceLocaleId)
end

--[=[
	Loads every available locale file. Used off the client, where there is no single
	target locale to narrow to.
]=]
function InstanceLocaleLoader.LoadAllLocales(self: InstanceLocaleLoader)
	self:_loadFile(self._sourceLocaleId)
	for fileLocale in self._availableLocales do
		self:_loadFile(fileLocale)
	end
end

--[=[
	Loads every available locale file that shares the target's language (e.g. for "es-mx":
	both `es` and `es-mx`; for "fr-fr": every `fr-*` file), so a regional player gets the
	universal-language strings and same-language siblings as fallbacks before dropping to
	the source. The source locale is ensured first. Idempotent -- a file already loaded is
	never decoded or written again -- and returns nothing, since the caller does not (and
	should not) care which files it touched.

	@param localeId string -- the target locale
]=]
function InstanceLocaleLoader.LoadLocale(self: InstanceLocaleLoader, localeId: string)
	assert(type(localeId) == "string", "Bad localeId")

	-- The source is the base fallback and must be decoded before any other file so their
	-- values merge onto entries with the right Source/Context.
	self:_loadFile(self._sourceLocaleId)

	local languageSubtag = ResolveLocaleUtils.getLanguageSubtag(localeId)
	if not languageSubtag then
		return
	end

	for fileLocale in self._availableLocales do
		if ResolveLocaleUtils.getLanguageSubtag(fileLocale) == languageSubtag then
			self:_loadFile(fileLocale)
		end
	end
end

-- Decodes and writes a single locale file the first time it is seen. Idempotent.
function InstanceLocaleLoader._loadFile(self: InstanceLocaleLoader, fileLocale: string)
	if self._loadedLocales[fileLocale] or not self._availableLocales[fileLocale] then
		return
	end
	self._loadedLocales[fileLocale] = true

	local entries = LocalizationEntryParserUtils.decodeLocaleFromInstance(
		self._translatorName,
		self._sourceLocaleId,
		fileLocale,
		self._folder,
		self._lookupTable
	)

	for _, item in entries do
		local text = item.Values[fileLocale]
		if text ~= nil then
			self._translatorService:SetEntryValue(item.Key, item.Source, item.Context, fileLocale, text)
		end
		-- The example only comes from the source locale.
		if fileLocale == self._sourceLocaleId then
			self._translatorService:SetEntryExample(item.Key, item.Source, item.Context, item.Example)
		end
	end
end

return InstanceLocaleLoader
