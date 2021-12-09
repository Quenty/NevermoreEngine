---
-- @classmod JSONTranslator
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local JsonToLocalizationTable = require("JsonToLocalizationTable")
local PseudoLocalize = require("PseudoLocalize")
local LocalizationServiceUtils = require("LocalizationServiceUtils")
local Promise = require("Promise")

local JSONTranslator = {}
JSONTranslator.ClassName = "JSONTranslator"
JSONTranslator.__index = JSONTranslator

function JSONTranslator.new(...)
	local self = setmetatable({}, JSONTranslator)

	-- Cache localizaiton table, because it can take 10-20ms to load.
	self._localizationTable = JsonToLocalizationTable.toLocalizationTable(...)
	self._englishTranslator = self._localizationTable:GetTranslator("en")
	self._fallbacks = {}

	if RunService:IsRunning() then
		self._localizationTable.Parent = LocalizationService
		self._promiseTranslator = LocalizationServiceUtils.promiseTranslator(Players.LocalPlayer)
	else
		self._promiseTranslator = Promise.resolved(self._englishTranslator)
	end

	if RunService:IsStudio() then
		PseudoLocalize.addToLocalizationTable(self._localizationTable, nil, "en")
	end

	return self
end

function JSONTranslator:PromiseLoaded()
	return self._promiseTranslator
end

--- Mostly just used for testing,
function JSONTranslator:FallbackTo(translator)
	assert(translator, "Bad translator")
	assert(translator.FormatByKey, "Bad translator")

	table.insert(self._fallbacks, translator)
end

function JSONTranslator:PromiseFormatByKey(key, args)
	assert(self ~= JSONTranslator, "Construct a new version of this class to use it")
	assert(type(key) == "string", "Key must be a string")

	return self._promiseTranslator:Then(function()
		return self:FormatByKey(key, args)
	end)
end

--- Blocking format until the cloud translations are loaded.
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

function JSONTranslator:Destroy()
	self._localizationTable:Destroy()
	self._localizationTable = nil
	self._englishTranslator = nil
	self._promiseTranslator = nil

	setmetatable(self, nil)
end

return JSONTranslator