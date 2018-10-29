--- Gets local translator for player
-- @module ClientTranslator

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local JsonToLocalizationTable = require("JsonToLocalizationTable")
local PseudoLocalize = require("PseudoLocalize")

assert(RunService:IsClient(), "ClientTranslator can only be required on client")

local ClientTranslatorFacade = {}
ClientTranslatorFacade.__index = ClientTranslatorFacade
ClientTranslatorFacade.ClassName = "ClientTranslatorFacade"

--- Initializes a new instance of the ClientTranslatorFacade
function ClientTranslatorFacade.new()
	local self = setmetatable({}, ClientTranslatorFacade)

	local localizationTable = JsonToLocalizationTable.loadFolder(ReplicatedStorage:WaitForChild("i18n"))
	localizationTable.Name = "JSONTranslationTable"
	localizationTable.Parent = LocalizationService

	if RunService:IsStudio() then
		PseudoLocalize.addToLocalizationTable(localizationTable, "qlp-pls")
	end

	self._clientTranslator = LocalizationService:GetTranslatorForPlayer(Players.LocalPlayer)

	return self
end

--- @{inheritDoc}
function ClientTranslatorFacade:FormatByKey(key, ...)
	assert(type(key) == "string", "Key must be a string")
	local data = {...}
	local result
	local ok, err = pcall(function()
		result = self._clientTranslator:FormatByKey(key, unpack(data))
	end)

	if not ok then
		if err then
			warn(err)
		else
			warn("Failed to localize '" .. key .. "'")
		end

		return key
	end

	return result
end

return ClientTranslatorFacade.new()