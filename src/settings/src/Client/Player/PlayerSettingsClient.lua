--!strict
--[=[
	A player's current settings. Handles replication back to the server
	when a setting changes. See [PlayerSettingsBase].

	@client
	@class PlayerSettingsClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local DataStoreStringUtils = require("DataStoreStringUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerSettingsBase = require("PlayerSettingsBase")
local PlayerSettingsConstants = require("PlayerSettingsConstants")
local PlayerSettingsInterface = require("PlayerSettingsInterface")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local Promise = require("Promise")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local Symbol = require("Symbol")
local ThrottledFunction = require("ThrottledFunction")
local ValueObject = require("ValueObject")

local UNSET_VALUE = Symbol.named("unsetValue")

local PlayerSettingsClient = {}
PlayerSettingsClient.ClassName = "PlayerSettingsClient"
PlayerSettingsClient.__index = PlayerSettingsClient
-- Runtime inheritance only. Typing the metatable target as `any` keeps the old solver from
-- chasing the full PlayerSettingsBase type here, which otherwise overflows its complexity
-- budget ("Code is too complex"). The inherited surface is supplied structurally below.
setmetatable(PlayerSettingsClient :: any, PlayerSettingsBase)

-- Only the dynamic remoting member this class touches.
type RemotingLike = {
	RequestUpdateSettings: any,
}

-- Minimal structural surface inherited from PlayerSettingsBase that this class uses. See the
-- setmetatable note above for why we don't intersect PlayerSettingsBase.PlayerSettingsBase.
type PlayerSettingsBaseLike = {
	_obj: Folder,
	_maid: Maid.Maid,
	GetPlayer: (self: any) -> Player?,
	Destroy: (self: any) -> (),
}

export type PlayerSettingsClient =
	typeof(setmetatable(
		{} :: {
			_remoting: RemotingLike,
			_pendingReplicationDataInTransit: ValueObject.ValueObject<any>,
			_toReplicate: { [any]: any? }?,
			_toReplicateCallbacks: { [string]: { [any]: any } },
			_currentReplicationRequest: Promise.Promise<()>?,
			_queueSendSettingsFunc: ThrottledFunction.ThrottledFunction<()>,
		},
		{} :: typeof({ __index = PlayerSettingsClient })
	))
	& PlayerSettingsBaseLike

--[=[
	See [SettingsBindersClient] and [SettingsServiceClient] on how to properly use this class.

	@param folder Folder
	@param serviceBag ServiceBag
	@return PlayerSettingsClient
]=]
function PlayerSettingsClient.new(folder: Folder, serviceBag: ServiceBag.ServiceBag): PlayerSettingsClient
	local self: PlayerSettingsClient =
		setmetatable(PlayerSettingsBase.new(folder, serviceBag) :: any, PlayerSettingsClient)

	if self:GetPlayer() == Players.LocalPlayer then
		self._remoting = self._maid:Add(Remoting.new(self._obj, "PlayerSettings", Remoting.Realms.CLIENT)) :: any

		self._toReplicate = nil
		self._toReplicateCallbacks = {}

		-- We only want to keep this data here until we're
		-- actually done sending and the server acknowledges this is the state that
		-- we have. Otherwise we accept the server as the state of truth
		self._pendingReplicationDataInTransit = self._maid:Add(ValueObject.new(nil))

		-- We need to avoid sending these quickly because otherwise
		-- sliding a slider can lag out stuff.
		self._queueSendSettingsFunc = self._maid:Add(ThrottledFunction.new(0.3, function()
			self:_sendSettings()
		end, { leading = true, trailing = true }))

		self._maid:GiveTask(PlayerSettingsInterface.Client:Implement(self._obj, self))
	end

	return self
end

--[=[
	Gets a settings value

	@param settingName string
	@param defaultValue T
	@return T
]=]
function PlayerSettingsClient.GetValue<T>(self: PlayerSettingsClient, settingName: string, defaultValue: T): T
	assert(type(settingName) == "string", "Bad settingName")

	if self._toReplicate and self._toReplicate[settingName] ~= nil then
		return PlayerSettingsUtils.decodeForNetwork(self._toReplicate[settingName])
	end

	local pending = self._pendingReplicationDataInTransit.Value
	if pending and pending[settingName] ~= nil then
		return PlayerSettingsUtils.decodeForNetwork(pending[settingName])
	end

	return (getmetatable(PlayerSettingsClient :: any) :: any).GetValue(self, settingName, defaultValue)
end

--[=[
	Observes a settings value.

	@param settingName string
	@param defaultValue T
	@return Observable<T>
]=]
function PlayerSettingsClient.ObserveValue<T>(
	self: PlayerSettingsClient,
	settingName: string,
	defaultValue: T
): Observable.Observable<T>
	assert(type(settingName) == "string", "Bad settingName")

	local baseObservable = (getmetatable(PlayerSettingsClient :: any) :: any).ObserveValue(
		self,
		settingName,
		defaultValue
	)

	-- We need to register our own replication checkers...
	return Observable.new(function(sub)
		local maid = Maid.new()

		local lastValue = UNSET_VALUE
		local lastObservedValue = UNSET_VALUE

		local function set(value)
			if lastValue ~= value then
				lastValue = value
				sub:Fire(lastValue)
			end
		end

		local function update()
			-- If we have existing queued data, report that
			if self._toReplicate ~= nil and self._toReplicate[settingName] ~= nil then
				set(PlayerSettingsUtils.decodeForNetwork(self._toReplicate[settingName]))
				return
			end

			-- Otherwise report data we're pending to send...
			local pending = self._pendingReplicationDataInTransit.Value
			if pending and pending[settingName] ~= nil then
				set(PlayerSettingsUtils.decodeForNetwork(pending[settingName]))
				return
			end

			-- Otherwise report the base value
			if lastObservedValue ~= UNSET_VALUE then
				set(lastObservedValue)
			end
		end

		maid:GiveTask(self._pendingReplicationDataInTransit.Changed:Connect(function(newValue)
			if newValue ~= nil then
				update()
			end
		end))

		self._toReplicateCallbacks[settingName] = self._toReplicateCallbacks[settingName] or {}
		self._toReplicateCallbacks[settingName][update] = true

		maid:GiveTask(function()
			local callbacks = self._toReplicateCallbacks[settingName]
			if callbacks then
				callbacks[update] = nil

				if not next(callbacks) then
					self._toReplicateCallbacks[settingName] = nil
				end
			end
		end)

		maid:GiveTask(baseObservable:Subscribe(function(newValue)
			lastObservedValue = newValue
			update()
		end, sub:GetFailComplete()))

		update()

		return maid
	end) :: any
end

--[=[
	Sets a settings value and replicates the value eventually (in a de-duplicated manner).

	@param settingName string
	@param value T
]=]
function PlayerSettingsClient.SetValue<T>(self: PlayerSettingsClient, settingName: string, value: T): ()
	assert(type(settingName) == "string", "Bad settingName")
	assert(self:GetPlayer() == Players.LocalPlayer, "Cannot set settings of another player")
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")

	if type(value) == "string" then
		assert(DataStoreStringUtils.isValidUTF8(value), "Invalid string")

		if (#value + #settingName) > PlayerSettingsConstants.MAX_SETTINGS_LENGTH then
			error(string.format("[PlayerSettingsClient.SetValue] - Setting is too long for %q", settingName))
		end
	end

	local queueReplication = false
	local toReplicate
	if self._toReplicate then
		toReplicate = self._toReplicate
	else
		toReplicate = {}
		self._toReplicate = toReplicate
		queueReplication = true
	end

	toReplicate[settingName] = PlayerSettingsUtils.encodeForNetwork(value)

	if self._toReplicateCallbacks[settingName] then
		for callback, _ in self._toReplicateCallbacks[settingName] do
			task.spawn(callback)
		end
	end

	if queueReplication then
		if self._currentReplicationRequest and self._currentReplicationRequest:IsPending() then
			-- Wait until current saving is done to save...
			self._currentReplicationRequest:Finally(function()
				if self.Destroy then
					self._queueSendSettingsFunc:Call()
				end
			end)
		else
			self._queueSendSettingsFunc:Call()
		end
	end
end

function PlayerSettingsClient._sendSettings(self: PlayerSettingsClient)
	if not self._toReplicate then
		warn("Nothing to save, should not have called this method")
		return
	end

	local toReplicate = self._toReplicate
	self._toReplicate = nil

	local promise = self:_promiseReplicateSettings(toReplicate)
	self._pendingReplicationDataInTransit.Value = toReplicate

	promise:Finally(function()
		if self._currentReplicationRequest == promise then
			self._currentReplicationRequest = nil
		end

		if self._pendingReplicationDataInTransit.Value == toReplicate then
			self._pendingReplicationDataInTransit.Value = nil
		end
	end)

	return promise
end

function PlayerSettingsClient._promiseReplicateSettings(self: PlayerSettingsClient, settingsMap)
	assert(type(settingsMap) == "table", "Bad settingsMap")

	return self._remoting.RequestUpdateSettings:PromiseInvokeServer(settingsMap)
end

return Binder.new("PlayerSettings", PlayerSettingsClient :: any) :: Binder.Binder<PlayerSettingsClient>
