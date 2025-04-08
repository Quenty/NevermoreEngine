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
local LocalizationEntryParserUtils = require("LocalizationEntryParserUtils")
local Maid = require("Maid")
local PseudoLocalize = require("PseudoLocalize")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local TranslationKeyUtils = require("TranslationKeyUtils")
local TranslatorService = require("TranslatorService")
local ValueObject = require("ValueObject")
local NumberLocalizationUtils = require("NumberLocalizationUtils")
local _ServiceBag = require("ServiceBag")
local _Observable = require("Observable")
local _Promise = require("Promise")

local JSONTranslator = {}
JSONTranslator.ClassName = "JSONTranslator"
JSONTranslator.ServiceName = "JSONTranslator"
JSONTranslator.__index = JSONTranslator

export type JSONTranslator = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_serviceBag: _ServiceBag.ServiceBag,
		_translatorService: TranslatorService.TranslatorService,
		_translatorName: string,
		_entries: { [string]: any },
		_localizationTable: any,
		_localTranslator: ValueObject.ValueObject<any>,
		_sourceTranslator: ValueObject.ValueObject<any>,
	},
	{} :: typeof({ __index = JSONTranslator })
))

--[=[
	Constructs a new JSONTranslator from the given args.

	```
	local translator = JSONTranslator.new("MyTranslator", en", {
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
	end)
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
		self._entries = LocalizationEntryParserUtils.decodeFromTable(self._translatorName, localeId, dataTable)
	elseif typeof(localeId) == "Instance" then
		local parent = localeId
		local sourceLocaleId = "en"
		self._entries = LocalizationEntryParserUtils.decodeFromInstance(self._translatorName, sourceLocaleId, parent)
	else
		error("Must pass a localeId and dataTable")
	end

	return self :: any
end

function JSONTranslator.Init(self: JSONTranslator, serviceBag: _ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._translatorService = self._serviceBag:GetService(TranslatorService) :: any

	self._maid = Maid.new()
	self._localTranslator = self._maid:Add(ValueObject.new(nil))
	self._sourceTranslator = self._maid:Add(ValueObject.new(nil))

	self._localizationTable = self._translatorService:GetLocalizationTable()

	for _, item in self._entries do
		for localeId, text in item.Values do
			self._localizationTable:SetEntryValue(item.Key, item.Source, item.Context, localeId, text)
		end
		self._localizationTable:SetEntryExample(item.Key, item.Source, item.Context, item.Example)
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

function JSONTranslator.ObserveNumber(self: JSONTranslator, number: number): _Observable.Observable<string>
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
): _Observable.Observable<string>
	assert((self :: any) ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	return Rx.combineLatest({
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

	-- Always waits for full translator to be loaded since we only get one shot
	return self:PromiseTranslator():Then(function(translator)
		return self:_doTranslation(translator, translationKey, args)
	end)
end

--[=[
	Returns a promise that will resolve once the Roblox translator is loaded from the cloud.
	@return Promise<Translator>
]=]
function JSONTranslator.PromiseTranslator(self: JSONTranslator): _Promise.Promise<Translator>
	return self._translatorService:PromiseTranslator()
end

--[=[
	Observes the current Roblox translator for this translator.

	@return Observable<Translator>
]=]
function JSONTranslator.ObserveTranslator(self: JSONTranslator): _Observable.Observable<Translator>
	return self._translatorService:ObserveTranslator()
end

--[=[
	Observes the current locale id for this translator.

	@return Observable<string>
]=]
function JSONTranslator.ObserveLocaleId(self: JSONTranslator): _Observable.Observable<string>
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

	self._localizationTable:SetEntryValue(translationKey, source, context, localeId, text or source)

	if RunService:IsStudio() then
		self._localizationTable:SetEntryValue(
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
): _Observable.Observable<string>
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
function JSONTranslator.PromiseLoaded(self: JSONTranslator): _Promise.Promise<()>
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

	local translator = self._translatorService:GetTranslator()
	if not translator then
		error("Translator is not yet acquired yet")
	end

	return self:_doTranslation(translator, translationKey, args)
end

function JSONTranslator._observeArgs(_self: JSONTranslator, translationArgs): _Observable.Observable<any>
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