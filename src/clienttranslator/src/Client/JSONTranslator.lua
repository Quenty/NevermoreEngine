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

local JsonToLocalizationTable = require("JsonToLocalizationTable")
local PseudoLocalize = require("PseudoLocalize")
local LocalizationServiceUtils = require("LocalizationServiceUtils")
local Promise = require("Promise")
local Observable = require("Observable")
local Maid = require("Maid")
local Blend = require("Blend")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

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

	if RunService:IsRunning() then
		self._promiseTranslator = LocalizationServiceUtils.promiseTranslator(Players.LocalPlayer)
	else
		self._promiseTranslator = Promise.resolved(self._englishTranslator)
	end

	if RunService:IsStudio() then
		PseudoLocalize.addToLocalizationTable(self._localizationTable, nil, "en")
	end

	return self
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
	Gets the current localeId of the translator if it's initialized, or a default if it is not.

	@return string
]=]
function JSONTranslator:GetLocaleId()
	if self._promiseTranslator:IsFulfilled() then
		local translator = self._promiseTranslator:Wait()
		return translator.LocaleId
	else
		warn("[JSONTranslator] - Translator is not loaded yet, returning english")
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

		maid:GivePromise(self._promiseTranslator:Then(function()
			if argObservable then
				maid:GiveTask(argObservable:Subscribe(function(args)
					sub:Fire(self:FormatByKey(key, args))
				end))
			else
				sub:Fire(self:FormatByKey(key, nil))
			end
		end))

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
		warn("Failed to localize '" .. key .. "'")
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