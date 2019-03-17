--- Gets local translator for player
-- @module ClientTranslator

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local JsonToLocalizationTable = require("JsonToLocalizationTable")
local PseudoLocalize = require("PseudoLocalize")
local Promise = require("Promise")

assert(RunService:IsClient(), "ClientTranslator can only be required on client")

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
	assert(self._clientTranslator, "ClientTranslator is not initialized")
	assert(type(key) == "string", "Key must be a string")
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

return ClientTranslatorFacade