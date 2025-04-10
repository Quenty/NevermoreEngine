--!strict
--[=[
	Handles selecting the right locale/translator for Studio, and Roblox games.

	@class TranslatorService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalizationService = game:GetService("LocalizationService")

local LocalizationServiceUtils = require("LocalizationServiceUtils")
local Maid = require("Maid")
local Promise = require("Promise")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ValueObject = require("ValueObject")
local _Observable = require("Observable")
local _ServiceBag = require("ServiceBag")

local TranslatorService = {}
TranslatorService.ServiceName = "TranslatorService"

export type TranslatorService = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_serviceBag: _ServiceBag.ServiceBag,
		_translator: ValueObject.ValueObject<Translator>,
		_localizationTable: LocalizationTable?,
		_pendingTranslatorPromise: Promise.Promise<Translator>?,
		_localeIdValue: ValueObject.ValueObject<string>?,
		_loadedPlayerObservable: _Observable.Observable<Player>?,
		_loadedPlayer: Player?,
	},
	{} :: typeof({ __index = TranslatorService })
))

function TranslatorService.Init(self: TranslatorService, serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._translator = self._maid:Add(ValueObject.new(nil))
	self._translator:Mount(self:_observeTranslatorImpl())
end

function TranslatorService.GetLocalizationTable(self: TranslatorService): LocalizationTable
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

function TranslatorService._getLocalizationTableName(_self: TranslatorService): string
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
function TranslatorService.ObserveTranslator(self: TranslatorService): _Observable.Observable<Translator>
	return self._translator:Observe()
end

--[=[
	Promises the Roblox translator

	@return Observable<Translator>
]=]
function TranslatorService.PromiseTranslator(self: TranslatorService): Promise.Promise<Translator>
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

	maid:GiveTask(self._translator:Observe():Subscribe(function(translator: Translator)
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
function TranslatorService.GetTranslator(self: TranslatorService): Translator?
	return self._translator.Value
end

--[=[
	Observes the current locale id for this translator.

	@return Observable<string>
]=]
function TranslatorService.ObserveLocaleId(self: TranslatorService): _Observable.Observable<string>
	if self._localeIdValue then
		return self._localeIdValue:Observe()
	end

	local valueObject = self._maid:Add(ValueObject.new("en-us", "string"))

	valueObject:Mount(self._translator:Observe():Pipe({
		Rx.switchMap(function(translator: Translator): any
			if translator then
				return RxInstanceUtils.observeProperty(translator, "LocaleId")
			else
				-- Fallback
				return self:_observeLoadedPlayer():Pipe({
					Rx.switchMap(function(player: Player)
						if player then
							return RxInstanceUtils.observeProperty(player, "LocaleId")
						else
							return RxInstanceUtils.observeProperty(LocalizationService, "RobloxLocaleId")
						end
					end) :: any,
				})
			end
		end) :: any,
		Rx.distinct() :: any,
	}) :: any)
	self._localeIdValue = valueObject
	return valueObject:Observe()
end

--[=[
	Gets the localeId to use

	@return string
]=]
function TranslatorService.GetLocaleId(self: TranslatorService): string
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

function TranslatorService._observeTranslatorImpl(self: TranslatorService): _Observable.Observable<Translator>
	return self:_observeLoadedPlayer():Pipe({
		Rx.switchMap(function(loadedPlayer: Player): any
			if loadedPlayer then
				return Rx.fromPromise(LocalizationServiceUtils.promisePlayerTranslator(loadedPlayer))
			end

			return RxInstanceUtils.observeProperty(LocalizationService, "RobloxLocaleId"):Pipe({
				Rx.switchMap(function(localeId: string): any
					-- This can actually take a while (20-30 seconds)
					return Rx.fromPromise(LocalizationServiceUtils.promiseTranslatorForLocale(localeId))
				end) :: any,
			})
		end) :: any,
	}) :: any
end

function TranslatorService._observeLoadedPlayer(self: TranslatorService): _Observable.Observable<Player>
	if self._loadedPlayerObservable then
		return self._loadedPlayerObservable
	end

	local observable: any = RxInstanceUtils.observeProperty(Players, "LocalPlayer"):Pipe({
		Rx.switchMap(function(player: Player): any
			if not player then
				return Rx.of(nil)
			end

			return RxInstanceUtils.observeProperty(player, "LocaleId"):Pipe({
				Rx.map(function(localeId): Player?
					if localeId == "" then
						return nil
					else
						return player
					end
				end) :: any,
			})
		end) :: any,
		Rx.distinct() :: any,
		Rx.cache() :: any,
	})
	self._loadedPlayerObservable = observable

	return observable
end

function TranslatorService.Destroy(self: TranslatorService)
	self._maid:DoCleaning()
end

return TranslatorService