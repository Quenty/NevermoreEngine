--!strict
--[=[
	Owns the lazy per-locale loading state for an instance-decoded [JSONTranslator]
	(a folder of per-locale JSON StringValues / ModuleScripts): which locales are
	available, which have already been loaded, and the accumulated entry lookup.

	Decodes and writes a locale's entries to the [TranslatorService] only the first time
	that locale is needed. Registered as a service by the [JSONTranslator] that owns it.

	The locale files are reached through a [TemplateProvider] rather than off the folder
	directly. On a live server that keeps them from replicating to every client at join --
	a game with a dozen languages otherwise ships all of them to a player who reads one --
	and each file is fetched on demand instead. Off a live server the provider resolves them
	locally and synchronously, so nothing about loading changes there.

	One file per locale. A second file resolving to a locale the provider already knows is
	warned about and ignored, since the provider keys templates by name.

	@class InstanceLocaleLoader
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")
local Maid = require("Maid")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local PseudoLocalize = require("PseudoLocalize")
local ResolveLocaleUtils = require("ResolveLocaleUtils")
local ServiceBag = require("ServiceBag")
local TemplateProvider = require("TemplateProvider")
local TemplateReplicationModes = require("TemplateReplicationModes")
local TemplateReplicationModesUtils = require("TemplateReplicationModesUtils")
local TranslatorService = require("TranslatorService")

-- How long a locale file may go missing before saying so. Matches [TemplateProvider]'s own
-- missing-template warning, which covers the leg after the file's name is known.
local MISSING_FILE_WARNING_TIME = 5

local InstanceLocaleLoader = setmetatable({}, BaseObject)
InstanceLocaleLoader.ClassName = "InstanceLocaleLoader"
InstanceLocaleLoader.__index = InstanceLocaleLoader

export type InstanceLocaleLoader = typeof(setmetatable(
	{} :: {
		ServiceName: string,
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_translatorService: TranslatorService.TranslatorService,
		_templateProvider: TemplateProvider.TemplateProvider,
		_translatorName: string,
		_sourceLocaleId: string,
		_folder: Instance,
		_lookupTable: { [string]: any },
		_loadedLocales: { [string]: true },
		_requestedLocales: { [string]: true },
		_availableFiles: { [string]: number },
		_tombstonedFiles: { [string]: true },
		_hasWarnedUnhidden: boolean,
		_pendingFileNamePromises: { [string]: Promise.Promise<string> },
		_pendingFilePromises: { [string]: Promise.Promise<()> },
	},
	{} :: typeof({ __index = InstanceLocaleLoader })
))

--[=[
	Constructs a new [InstanceLocaleLoader]. Register it on the [ServiceBag] that provides
	the [TranslatorService] its writes land on -- it pulls in a [TemplateProvider] of its
	own, so the standard initialization chain has to reach it.

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

	local self: InstanceLocaleLoader = setmetatable({} :: any, InstanceLocaleLoader)

	self.ServiceName = translatorName .. "LocaleLoader"
	self._translatorName = translatorName
	self._sourceLocaleId = sourceLocaleId
	self._folder = folder

	return self
end

--[=[
	Initializes the loader. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function InstanceLocaleLoader.Init(self: InstanceLocaleLoader, serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._lookupTable = {}
	self._loadedLocales = {}
	self._requestedLocales = {}
	self._availableFiles = {}
	self._tombstonedFiles = {}
	self._hasWarnedUnhidden = false
	self._pendingFileNamePromises = {}
	self._pendingFilePromises = {}

	self._translatorService = serviceBag:GetService(TranslatorService) :: any

	-- One provider per translator: it is named for this translator, so its Remoting channel
	-- lines up across realms without colliding with any other translator's files.
	self._templateProvider =
		serviceBag:GetService(TemplateProvider.new(self._translatorName .. "Locales", self._folder) :: any) :: any

	self:_trackAvailableFiles()
end

--[=[
	Loads the source locale. Always call this first -- it establishes the Source/Context
	that other locales' values merge onto, and it is the ultimate fallback for every key.
]=]
function InstanceLocaleLoader.LoadSourceLocale(self: InstanceLocaleLoader)
	self:PromiseSourceLocale()
end

--[=[
	Resolves once the source locale's file has been fetched, decoded, and queued onto the
	[TranslatorService]. This is what makes a synchronous read
	([JSONTranslator.FormatByKey]) safe: on a live client the file arrives over the network,
	so there is a window at boot where the fallback for every key is simply not here yet.

	@return Promise<()>
]=]
function InstanceLocaleLoader.PromiseSourceLocale(self: InstanceLocaleLoader): Promise.Promise<()>
	return self:_promiseFile(self._sourceLocaleId)
end

--[=[
	Loads every available locale file. Used off the client, where there is no single
	target locale to narrow to.
]=]
function InstanceLocaleLoader.LoadAllLocales(self: InstanceLocaleLoader)
	self:PromiseAllLocales()
end

--[=[
	See [InstanceLocaleLoader.LoadAllLocales]. Resolves once every locale known at the time
	of the call has landed.

	@return Promise<()>
]=]
function InstanceLocaleLoader.PromiseAllLocales(self: InstanceLocaleLoader): Promise.Promise<()>
	local promises = { self:PromiseSourceLocale() }

	for fileLocale in self:_getAvailableLocales() do
		table.insert(promises, self:_promiseFile(fileLocale))
	end

	return PromiseUtils.all(promises) :: any
end

--[=[
	Loads every available locale file that shares the target's language (e.g. for "es-mx":
	both `es` and `es-mx`; for "fr-fr": every `fr-*` file), so a regional player gets the
	universal-language strings and same-language siblings as fallbacks before dropping to
	the source. The source locale is ensured first. Idempotent -- a file already loaded is
	never fetched, decoded, or written again -- and returns nothing, since the caller does
	not (and should not) care which files it touched.

	@param localeId string -- the target locale
]=]
function InstanceLocaleLoader.LoadLocale(self: InstanceLocaleLoader, localeId: string)
	self:PromiseLoadLocale(localeId)
end

--[=[
	See [InstanceLocaleLoader.LoadLocale]. Resolves once the files known to match the target
	at the time of the call have landed. Files that replicate in later are still loaded --
	the request is remembered -- but this promise does not wait for them, since there is no
	point at which the set is known to be complete.

	@param localeId string
	@return Promise<()>
]=]
function InstanceLocaleLoader.PromiseLoadLocale(self: InstanceLocaleLoader, localeId: string): Promise.Promise<()>
	assert(type(localeId) == "string", "Bad localeId")

	local promises = { self:PromiseSourceLocale() }

	local languageSubtag = ResolveLocaleUtils.getLanguageSubtag(localeId)
	if not languageSubtag then
		return PromiseUtils.all(promises) :: any
	end

	self._requestedLocales[localeId] = true

	for fileLocale in self:_getAvailableLocales() do
		if ResolveLocaleUtils.getLanguageSubtag(fileLocale) == languageSubtag then
			table.insert(promises, self:_promiseFile(fileLocale))
		end
	end

	return PromiseUtils.all(promises) :: any
end

-- Mirrors the provider's known file names. Both lists are watched because a file is in the
-- replicated list, the unreplicated (tombstoned) list, or -- once a client has fetched it --
-- both at once, hence the refcount rather than a set.
function InstanceLocaleLoader._trackAvailableFiles(self: InstanceLocaleLoader)
	local function track(observeNamesBrio, isTombstoned: boolean)
		self._maid:GiveTask(observeNamesBrio:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, fileName = brio:ToMaidAndValue()

			if isTombstoned then
				self._tombstonedFiles[fileName] = true
			else
				self:_warnIfReplicatedAtJoin(fileName)
			end

			local count = (self._availableFiles[fileName] or 0) + 1
			self._availableFiles[fileName] = count
			if count == 1 then
				self:_onFileAvailable(fileName)
			end

			maid:GiveTask(function()
				local remaining = (self._availableFiles[fileName] or 0) - 1
				if remaining > 0 then
					self._availableFiles[fileName] = remaining
				else
					self._availableFiles[fileName] = nil
				end
			end)
		end))
	end

	track(self._templateProvider:ObserveTemplateNamesBrio(), false)
	track(self._templateProvider:ObserveUnreplicatedTemplateNamesBrio(), true)
end

-- A client that can see a locale file outright, having never seen a tombstone for it, is a
-- client the server never hid it from -- so the whole language set replicated at join and
-- this loader is saving nothing. Everything still works, which is exactly why this is worth
-- saying out loud: the usual cause is a translator registered on the client bag only, and
-- nothing else about the game looks wrong.
function InstanceLocaleLoader._warnIfReplicatedAtJoin(self: InstanceLocaleLoader, fileName: string)
	if self._hasWarnedUnhidden or self._tombstonedFiles[fileName] then
		return
	end

	if TemplateReplicationModesUtils.inferReplicationMode() ~= TemplateReplicationModes.CLIENT then
		return
	end

	self._hasWarnedUnhidden = true

	warn(
		string.format(
			"[InstanceLocaleLoader.%s] - Locale file %q replicated at join instead of being fetched. "
				.. "Register this translator on the server's ServiceBag too, so the server can hide the "
				.. "locale files and serve them on demand.",
			self._translatorName,
			fileName
		)
	)
end

function InstanceLocaleLoader._onFileAvailable(self: InstanceLocaleLoader, fileName: string)
	local fileLocale = LocalizationEntryParserUtils.parseLocaleFromName(fileName)

	local existingFileName = self:_getFileNameForLocale(fileLocale)
	if existingFileName and existingFileName ~= fileName then
		-- The provider keys templates by name, so only one of these can ever be fetched.
		-- Loud, because the other file's strings would otherwise go missing with no error.
		warn(
			string.format(
				"[InstanceLocaleLoader.%s] - Locale %q has more than one file (%q and %q). Only %q will be loaded.",
				self._translatorName,
				fileLocale,
				existingFileName,
				fileName,
				existingFileName
			)
		)
		return
	end

	local pendingFileName = self._pendingFileNamePromises[fileLocale]
	if pendingFileName then
		pendingFileName:Resolve(fileName)
	end

	-- A file can appear after a locale was asked for -- tombstones replicate to a client
	-- over time -- so a request that matched nothing when it was made is reconsidered here
	-- rather than left to whatever happens to ask again.
	local languageSubtag = ResolveLocaleUtils.getLanguageSubtag(fileLocale)
	for requestedLocaleId in self._requestedLocales do
		if ResolveLocaleUtils.getLanguageSubtag(requestedLocaleId) == languageSubtag then
			self:_promiseFile(fileLocale)
			break
		end
	end
end

function InstanceLocaleLoader._getFileNameForLocale(self: InstanceLocaleLoader, fileLocale: string): string?
	for fileName in self._availableFiles do
		if LocalizationEntryParserUtils.parseLocaleFromName(fileName) == fileLocale then
			return fileName
		end
	end

	return nil
end

function InstanceLocaleLoader._getAvailableLocales(self: InstanceLocaleLoader): { [string]: true }
	local locales: { [string]: true } = {}

	for fileName in self._availableFiles do
		locales[LocalizationEntryParserUtils.parseLocaleFromName(fileName)] = true
	end

	return locales
end

-- Resolves with the name of the file holding a locale, waiting for it to show up if the
-- provider does not know it yet. A client learns which locales exist as the tombstones
-- replicate, so "no file for this locale" and "not yet" are the same observation at boot,
-- and treating them as the former would silently skip the file when it did arrive.
function InstanceLocaleLoader._promiseFileName(self: InstanceLocaleLoader, fileLocale: string): Promise.Promise<string>
	local existing = self._pendingFileNamePromises[fileLocale]
	if existing then
		return existing
	end

	local promise: Promise.Promise<string> = Promise.new()
	self._pendingFileNamePromises[fileLocale] = promise
	self._maid[promise] = promise

	local found = self:_getFileNameForLocale(fileLocale)
	if found then
		promise:Resolve(found)
		return promise
	end

	self._maid:GiveTask(task.delay(MISSING_FILE_WARNING_TIME, function()
		if promise:IsPending() then
			warn(string.format("[InstanceLocaleLoader.%s] - No locale file for %q", self._translatorName, fileLocale))
		end
	end))

	return promise
end

-- Fetches, decodes, and writes a single locale file the first time it is asked for.
-- Idempotent -- repeat calls neither refetch nor rewrite.
function InstanceLocaleLoader._promiseFile(self: InstanceLocaleLoader, fileLocale: string): Promise.Promise<()>
	local existing = self._pendingFilePromises[fileLocale]
	if existing then
		return existing
	end

	local promiseTemplate
	if fileLocale == self._sourceLocaleId then
		promiseTemplate = self:_promiseFileName(fileLocale):Then(function(fileName)
			return self._templateProvider:PromiseTemplate(fileName)
		end)
	else
		-- Chained behind the source rather than raced with it. The source establishes the
		-- Source/Context every other locale's values merge onto, and once fetching is
		-- asynchronous the order files arrive in has nothing to do with the order they were
		-- asked for. Only the decode is ordered -- the fetches still overlap.
		promiseTemplate = self:PromiseSourceLocale()
			:Then(function()
				return self:_promiseFileName(fileLocale)
			end)
			:Then(function(fileName)
				return self._templateProvider:PromiseTemplate(fileName)
			end)
	end

	local promise = promiseTemplate:Then(function()
		self:_writeLocale(fileLocale)
	end)

	self._maid[promise] = promise
	self._pendingFilePromises[fileLocale] = promise

	return promise
end

-- Decodes the locale out of the folder and queues its entries. The decode reads the folder
-- rather than the fetched instance because a locale can be spread over nested files, and
-- because a client parents what it fetched back under the folder -- so by the time this
-- runs, the folder holds the file either way.
function InstanceLocaleLoader._writeLocale(self: InstanceLocaleLoader, fileLocale: string)
	-- The maid cancels the promise this runs from, but not the [TemplateProvider] fetch it
	-- chains off, so a file that lands after teardown still arrives here. Writing then would
	-- queue entries the flush will never come for.
	if not self.Destroy then
		return
	end

	if self._loadedLocales[fileLocale] then
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

	local pseudoLocaleId = PseudoLocalize.getDefaultPseudoLocaleId()

	for _, item in entries do
		local text = item.Values[fileLocale]
		if text ~= nil then
			self._translatorService:SetEntryValue(item.Key, item.Source, item.Context, fileLocale, text)
		end

		-- The example and the pseudo-localized value both come from the source locale only --
		-- the parser derives the latter from the source text, in Studio, and no other file's
		-- decode produces one.
		if fileLocale == self._sourceLocaleId then
			self._translatorService:SetEntryExample(item.Key, item.Source, item.Context, item.Example)

			-- Queued here because nothing else does it: a key a locale file already registered
			-- is not re-registered by [JSONTranslator.ToTranslationKey] when it first appears on
			-- screen, so the pseudo value it used to backfill would never reach the table and
			-- the forced pseudo locale would fall back to the source language in Studio.
			local pseudoText = item.Values[pseudoLocaleId]
			if pseudoText ~= nil then
				self._translatorService:SetEntryValue(item.Key, item.Source, item.Context, pseudoLocaleId, pseudoText)
			end
		end
	end
end

return InstanceLocaleLoader
