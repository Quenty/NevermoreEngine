--!strict
--[=[
	Utility function that loads a translator from a folder or a table.

	To get translations uploaded.

	1. Run the game
	2. On the client, check LocalizationService.GeneratedJSONTable
	3. Right click > Save as CSV
	4. Stop the game
	5. In Studio, go to plugins > "Localization Tools"
	6. Upload the CSV (update)

	@class JSONTranslator
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local InstanceLocaleLoader = require("InstanceLocaleLoader")
local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")
local Maid = require("Maid")
local NumberLocalizationUtils = require("NumberLocalizationUtils")
local Observable = require("Observable")
local Promise = require("Promise")
local PseudoLocalize = require("PseudoLocalize")
local ResolveLocaleUtils = require("ResolveLocaleUtils")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")
local TableLocaleLoader = require("TableLocaleLoader")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")
local TranslationKeyUtils = require("TranslationKeyUtils")
local TranslatorService = require("TranslatorService")
local ValueObject = require("ValueObject")

local JSONTranslator = {}
JSONTranslator.ClassName = "JSONTranslator"
JSONTranslator.ServiceName = "JSONTranslator"
JSONTranslator.__index = JSONTranslator

-- The common surface of [TableLocaleLoader] and [InstanceLocaleLoader]. Both queue
-- localization entries onto the [TranslatorService] they were constructed with; the
-- instance loader defers per locale.
type LocaleLoader = {
	LoadSourceLocale: (self: any) -> (),
	LoadLocale: (self: any, localeId: string) -> (),
	LoadAllLocales: (self: any) -> (),
}

export type JSONTranslator = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_serviceBag: ServiceBag.ServiceBag,
		_translatorService: TranslatorService.TranslatorService,
		_tieRealmService: TieRealmService.TieRealmService,
		_translatorName: string,
		_createLoader: (serviceBag: ServiceBag.ServiceBag) -> LocaleLoader,
		_loader: LocaleLoader,
		_localizationTable: any,
		_localTranslators: { [string]: any },
		_sourceTranslator: ValueObject.ValueObject<any>,
	},
	{} :: typeof({ __index = JSONTranslator })
))

--[=[
	Constructs a new JSONTranslator from the given args.

	```lua
	local translator = JSONTranslator.new("MyTranslator", "en", {
		actions = {
			respawn = "Respawn {playerName}";
		};
	})

	print(translator:FormatByKey("actions.respawn"), { playerName = "Quenty"}) --> Respawn Quenty

	-- Observing is preferred
	maid:GiveTask(translator:ObserveFormatByKey("actions.respawn", {
		playerName = RxInstanceUtils.observeProperty(player, "DisplayName");
	}):Subscribe(function(text)
		print(text) --> "Respawn Quenty"
	end))
	```

	```lua
	local translator = JSONTranslator.new(script)
	-- assume there is an `en.json` underneath the script with valid JSON.
	```

	@param translatorName string -- Name of the translator. Used for source.
	@param localeId string
	@param dataTable table
	@return JSONTranslator
]=]
function JSONTranslator.new(translatorName: string, localeId: string, dataTable): JSONTranslator
	assert(type(translatorName) == "string", "Bad translatorName")

	local self = setmetatable({}, JSONTranslator)

	self._translatorName = translatorName
	self.ServiceName = translatorName

	if type(localeId) == "string" and type(dataTable) == "table" then
		-- Table-driven data is already in memory; decode it now. The loader needs the service
		-- bag, so defer its construction to Init via a callback.
		local entries = LocalizationEntryParserUtils.decodeFromTable(self._translatorName, localeId, dataTable)
		self._createLoader = function(serviceBag)
			return TableLocaleLoader.new(serviceBag, entries) :: any
		end
	elseif typeof(localeId) == "Instance" then
		-- Instance-driven translators (per-locale JSON StringValues / ModuleScripts) defer
		-- decoding to the loader; it too is built in Init once the bag is available.
		local folder = localeId
		self._createLoader = function(serviceBag)
			return InstanceLocaleLoader.new(serviceBag, self._translatorName, "en", folder) :: any
		end
	else
		error("Must pass a localeId and dataTable")
	end

	return self :: any
end

function JSONTranslator.Init(self: JSONTranslator, serviceBag: ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._translatorService = self._serviceBag:GetService(TranslatorService) :: any
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._maid = Maid.new()
	self._localTranslators = {}
	self._sourceTranslator = self._maid:Add(ValueObject.new(nil))

	self._localizationTable = self._translatorService:GetLocalizationTable()

	-- The loader resolves the TranslatorService from the bag and writes to it directly.
	self._loader = self._createLoader(self._serviceBag)

	if self._tieRealmService:GetTieRealm() == TieRealms.CLIENT then
		-- On the client, load the source locale now (the fallback) and each target
		-- locale's data as the locale is swapped to.
		self._loader:LoadSourceLocale()
		self._maid:GiveTask(self._translatorService:ObserveLocaleId():Subscribe(function(localeId)
			self._loader:LoadLocale(localeId)
		end))
	else
		-- Off the client there is no player locale to key off, so load everything.
		self._loader:LoadAllLocales()
	end

	self._maid:GiveTask(
		RxInstanceUtils.observeProperty(self._localizationTable, "SourceLocaleId"):Subscribe(function(localeId)
			self._sourceTranslator.Value = self._localizationTable:GetTranslator(localeId)
		end)
	)
end

function JSONTranslator.ObserveNumber(self: JSONTranslator, number: number): Observable.Observable<string>
	return Rx.combineLatest({
		localeId = self:ObserveLocaleId(),
		number = number,
	}):Pipe({
		Rx.map(function(state)
			return NumberLocalizationUtils.localize(state.number, state.localeId)
		end) :: any,
	}) :: any
end

function JSONTranslator.ObserveAbbreviatedNumber(
	self: JSONTranslator,
	number: number,
	roundingBehaviourType,
	numSignificantDigits: number?
)
	return Rx.combineLatest({
		localeId = self:ObserveLocaleId(),
		roundingBehaviourType = roundingBehaviourType,
		numSignificantDigits = numSignificantDigits,
		number = number,
	}):Pipe({
		Rx.map(function(state)
			return NumberLocalizationUtils.abbreviate(
				state.number,
				state.localeId,
				state.roundingBehaviourType,
				state.numSignificantDigits
			)
		end) :: any,
	})
end

--[=[
	Observes the translated value
	@param translationKey string
	@param translationArgs table? -- May have observables (or convertable to observables) in it.
	@return Observable<string>
]=]
function JSONTranslator.ObserveFormatByKey(
	self: JSONTranslator,
	translationKey: string,
	translationArgs
): Observable.Observable<string>
	assert((self :: any) ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	-- Flat, so every source is subscribed exactly once for the life of the subscription. The
	-- trigger carries a latch that suppresses a not-ready state after its first emission, and
	-- it is a cold observable: nesting it under a switchMap would resubscribe it -- and reset
	-- that latch -- every time an arg emitted, letting a locale swap flicker good text back to
	-- the source language mid-swap.
	--
	-- The local translator is deliberately absent though _doTranslation reads it: it swaps at
	-- the start of a locale change, before that locale's data has landed, so re-emitting on it
	-- would publish a source-language fallback over a good translation until the flush.
	return Rx.combineLatest({
		cloudTranslator = self:ObserveTranslator(),
		sourceTranslator = self._sourceTranslator:Observe(),
		readyLocaleId = self:_observeTranslationTrigger(translationKey),
		translationArgs = self:_observeArgs(translationArgs),
	}):Pipe({
		Rx.map(function(state): string
			return self:_doTranslation(
				state.cloudTranslator,
				translationKey,
				state.translationArgs,
				state.readyLocaleId
			)
		end) :: any,
	}) :: any
end

--[=[
	Formats the resulting entry by args.

	:::tip
	You should use [JSONTranslator.ObserveFormatByKey] instead of this to respond
	to locale changing.
	:::

	@param translationKey string
	@param args table?
	@return Promise<string>
]=]
function JSONTranslator.PromiseFormatByKey(self: JSONTranslator, translationKey: string, args)
	assert((self :: any) ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	-- Wait for this key's queued writes to land, then for the translator, so we never read a
	-- key before it has been written. Only this key is waited on -- the rest of the batch
	-- stays queued for the normal end-of-frame flush.
	return Rx.toPromise(self:_observeTranslationReady(translationKey):Pipe({
		Rx.where(function(readyLocaleId)
			return readyLocaleId ~= nil
		end) :: any,
	}) :: any)
		:Then(function()
			return self:PromiseTranslator()
		end)
		:Then(function(translator)
			return self:_doTranslation(translator, translationKey, args)
		end)
end

--[=[
	Observes when a translation key is readable for the current locale, emitting the locale
	id it is readable for, or nil while its data is still queued.

	:::warning
	This is an implementation detail, exposed for the translation stack itself and for
	diagnostics. You should not need it: every way of reading a translation
	([JSONTranslator.ObserveFormatByKey], [JSONTranslator.PromiseFormatByKey],
	[JSONTranslator.FormatByKey], [JSONTranslator.ObserveTranslation]) already waits for the
	key it reads, and re-reads when a locale swap brings new data in.
	:::

	Localization writes are batched to the end of the frame (see
	[TranslatorService.SetEntryValue]), because a game streaming in can register thousands of
	entries in a single frame and each raw table write invalidates every AutoLocalize entry
	in the engine. That means a key is not readable the instant it is registered, and this is
	how the read paths above find out that it is.

	Re-emits whenever the locale changes or new data lands for the key, so a locale swap is
	picked up without resubscribing. Nothing here yields.

	@param translationKey string
	@return Observable<string?>
]=]
function JSONTranslator._observeTranslationReady(
	self: JSONTranslator,
	translationKey: string
): Observable.Observable<string?>
	assert((self :: any) ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	return self._translatorService:ObserveLocaleId():Pipe({
		Rx.switchMap(function(localeId: string): any
			-- Queue the locale's file here rather than trusting the subscription in Init to
			-- have run first. Loading is idempotent and only queues -- it never writes the
			-- table -- so readiness is accurate whatever order subscribers run in. Guarded on
			-- liveness because a consumer's subscription can outlive this translator, and a
			-- destroyed one must not keep queueing writes on every locale change.
			if self.Destroy then
				self._loader:LoadLocale(localeId)
			end

			return self._translatorService:ObserveIsTranslationReady(translationKey):Pipe({
				Rx.map(function(isReady: boolean): string?
					return if isReady then localeId else nil
				end) :: any,
			})
		end) :: any,
		-- Queuing the new locale's file above happens while the outgoing locale's readiness
		-- is still subscribed, so a swap reports not-ready once for each locale. This is a
		-- state, not a pulse: collapse the repeat.
		Rx.distinct() :: any,
	}) :: any
end

-- Drives re-translation. Emits once on subscribe whatever the readiness state, so a reader
-- always has something to paint instead of waiting a frame on the batch, and thereafter only
-- when the key is ready: a locale swap must not flicker a good translation back to a
-- fallback while the new locale's data is still queued.
function JSONTranslator._observeTranslationTrigger(
	self: JSONTranslator,
	translationKey: string
): Observable.Observable<string?>
	return Observable.new(function(sub)
		local maid = Maid.new()
		local hasFired = false

		maid:GiveTask(self:_observeTranslationReady(translationKey):Subscribe(function(readyLocaleId: string?)
			-- Readiness belongs to the TranslatorService, which outlives this translator (the
			-- service bag tears services down in reverse init order), so a consumer's
			-- subscription can still be fed after Destroy has stripped the metatable.
			if not self.Destroy then
				return
			end

			if readyLocaleId ~= nil or not hasFired then
				hasFired = true
				sub:Fire(readyLocaleId)
			end
		end))

		return maid
	end) :: any
end

--[=[
	Returns a promise that will resolve once the Roblox translator is loaded from the cloud.
	@return Promise<Translator>
]=]
function JSONTranslator.PromiseTranslator(self: JSONTranslator): Promise.Promise<Translator>
	return self._translatorService:PromiseTranslator()
end

--[=[
	Observes the current Roblox translator for this translator.

	@return Observable<Translator>
]=]
function JSONTranslator.ObserveTranslator(self: JSONTranslator): Observable.Observable<Translator>
	return self._translatorService:ObserveTranslator()
end

--[=[
	Observes the current locale id for this translator.

	@return Observable<string>
]=]
function JSONTranslator.ObserveLocaleId(self: JSONTranslator): Observable.Observable<string>
	return self._translatorService:ObserveLocaleId()
end

--[=[
	Adds an entry value to the localization table itself. This can be useful
	for ensuring pseudo localization and/or generating localization values
	from the game data itself.

	@param translationKey string
	@param source string
	@param context string
	@param localeId string
	@param text string
]=]
function JSONTranslator.SetEntryValue(
	self: JSONTranslator,
	translationKey: string,
	source: string,
	context: string,
	localeId: string,
	text: string
)
	assert(type(translationKey) == "string", "Bad translationKey")
	assert(type(source) == "string", "Bad source")
	assert(type(context) == "string", "Bad context")
	assert(type(localeId) == "string", "Bad localeId")
	assert(type(text) == "string", "Bad text")

	self._translatorService:SetEntryValue(translationKey, source, context, localeId, text or source)

	if RunService:IsStudio() then
		self._translatorService:SetEntryValue(
			translationKey,
			source,
			context,
			PseudoLocalize.getDefaultPseudoLocaleId(),
			PseudoLocalize.pseudoLocalize(text)
		)
	end
end

--[=[
	Observes a translation key and formats it with the given args.

	@param prefix string
	@param text string
	@param translationArgs table?
	@return Observable<string>
]=]
function JSONTranslator.ObserveTranslation(
	self: JSONTranslator,
	prefix: string,
	text: string,
	translationArgs
): Observable.Observable<string>
	assert(type(prefix) == "string", "Bad text")
	assert(type(text) == "string", "Bad text")

	return self:ObserveFormatByKey(self:ToTranslationKey(prefix, text), translationArgs)
end

--[=[
	Converts the given prefix and text into a translation key.

	@param prefix string
	@param text string
	@return string
]=]
function JSONTranslator.ToTranslationKey(self: JSONTranslator, prefix: string, text: string): string
	assert(type(prefix) == "string", "Bad text")
	assert(type(text) == "string", "Bad text")

	local translationKey = TranslationKeyUtils.getTranslationKey(prefix, text)
	local context = string.format("automatic.%s", translationKey)

	-- TODO: Only set if we don't need it
	self:SetEntryValue(translationKey, text, context, "en", text)

	return translationKey
end

--[=[
	Gets the current localeId of the translator if it's initialized, or a default if it is not.

	@return string
]=]
function JSONTranslator.GetLocaleId(self: JSONTranslator): string
	return self._translatorService:GetLocaleId()
end

--[=[
	Gets the localization table the translation is using.

	@return LocalizationTable
]=]
function JSONTranslator.GetLocalizationTable(self: JSONTranslator): LocalizationTable
	return self._localizationTable
end

--[=[
	Returns a promise that will resolve once the translator is loaded from the cloud.
	@return Promise
]=]
function JSONTranslator.PromiseLoaded(self: JSONTranslator): Promise.Promise<()>
	return self:PromiseTranslator()
end

--[=[
	Formats or errors if the cloud translations are not loaded.

	:::tip
	You should use [JSONTranslator.ObserveFormatByKey] instead of this to respond
	to locale changing.
	:::

	@param translationKey string
	@param args table?
	@return string
]=]
function JSONTranslator.FormatByKey(self: JSONTranslator, translationKey: string, args): string
	assert((self :: any) ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	-- Synchronous read: land just this key's queued writes before reading, rather than
	-- forcing the whole deferred batch (and its full table write cost) early. The current
	-- locale is queued first, since a synchronous read cannot wait on the subscription in
	-- Init to have queued it.
	self._loader:LoadLocale(self._translatorService:GetLocaleId())
	self._translatorService:FlushEntryForKey(translationKey)

	local translator = self._translatorService:GetTranslator()
	if not translator then
		error("Translator is not yet acquired yet")
	end

	return self:_doTranslation(translator, translationKey, args)
end

function JSONTranslator._observeArgs(_self: JSONTranslator, translationArgs): Observable.Observable<any>
	if translationArgs == nil then
		return Rx.of(nil)
	end

	local args = {}
	for argKey, value in translationArgs do
		args[argKey] = Blend.toPropertyObservable(value) or Rx.of(value)
	end

	return Rx.combineLatest(args)
end

function JSONTranslator._doTranslation(
	self: JSONTranslator,
	translator: Translator?,
	translationKey: string,
	args,
	localeId: string?
): string
	assert(type(translationKey) == "string", "Bad translationKey")

	local targetLocaleId = localeId or self._translatorService:GetLocaleId()

	-- A translator answers in the language it was built for, so one built for another
	-- language returns fluent text in the wrong language instead of failing. The cloud
	-- translator is bound to the player's Roblox locale, which a forced locale (a language
	-- selector) does not move, so it is only consulted when the languages agree.
	-- The source translator is exempt: answering in another language is its whole job.
	local translation = self:_tryTranslate(translator, translationKey, args, targetLocaleId)
		or self:_tryTranslate(self:_getLocalTranslator(targetLocaleId), translationKey, args, targetLocaleId)
		or self:_tryTranslate(self._sourceTranslator.Value, translationKey, args, nil)

	if translation then
		return translation
	end

	-- Only a key no translator could resolve is worth reporting. A miss on any single
	-- translator is routine -- the cloud translator does not know keys registered at runtime,
	-- and a key whose writes are still queued is not readable yet by design -- so warning per
	-- miss floods the console with one line per key per locale swap.
	if self._translatorService:IsTranslationReadyForLocale(translationKey, targetLocaleId) then
		-- The locale is the actionable half: the key usually exists, just not for this one.
		warn(
			string.format("[JSONTranslator] - Failed to localize '%s' for locale '%s'", translationKey, targetLocaleId)
		)
	end

	return translationKey
end

-- The local table's translator for a locale, cached per locale. Resolved from the locale
-- being translated for rather than held in a ValueObject updated by a locale subscription:
-- signal handlers fire newest-connected first, so such a subscription can still hold the
-- previous locale's translator while a reader is translating for the new one. A translator
-- reflects entries written after it was obtained, so caching one per locale is safe.
function JSONTranslator._getLocalTranslator(self: JSONTranslator, localeId: string): Translator?
	local found = self._localTranslators[localeId]
	if found then
		return found
	end

	local translator = self._localizationTable:GetTranslator(localeId)
	self._localTranslators[localeId] = translator
	return translator
end

-- Translates through one translator, returning nil when it cannot answer: it is absent, it
-- is built for another language than requiredLocaleId (nil to accept any), or it does not
-- have the key. Roblox raises rather than returning nil for a missing key, hence the pcall.
function JSONTranslator._tryTranslate(
	_self: JSONTranslator,
	translator: Translator?,
	translationKey: string,
	args,
	requiredLocaleId: string?
): string?
	if not translator then
		return nil
	end

	if requiredLocaleId and not ResolveLocaleUtils.isCompatibleLocale(requiredLocaleId, translator.LocaleId) then
		return nil
	end

	local translation: string?

	local ok = pcall(function()
		translation = (translator :: any):FormatByKey(translationKey, args)
	end)
	if not ok then
		return nil
	end

	return translation
end

--[=[
	Cleans up the translator and deletes the localization table if it exists.
	Should be called by [ServiceBag]
]=]
function JSONTranslator.Destroy(self: JSONTranslator)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return JSONTranslator
