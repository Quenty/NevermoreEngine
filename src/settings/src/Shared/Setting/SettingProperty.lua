--!strict
--[=[
	@class SettingProperty
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local Rx = require("Rx")
local RxSignal = require("RxSignal")
local ServiceBag = require("ServiceBag")
local SettingsDataService = require("SettingsDataService")

local SettingProperty = {}
SettingProperty.ClassName = "SettingProperty"
SettingProperty.__index = SettingProperty

export type SettingProperty<T> = typeof(setmetatable(
	{} :: {
		Value: T,
		Changed: any,
		DefaultValue: T,

		_serviceBag: ServiceBag.ServiceBag,
		_bridge: SettingsDataService.SettingsDataService,
		_player: Player?,
		_definition: any,
	},
	{} :: typeof({ __index = SettingProperty })
))

--[=[
	Constructs a new SettingProperty.

	A nil player means the local player: the real `Players.LocalPlayer`, or the mock a test has
	already designated through [PlayerMock.setMockedLocalPlayer]. Designation may happen before
	bags boot -- matching production, where `Players.LocalPlayer` exists before any service runs --
	so construction requires a resolvable local player up front.

	@param serviceBag ServiceBag
	@param player Player?
	@param definition SettingDefinition
	@return SettingProperty<T>
]=]
function SettingProperty.new<T>(serviceBag: ServiceBag.ServiceBag, player: Player?, definition): SettingProperty<T>
	local self: SettingProperty<T> = setmetatable({} :: any, SettingProperty)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._bridge = self._serviceBag:GetService(SettingsDataService) :: any

	assert(player ~= nil or Players.LocalPlayer ~= nil or PlayerMock.getMockedLocalPlayer() ~= nil, "No player")
	if player ~= nil then
		self._player = player
	end
	self._definition = assert(definition, "No definition")

	if self:_findPlayer() ~= nil then
		self:_promisePlayerSettings():Then(function(playerSettings)
			playerSettings:EnsureInitialized(self._definition:GetSettingName(), self._definition:GetDefaultValue())
		end)
	end

	return self
end

--[=[
	Observes the value of the setting property
	@return Observable<T>
]=]
function SettingProperty.Observe<T>(self: SettingProperty<T>): Observable.Observable<T>
	return self:_observePlayerSettings():Pipe({
		Rx.where(function(settings)
			return settings ~= nil
		end),
		Rx.take(1),
		Rx.switchMap(function()
			-- Ensure we're loaded first and then register for real.
			return self:_observePlayerSettings()
		end) :: any,
		Rx.switchMap(function(playerSettings): any
			if not playerSettings then
				-- Don't emit until we have a value
				return Rx.of(self._definition:GetDefaultValue())
			else
				return playerSettings:ObserveValue(
					self._definition:GetSettingName(),
					self._definition:GetDefaultValue()
				)
			end
		end) :: any,
	}) :: any
end

(SettingProperty :: any).__index = function(self, index): any
	if index == "Value" then
		local settings = self:_getPlayerSettings()
		if settings then
			return settings:GetValue(self._definition:GetSettingName(), self._definition:GetDefaultValue())
		else
			return self._definition:GetDefaultValue()
		end
	elseif index == "Changed" then
		return RxSignal.new(self:Observe():Pipe({
			-- TODO: Handle scenario where we're loading and .Value changes because of what
			-- we queried.
			Rx.skip(1),
		}))
	elseif index == "DefaultValue" then
		return self._definition:GetDefaultValue()
	elseif SettingProperty[index] then
		return SettingProperty[index]
	else
		error(
			string.format(
				"%q is not a member of SettingProperty %s",
				tostring(index),
				self._definition:GetSettingName()
			)
		)
	end
end

function SettingProperty.__newindex<T>(self, index, value)
	if index == "Value" then
		self:SetValue(value)
	elseif index == "DefaultValue" or index == "Changed" or SettingProperty[index] then
		error(string.format("Cannot set %q", tostring(index)))
	else
		rawset(self, index, value)
	end
end

--[=[
	Sets the value of the setting property. Will warn if it cannot do so.

	:::tip
	Use [PromiseSetValue] to ensure value is set.
	:::

	@param value T
]=]
function SettingProperty.SetValue<T>(self: SettingProperty<T>, value: T): ()
	local settings = self:_getPlayerSettings()
	if settings then
		settings:SetValue(self._definition:GetSettingName(), value)
	else
		warn(
			"[SettingProperty.SetValue] - Cannot set setting value. Use :PromiseSetValue() to ensure value is set after load."
		)
	end
end

--[=[
	Promises the value of the setting once it's loaded.

	@return Promise<T>
]=]
function SettingProperty.PromiseValue<T>(self: SettingProperty<T>): Promise.Promise<T>
	return self:_promisePlayerSettings():Then(function(playerSettings)
		return playerSettings:GetValue(self._definition:GetSettingName(), self._definition:GetDefaultValue())
	end)
end

--[=[
	Promises to set the value

	@param value T
	@return Promise
]=]
function SettingProperty.PromiseSetValue<T>(self: SettingProperty<T>, value: T): Promise.Promise<()>
	return self:_promisePlayerSettings():Then(function(playerSettings)
		playerSettings:SetValue(self._definition:GetSettingName(), value)
	end)
end

--[=[
	Restores the setting to the default value
]=]
function SettingProperty.RestoreDefault<T>(self: SettingProperty<T>): ()
	local settings = self:_getPlayerSettings()
	if settings then
		settings:RestoreDefault(self._definition:GetSettingName(), self._definition:GetDefaultValue())
	else
		warn(
			"[SettingProperty.RestoreDefault] - Cannot set setting value. Use :PromiseRestoreDefault() to ensure value is set after load."
		)
	end
end

--[=[
	Restores the setting to the default value. This is different than setting to the default value
	because it means there is no "user-set" value which could lead to values changing if
	defaults change.

	@return Promise
]=]
function SettingProperty.PromiseRestoreDefault<T>(self: SettingProperty<T>): Promise.Promise<()>
	return self:_promisePlayerSettings():Then(function(playerSettings)
		playerSettings:RestoreDefault(self._definition:GetSettingName(), self._definition:GetDefaultValue())
	end)
end

function SettingProperty._findPlayer<T>(self: SettingProperty<T>): Player?
	return rawget(self :: any, "_player") or Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
end

function SettingProperty._resolvePlayer<T>(self: SettingProperty<T>): Player
	return assert(self:_findPlayer(), "No player") :: Player
end

function SettingProperty._observePlayerSettings<T>(self: SettingProperty<T>)
	return self._bridge:ObservePlayerSettings(self:_resolvePlayer())
end

function SettingProperty._getPlayerSettings<T>(self: SettingProperty<T>)
	return self._bridge:GetPlayerSettings(self:_resolvePlayer())
end

function SettingProperty._promisePlayerSettings<T>(self: SettingProperty<T>)
	return self._bridge:PromisePlayerSettings(self:_resolvePlayer())
end

return SettingProperty
