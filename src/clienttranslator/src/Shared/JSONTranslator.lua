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
		_localTranslator: ValueObject.ValueObject<any>,
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
	self._localTranslator = self._maid:Add(ValueObject.new(nil))
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

	-- TODO: Maybe don't hold these unless needed
	self._maid:GiveTask(self._translatorService:ObserveLocaleId():Subscribe(function(localeId)
		self._localTranslator.Value = self._localizationTable:GetTranslator(localeId)
	end))
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

	local translationObservable = Rx.combineLatest({
		cloudTranslator = self:ObserveTranslator(),
		translationKey = translationKey,
		translationArgs = self:_observeArgs(translationArgs),
	}):Pipe({
		Rx.switchMap(function(mainState): any
			if mainState.cloudTranslator then
				return self._translatorService:ObserveLocaleId():Pipe({
					Rx.map(function()
						return self:_doTranslation(
							mainState.cloudTranslator,
							mainState.translationKey,
							mainState.translationArgs
						)
					end) :: any,
				})
			end

			-- Fall back to local or source translator
			return Rx.combineLatest({
				localTranslator = self._localTranslator:Observe(),
				sourceTranslator = self._sourceTranslator:Observe(),
			}):Pipe({
				Rx.map(function(state): string?
					if state.localTranslator then
						return self:_doTranslation(
							state.localTranslator,
							mainState.translationKey,
							mainState.translationArgs
						)
					elseif state.sourceTranslator then
						return self:_doTranslation(
							state.sourceTranslator,
							mainState.translationKey,
							mainState.translationArgs
						)
					else
						return nil
					end
				end) :: any,
				Rx.where(function(value)
					return value ~= nil
				end) :: any,
			})
		end) :: any,
	})

	-- Wait for the deferred entry writes to land before translating, so we never read a
	-- key before it has been written.
	return Rx.fromPromise(self._translatorService:PromiseEntriesWritten()):Pipe({
		Rx.switchMap(function(): any
			return translationObservable
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

	-- Wait for the deferred entry writes to land, then for the translator, so we never
	-- read a key before it has been written.
	return self._translatorService
		:PromiseEntriesWritten()
		:Then(function()
			return self:PromiseTranslator()
		end)
		:Then(function(translator)
			return self:_doTranslation(translator, translationKey, args)
		end)
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
	-- forcing the whole deferred batch (and its full table write cost) early.
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
	translator: Translator,
	translationKey: string,
	args
): string
	assert(typeof(translator) == "Instance", "Bad translator")
	assert(type(translationKey) == "string", "Bad translationKey")

	local translation: string
	local ok, err = pcall(function()
		translation = translator:FormatByKey(translationKey, args)
	end)

	if translation then
		return translation
	end

	if err then
		warn(err)
	else
		warn("Failed to localize '" .. translationKey .. "'")
	end

	-- Try the local translator next (not from cloud)
	local localTranslator = self._localTranslator.Value
	if localTranslator then
		ok, err = pcall(function()
			translation = localTranslator:FormatByKey(translationKey, args)
		end)

		if translation then
			return translation
		end
	end

	-- Try the source translator next (we're missing the locale id)
	local sourceTranslator = self._sourceTranslator.Value
	if sourceTranslator then
		ok, err = pcall(function()
			translation = sourceTranslator:FormatByKey(translationKey, args)
		end)
	end

	if ok and not err and translation then
		return translation
	end

	return translationKey
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
