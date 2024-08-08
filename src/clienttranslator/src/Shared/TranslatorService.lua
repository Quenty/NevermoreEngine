--[=[
	Handles selecting the right locale/translator for Studio, and Roblox games.

	@class TranslatorService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalizationService = game:GetService("LocalizationService")

local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")
local LocalizationServiceUtils = require("LocalizationServiceUtils")
local ValueObject = require("ValueObject")
local Maid = require("Maid")
local Promise = require("Promise")

local TranslatorService = {}
TranslatorService.ServiceName = "TranslatorService"

function TranslatorService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._translator = self._maid:Add(ValueObject.new(nil))
	self._translator:Mount(self:_observeTranslatorImpl())
end

function TranslatorService:GetLocalizationTable()
	if self._localizationTable then
		return self._localizationTable
	end

	local localizationTableName = self:_getLocalizationTableName()
	local localizationTable = LocalizationService:FindFirstChild(localizationTableName)

	if not localizationTable then
		localizationTable = Instance.new("LocalizationTable")
		localizationTable.Name = localizationTableName
		localizationTable.Parent = LocalizationService
	end

	self._localizationTable = localizationTable
	return localizationTable
end

function TranslatorService:_getLocalizationTableName()
	if RunService:IsServer() then
		return "GeneratedJSONTable_Server"
	else
		return "GeneratedJSONTable_Client"
	end
end

--[=[
	Observes Roblox translator

	@return Observable<Translator>
]=]
function TranslatorService:ObserveTranslator()
	return self._translator:Observe()
end

--[=[
	Promises the Roblox translator

	@return Observable<Translator>
]=]
function TranslatorService:PromiseTranslator()
	local found = self._translator.Value
	if found then
		return Promise.resolved(found)
	end

	if self._pendingTranslatorPromise then
		return self._pendingTranslatorPromise
	end

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

	self._maid._pendingTranslatorMaid = maid
	self._pendingTranslatorPromise = promise

	maid:GiveTask(function()
		if self._maid._pendingTranslatorMaid == maid then
			self._maid._pendingTranslatorMaid = nil
		end

		if self._pendingTranslatorPromise == promise then
			self._pendingTranslatorPromise = nil
		end
	end)

	maid:GiveTask(self._translator:Observe():Subscribe(function(translator)
		if translator then
			promise:Resolve(translator)
		end
	end))

	return promise
end

--[=[
	Gets the current translator to use

	@return Translator?
]=]
function TranslatorService:GetTranslator()
	return self._translator.Value
end

--[=[
	Observes the current locale id for this translator.

	@return Observable<string>
]=]
function TranslatorService:ObserveLocaleId()
	return self._translator:Observe():Pipe({
		Rx.switchMap(function(translator)
			if translator then
				return RxInstanceUtils.observeProperty(translator, "LocaleId")
			else
				-- Fallback
				return self:_observeLoadedPlayer():Pipe({
					Rx.switchMap(function(player)
						if player then
							return RxInstanceUtils.observeProperty(player, "LocaleId")
						else
							return RxInstanceUtils.observeProperty(LocalizationService, "RobloxLocaleId")
						end
					end)
				})
			end
		end);
		Rx.distinct();
	})
end

--[=[
	Gets the localeId to use

	@return string
]=]
function TranslatorService:GetLocaleId()
	local found = self._translator.Value
	if found then
		return found.LocaleId
	end

	-- Fallback
	local player = Players.LocalPlayer
	if player and player.LocaleId ~= "" then
		return player.LocaleId
	else
		return LocalizationService.RobloxLocaleId
	end
end

function TranslatorService:_observeTranslatorImpl()
	return self:_observeLoadedPlayer():Pipe({
		Rx.switchMap(function(loadedPlayer)
			if loadedPlayer then
				return Rx.fromPromise(LocalizationServiceUtils.promisePlayerTranslator(loadedPlayer))
			end

			return RxInstanceUtils.observeProperty(LocalizationService, "RobloxLocaleId"):Pipe({
				Rx.switchMap(function(localeId)
					-- This can actually take a while (20-30 seconds)
					return Rx.fromPromise(LocalizationServiceUtils.promiseTranslatorForLocale(localeId))
				end)
			})
		end);
	})
end

function TranslatorService:_observeLoadedPlayer()
	if self._loadedPlayerObservable then
		return self._loadedPlayerObservable
	end

	self._loadedPlayerObservable = RxInstanceUtils.observeProperty(Players, "LocalPlayer"):Pipe({
		Rx.switchMap(function(player)
			if not player then
				return Rx.of(nil)
			end

			return RxInstanceUtils.observeProperty(player, "LocaleId"):Pipe({
				Rx.map(function(localeId)
					if localeId == "" then
						return nil
					else
						return player
					end
				end);
			})
		end);
		Rx.distinct();
		Rx.cache();
	})

	return self._loadedPlayerObservable
end

function TranslatorService:Destroy()
	self._maid:DoCleaning()
end

return TranslatorService