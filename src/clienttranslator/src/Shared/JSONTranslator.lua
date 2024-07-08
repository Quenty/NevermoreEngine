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

local JSONTranslator = {}
JSONTranslator.ClassName = "JSONTranslator"
JSONTranslator.ServiceName = "JSONTranslator"
JSONTranslator.__index = JSONTranslator

--[=[
	Constructs a new JSONTranslator from the given args.

	```lua
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
function JSONTranslator.new(translatorName, localeId, dataTable)
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

	return self
end

function JSONTranslator:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._translatorService = self._serviceBag:GetService(TranslatorService)

	self._maid = Maid.new()
	self._localTranslator = self._maid:Add(ValueObject.new(nil))
	self._sourceTranslator = self._maid:Add(ValueObject.new(nil))

	self._localizationTable = self._translatorService:GetLocalizationTable()

	for _, item in pairs(self._entries) do
		for localeId, text in pairs(item.Values) do
			self._localizationTable:SetEntryValue(item.Key, item.Source, item.Context, localeId, text)
		end
		self._localizationTable:SetEntryExample(item.Key, item.Source, item.Context, item.Example)
	end

	self._maid:GiveTask(RxInstanceUtils.observeProperty(self._localizationTable, "SourceLocaleId"):Subscribe(function(localeId)
		self._sourceTranslator.Value = self._localizationTable:GetTranslator(localeId)
	end))
	self._maid:GiveTask(self._translatorService:ObserveLocaleId():Subscribe(function(localeId)
		self._localTranslator.Value = self._localizationTable:GetTranslator(localeId)
	end))
end

--[=[
	Observes the translated value
	@param translationKey string
	@param translationArgs table? -- May have observables (or convertable to observables) in it.
	@return Observable<string>
]=]
function JSONTranslator:ObserveFormatByKey(translationKey, translationArgs)
	assert(self ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	return Rx.combineLatest({
		translator = self:ObserveTranslator();
		translationKey = translationKey;
		translationArgs = self:_observeArgs(translationArgs);
	}):Pipe({
		Rx.switchMap(function(mainState)
			if mainState.translator then
				return Rx.of(self:_doTranslation(mainState.translator, mainState.translationKey, mainState.translationArgs))
			end

			-- Fall back to local or source translator
			return Rx.combineLatest({
				localTranslator = self._localTranslator:Observe();
				sourceTranslator = self._sourceTranslator:Observe();
			}):Pipe({
				Rx.map(function(state)
					if state.localTranslator then
						return self:_doTranslation(state.localTranslator, mainState.translationKey, mainState.translationArgs)
					elseif state.sourceTranslator then
						return self:_doTranslation(state.sourceTranslator, mainState.translationKey, mainState.translationArgs)
					else
						return nil
					end
				end);
				Rx.where(function(value)
					return value ~= nil
				end);
			})
		end)
	})
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
function JSONTranslator:PromiseFormatByKey(translationKey, args)
	assert(self ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	-- Always waits for full translator to be loaded since we only get one shot
	return self:PromiseTranslator():Then(function(translator)
		return self:_doTranslation(translator, translationKey, args)
	end)
end

function JSONTranslator:PromiseTranslator()
	return self._translatorService:PromiseTranslator()
end

function JSONTranslator:ObserveTranslator()
	return self._translatorService:ObserveTranslator()
end

--[=[
	Observes the current locale id for this translator.

	@return Observable<string>
]=]
function JSONTranslator:ObserveLocaleId()
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
function JSONTranslator:SetEntryValue(translationKey, source, context, localeId, text)
	assert(type(translationKey) == "string", "Bad translationKey")
	assert(type(source) == "string", "Bad source")
	assert(type(context) == "string", "Bad context")
	assert(type(localeId) == "string", "Bad localeId")
	assert(type(text) == "string", "Bad text")

	self._localizationTable:SetEntryValue(translationKey, source, context, localeId, text or source)

	if RunService:IsStudio() then
		self._localizationTable:SetEntryValue(translationKey, source, context, PseudoLocalize.getDefaultPseudoLocaleId(), PseudoLocalize.pseudoLocalize(text))
	end
end

function JSONTranslator:ObserveTranslation(prefix, text, translationArgs)
	assert(type(prefix) == "string", "Bad text")
	assert(type(text) == "string", "Bad text")

	return self:ObserveFormatByKey(self:ToTranslationKey(prefix, text), translationArgs)
end

function JSONTranslator:ToTranslationKey(prefix, text)
	assert(type(prefix) == "string", "Bad text")
	assert(type(text) == "string", "Bad text")

	local translationKey = TranslationKeyUtils.getTranslationKey(prefix, text)
	local context = ("automatic.%s"):format(translationKey)

	-- TODO: Only set if we don't need it
	self:SetEntryValue(translationKey, text, context, "en", text)

	return translationKey
end

--[=[
	Gets the current localeId of the translator if it's initialized, or a default if it is not.

	@return string
]=]
function JSONTranslator:GetLocaleId()
	return self._translatorService:GetLocaleId()
end

--[=[
	Gets the localization table the translation is using.

	@return LocalizaitonTable
]=]
function JSONTranslator:GetLocalizationTable()
	return self._localizationTable
end

--[=[
	Returns a promise that will resolve once the translator is loaded from the cloud.
	@return Promise
]=]
function JSONTranslator:PromiseLoaded()
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
function JSONTranslator:FormatByKey(translationKey, args)
	assert(self ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(translationKey) == "string", "Key must be a string")

	local translator = self._translatorService:GetTranslator()
	if not translator then
		error("Translator is not yet acquired yet")
	end

	return self:_doTranslation(translator, translationKey, args)
end

function JSONTranslator:_observeArgs(translationArgs)
	if translationArgs == nil then
		return Rx.of(nil)
	end

	local args = {}
	for argKey, value in pairs(translationArgs) do
		args[argKey] = Blend.toPropertyObservable(value) or Rx.of(value)
	end

	return Rx.combineLatest(args)
end

function JSONTranslator:_doTranslation(translator, translationKey, args)
	assert(typeof(translator) == "Instance", "Bad translator")
	assert(type(translationKey) == "string", "Bad translationKey")

	local translation
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

	if ok and not err then
		return translation
	end

	return translationKey
end

--[=[
	Cleans up the translator and deletes the localization table if it exists.
	Should be called by [ServiceBag]
]=]
function JSONTranslator:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return JSONTranslator