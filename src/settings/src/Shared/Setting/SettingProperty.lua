--[=[
	@class SettingProperty
]=]

local require = require(script.Parent.loader).load(script)

local SettingsDataService = require("SettingsDataService")
local Rx = require("Rx")
local RxSignal = require("RxSignal")

local SettingProperty = {}
SettingProperty.ClassName = "SettingProperty"
SettingProperty.__index = SettingProperty

--[=[
	Constructs a new SettingProperty.

	@param serviceBag ServiceBag
	@param player Player
	@param definition SettingDefinition
	@return SettingProperty<T>
]=]
function SettingProperty.new(serviceBag, player, definition)
	local self = setmetatable({}, SettingProperty)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._bridge = self._serviceBag:GetService(SettingsDataService)

	self._player = assert(player, "No player")
	self._definition = assert(definition, "No definition")

	self:_promisePlayerSettings():Then(function(playerSettings)
		playerSettings:EnsureInitialized(self._definition:GetSettingName(), self._definition:GetDefaultValue())
	end)

	return self
end

--[=[
	Observes the value of the setting property
	@return Observable<T>
]=]
function SettingProperty:Observe()
	return self:_observePlayerSettings():Pipe({
		Rx.where(function(settings)
			return settings ~= nil
		end);
		Rx.take(1);
		Rx.switchMap(function()
			-- Ensure we're loaded first and then register for real.
			return self:_observePlayerSettings()
		end);
		Rx.switchMap(function(playerSettings)
			if not playerSettings then
				-- Don't emit until we have a value
				return Rx.of(self._definition:GetDefaultValue())
			else
				return playerSettings:ObserveValue(self._definition:GetSettingName(), self._definition:GetDefaultValue())
			end
		end);
	})
end

function SettingProperty:__index(index)
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
					Rx.skip(1);
				}))
	elseif index == "DefaultValue" then
		return self._definition:GetDefaultValue()
	elseif SettingProperty[index] then
		return SettingProperty[index]
	else
		error(string.format("%q is not a member of SettingProperty %s", tostring(index), self._definition:GetSettingName()))
	end
end

function SettingProperty:__newindex(index, value)
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
function SettingProperty:SetValue(value)
	local settings = self:_getPlayerSettings()
	if settings then
		settings:SetValue(self._definition:GetSettingName(), value)
	else
		warn("[SettingProperty.SetValue] - Cannot set setting value. Use :PromiseSetValue() to ensure value is set after load.")
	end
end

--[=[
	Promises the value of the setting once it's loaded.

	@return Promise<T>
]=]
function SettingProperty:PromiseValue()
	return self:_promisePlayerSettings()
		:Then(function(playerSettings)
			return playerSettings:GetValue(self._definition:GetSettingName(), self._definition:GetDefaultValue())
		end)
end

--[=[
	Promises to set the value

	@param value T
	@return Promise
]=]
function SettingProperty:PromiseSetValue(value)
	return self:_promisePlayerSettings()
		:Then(function(playerSettings)
			playerSettings:SetValue(self._definition:GetSettingName(), value)
		end)
end

--[=[
	Restores the setting to the default value
]=]
function SettingProperty:RestoreDefault()
	local settings = self:_getPlayerSettings()
	if settings then
		settings:RestoreDefault(self._definition:GetSettingName(), self._definition:GetDefaultValue())
	else
		warn("[SettingProperty.RestoreDefault] - Cannot set setting value. Use :PromiseRestoreDefault() to ensure value is set after load.")
	end
end

--[=[
	Restores the setting to the default value. This is different than setting to the default value
	because it means there is no "user-set" value which could lead to values changing if
	defaults change.

	@return Promise
]=]
function SettingProperty:PromiseRestoreDefault()
	return self:_promisePlayerSettings()
		:Then(function(playerSettings)
			playerSettings:RestoreDefault(self._definition:GetSettingName(), self._definition:GetDefaultValue())
		end)
end


function SettingProperty:_observePlayerSettings()
	return self._bridge:ObservePlayerSettings(self._player)
end

function SettingProperty:_getPlayerSettings()
	return self._bridge:GetPlayerSettings(self._player)
end

function SettingProperty:_promisePlayerSettings()
	return self._bridge:PromisePlayerSettings(self._player)
end

return SettingProperty