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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Blend = require("Blend")
local JsonToLocalizationTable = require("JsonToLocalizationTable")
local LocalizationServiceUtils = require("LocalizationServiceUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local PseudoLocalize = require("PseudoLocalize")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local TranslationKeyUtils = require("TranslationKeyUtils")

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
	@param ... any
	@return JSONTranslator
]=]
function JSONTranslator.new(translatorName, ...)
	local self = setmetatable({}, JSONTranslator)

	assert(type(translatorName) == "string", "Bad translatorName")
	self.ServiceName = translatorName

	-- Cache localizaiton table, because it can take 10-20ms to load.
	self._localizationTable = JsonToLocalizationTable.toLocalizationTable(translatorName, ...)
	self._englishTranslator = self._localizationTable:GetTranslator("en")
	self._fallbacks = {}

	if RunService:IsRunning() and RunService:IsClient() then
		self._promiseTranslator = LocalizationServiceUtils.promiseTranslator(Players.LocalPlayer)
	else
		self._promiseTranslator = Promise.resolved(self._englishTranslator)
	end

	if RunService:IsStudio() then
		PseudoLocalize.addToLocalizationTable(self._localizationTable, nil, "en")
	end

	return self
end

function JSONTranslator:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

--[=[
	Observes the current locale id for this translator.

	@return Observable<string>
]=]
function JSONTranslator:ObserveLocaleId()
	return Rx.fromPromise(self._promiseTranslator):Pipe({
		Rx.switchMap(function(translator)
			return RxInstanceUtils.observeProperty(translator, "LocaleId")
		end)
	})
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
		self._localizationTable:SetEntryValue(translationKey, source, context,
			PseudoLocalize.getDefaultPseudoLocaleId(),
			PseudoLocalize.pseudoLocalize(text))
	end
end

function JSONTranslator:ObserveTranslation(prefix, text, argData)
	assert(type(prefix) == "string", "Bad text")
	assert(type(text) == "string", "Bad text")

	return self:ObserveFormatByKey(self:ToTranslationKey(prefix, text), argData)
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
	if self._promiseTranslator:IsFulfilled() then
		local translator = self._promiseTranslator:Wait()
		return translator.LocaleId
	else
		warn("[JSONTranslator.GetLocaleId] - Translator is not loaded yet, returning english")
		return "en"
	end
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
	return self._promiseTranslator
end

--[=[
	Makes the translator fall back to another translator if an entry cannot be found.

	Mostly just used for testing.

	@param translator JSONTranslator | Translator
]=]
function JSONTranslator:FallbackTo(translator)
	assert(translator, "Bad translator")
	assert(translator.FormatByKey, "Bad translator")

	table.insert(self._fallbacks, translator)
end

--[=[
	Formats the resulting entry by args.

	:::tip
	You should use [JSONTranslator.ObserveFormatByKey] instead of this to respond
	to locale changing.
	:::

	@param key string
	@param args table?
	@return Promise<string>
]=]
function JSONTranslator:PromiseFormatByKey(key, args)
	assert(self ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(key) == "string", "Key must be a string")

	return self._promiseTranslator:Then(function()
		return self:FormatByKey(key, args)
	end)
end

--[=[
	Observes the translated value
	@param key string
	@param argData table? -- May have observables (or convertable to observables) in it.
	@return Observable<string>
]=]
function JSONTranslator:ObserveFormatByKey(key, argData)
	assert(self ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(key) == "string", "Key must be a string")

	local argObservable
	if argData then
		local args = {}
		for argKey, value in pairs(argData) do
			args[argKey] = Blend.toPropertyObservable(value) or Rx.of(value)
		end

		argObservable = Rx.combineLatest(args)
	else
		argObservable = nil
	end

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GivePromise(self._promiseTranslator):Then(function(translator)
			if argObservable then
				maid:GiveTask(Rx.combineLatest({
					localeId = RxInstanceUtils.observeProperty(translator, "LocaleId");
					args = argObservable;
				}):Subscribe(function(state)
					sub:Fire(self:FormatByKey(key, state.args))
				end))
			else
				maid:GiveTask(RxInstanceUtils.observeProperty(translator, "LocaleId"):Subscribe(function()
					sub:Fire(self:FormatByKey(key, nil))
				end))
			end
		end)

		return maid
	end)
end

--[=[
	Formats or errors if the cloud translations are not loaded.

	:::tip
	You should use [JSONTranslator.ObserveFormatByKey] instead of this to respond
	to locale changing.
	:::

	@param key string
	@param args table?
	@return string
]=]
function JSONTranslator:FormatByKey(key, args)
	assert(self ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(key) == "string", "Key must be a string")

	if not RunService:IsRunning() then
		return self:_formatByKeyTestMode(key, args)
	end

	local clientTranslator = self:_getClientTranslatorOrError()

	local result
	local ok, err = pcall(function()
		result = clientTranslator:FormatByKey(key, args)
	end)

	if ok and not err then
		return result
	end

	if err then
		warn(err)
	else
		warn("Failed to localize '" .. key .. "'")
	end

	-- Fallback to English
	if clientTranslator.LocaleId ~= self._englishTranslator.LocaleId then
		-- Ignore results as we know this may error
		ok, err = pcall(function()
			result = self._englishTranslator:FormatByKey(key, args)
		end)

		if ok and not err then
			return result
		end
	end

	return key
end

function JSONTranslator:_getClientTranslatorOrError()
	assert(self._promiseTranslator, "ClientTranslator is not initialized")

	if self._promiseTranslator:IsFulfilled() then
		return assert(self._promiseTranslator:Wait(), "Failed to get translator")
	else
		error("Translator is not yet acquired yet")
		return nil
	end
end

function JSONTranslator:_formatByKeyTestMode(key, args)
	-- Can't read LocalizationService.ForcePlayModeRobloxLocaleId :(
	local translator = self._localizationTable:GetTranslator("en")
	local result
	local ok, err = pcall(function()
		result = translator:FormatByKey(key, args)
	end)

	if ok and not err then
		return result
	end

	for _, fallback in pairs(self._fallbacks) do
		local value = fallback:FormatByKey(key, args)
		if value then
			return value
		end
	end

	if err then
		warn(err)
	else
		warn("[JSONTranslator._formatByKeyTestMode] - Failed to localize '" .. key .. "'")
	end

	return key
end

--[=[
	Cleans up the translator and deletes the localization table if it exists.
]=]
function JSONTranslator:Destroy()
	self._localizationTable:Destroy()
	self._localizationTable = nil
	self._englishTranslator = nil
	self._promiseTranslator = nil

	setmetatable(self, nil)
end

return JSONTranslator