--- Gets local translator for player
-- @module ClientTranslator

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local JsonToLocalizationTable = require("JsonToLocalizationTable")
local PseudoLocalize = require("PseudoLocalize")
local Promise = require("Promise")

local ClientTranslatorFacade = {}

--- Initializes a new instance of the ClientTranslatorFacade
--  Must be called before usage
function ClientTranslatorFacade:Init()
	local localizationTable = JsonToLocalizationTable.loadFolder(ReplicatedStorage:WaitForChild("i18n"))
	localizationTable.Name = "JSONTranslationTable"
	localizationTable.Parent = LocalizationService

	if RunService:IsStudio() then
		PseudoLocalize.addToLocalizationTable(localizationTable, "qlp-pls", "en")
	end

	self._englishTranslator = localizationTable:GetTranslator("en")

	local asyncTranslatorPromise = Promise.spawn(function(resolve, reject)
		local translator = nil
		local ok, err = pcall(function()
			translator = LocalizationService:GetTranslatorForPlayerAsync(Players.LocalPlayer)
		end)

		if not ok then
			reject(err or "Failed to GetTranslatorForPlayerAsync")
			return
		end

		if translator then
			assert(typeof(translator) == "Instance")
			resolve(translator)
			return
		end

		reject("Translator was not returned")
		return
	end)

	-- Give longer in non-studio mode
	local timeout = 20
	if RunService:IsStudio() then
		timeout = 0.5
	end

	delay(timeout, function()
		if not asyncTranslatorPromise:IsPending() then
			return
		end
		asyncTranslatorPromise:Reject(
			("GetTranslatorForPlayerAsync is still pending after %f, using local table")
			:format(timeout))
	end)

	local finalPromise = asyncTranslatorPromise:Catch(function(err)
		warn(("[ERR][ClientTranslatorFacade] - %s"):format(tostring(err)))
		local translator = LocalizationService:GetTranslatorForPlayer(Players.LocalPlayer)
		return translator
	end)

	self._clientTranslator = finalPromise:Wait()
	assert(typeof(self._clientTranslator) == "Instance")

	return self
end

--- @{inheritDoc}
function ClientTranslatorFacade:FormatByKey(key, ...)
	assert(type(key) == "string", "Key must be a string")

	if not RunService:IsRunning() then
		return self:_formatByKeyTestMode(key, ...)
	end

	assert(self._clientTranslator, "ClientTranslator is not initialized")

	local data = {...}
	local result
	local ok, err = pcall(function()
		result = self._clientTranslator:FormatByKey(key, unpack(data))
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
	if self._clientTranslator.LocaleId ~= self._englishTranslator.LocaleId then
		-- Ignore results as we know this may error
		ok, err = pcall(function()
			result = self._englishTranslator:FormatByKey(key, unpack(data))
		end)

		if ok and not err then
			return result
		end
	end

	return key
end

function ClientTranslatorFacade:_formatByKeyTestMode(key, ...)
	local i18n = ReplicatedStorage:FindFirstChild("i18n")
	if not i18n then
		return key
	end

	local data = {...}

	local localizationTable
	if self._localizationTable then
		-- Cache localizaiton table, because it can take 10-20ms to load.
		localizationTable = self._localizationTable
	else
		localizationTable = JsonToLocalizationTable.loadFolder(i18n)
		self._localizationTable = localizationTable
	end

	-- Can't read LocalizationService.ForcePlayModeRobloxLocaleId :(
	local translator = localizationTable:GetTranslator("en")
	local result
	local ok, err = pcall(function()
		result = translator:FormatByKey(key, unpack(data))
	end)

	if ok and not err then
		return result
	end

	if err then
		warn(err)
	else
		warn("Failed to localize '" .. key .. "'")
	end

	return key
end

return ClientTranslatorFacade
