--!strict
--[=[
	Key based CoreGuiEnabler, singleton
	Use this class to load/unload CoreGuis / other GUIs, by disabling based upon keys
	Keys are additive, so if you have more than 1 disabled, it's ok.

	```lua
	local CoreGuiEnabler = require("CoreGuiEnabler")

	-- Disable the backpack for 5 seconds
	local cleanup = CoreGuiEnabler:Disable(newproxy(), Enum.CoreGuiType.Backpack)
	task.delay(5, cleanup)
	```

	@class CoreGuiEnabler
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")

local CharacterUtils = require("CharacterUtils")
local Maid = require("Maid")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Rx = require("Rx")
local Symbol = require("Symbol")

local ALL_TOKEN = Symbol.named("allToken")

local CoreGuiEnabler = {}
CoreGuiEnabler.__index = CoreGuiEnabler
CoreGuiEnabler.ClassName = "CoreGuiEnabler"

export type CoreGuiEnabler = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_states: { [any]: { lastState: boolean, onChangeCallback: (boolean) -> (), disabledBy: { [any]: any } } },
		_stateSubs: ObservableSubscriptionTable.ObservableSubscriptionTable<boolean>,
	},
	{} :: typeof({ __index = CoreGuiEnabler })
))

function CoreGuiEnabler.new(): CoreGuiEnabler
	local self: CoreGuiEnabler = setmetatable({} :: any, CoreGuiEnabler)

	self._maid = Maid.new()
	self._states = {}

	self._stateSubs = self._maid:Add(ObservableSubscriptionTable.new() :: any)

	self:AddState(Enum.CoreGuiType.Backpack, function(isEnabled)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, isEnabled)

		if Players.LocalPlayer then
			CharacterUtils.unequipTools(Players.LocalPlayer)
		end
	end)

	self:AddState(Enum.CoreGuiType.SelfView, function(_isEnabled)
		-- Noopt
	end)

	-- Specifically handle this so we interface properly
	self:AddState(Enum.CoreGuiType.All, function(isEnabled)
		if isEnabled then
			for _, coreGuiType in Enum.CoreGuiType:GetEnumItems() do
				if coreGuiType ~= Enum.CoreGuiType.All then
					self:Enable(ALL_TOKEN, coreGuiType)
				end
			end
		else
			for _, coreGuiType in Enum.CoreGuiType:GetEnumItems() do
				if coreGuiType ~= Enum.CoreGuiType.All then
					self:Disable(ALL_TOKEN, coreGuiType)
				end
			end
		end
	end)

	for _, coreGuiType in Enum.CoreGuiType:GetEnumItems() do
		if not self._states[coreGuiType] then
			self:AddState(coreGuiType, function(isEnabled)
				StarterGui:SetCoreGuiEnabled(coreGuiType, isEnabled)
			end)
		end
	end

	self:_addStarterGuiState("TopbarEnabled")
	self:_addStarterGuiState("BadgesNotificationsActive")
	self:_addStarterGuiState("PointsNotificationsActive")

	self:AddState("ModalEnabled", function(isEnabled)
		UserInputService.ModalEnabled = not isEnabled
	end)

	self:AddState("EnableMouseLockOption", function(isEnabled)
		StarterPlayer.EnableMouseLockOption = isEnabled
	end)

	self:AddState("MouseIconEnabled", function(isEnabled)
		UserInputService.MouseIconEnabled = isEnabled
	end)

	return self
end

function CoreGuiEnabler:_addStarterGuiState(stateName)
	self:AddState(stateName, function(isEnabled)
		local success, err = pcall(function()
			StarterGui:SetCore(stateName, isEnabled)
		end)
		if not success then
			warn("[CoreGuiEnabler] - Failed to set core", err)
		end
	end)
end

--[=[
	Gets the current state

	@param coreGuiState string | CoreGuiType
	@return boolean
]=]
function CoreGuiEnabler:IsEnabled(coreGuiState): boolean
	local data = self._states[coreGuiState]
	if not data then
		error(string.format("[CoreGuiEnabler] - State '%s' does not exist.", tostring(coreGuiState)))
	end

	return next(data.disabledBy) == nil
end

--[=[
	Observes the state whenever it changed
	@param coreGuiState string | CoreGuiType
	@return Observable<boolean>
]=]
function CoreGuiEnabler:ObserveIsEnabled(coreGuiState)
	local data = self._states[coreGuiState]
	if not data then
		error(string.format("[CoreGuiEnabler] - State '%s' does not exist.", tostring(coreGuiState)))
	end

	return self._stateSubs:Observe(coreGuiState):Pipe({
		Rx.startFrom(function()
			return { self:IsEnabled(coreGuiState) }
		end),
	})
end

--[=[
	Adds a state that can be disabled or enabled.
	@param coreGuiState string | CoreGuiType
	@param onChangeCallback (isEnabled: boolean)
]=]
function CoreGuiEnabler:AddState(coreGuiState, onChangeCallback)
	assert(type(onChangeCallback) == "function", "must have onChangeCallback as function")
	assert(self._states[coreGuiState] == nil, "state already exists")

	self._states[coreGuiState] = {
		lastState = true,
		onChangeCallback = onChangeCallback,
		disabledBy = {},
	}
end

function CoreGuiEnabler:_setDisabledByKey(coreGuiState, key, value)
	assert(key ~= nil, "Bad key")

	local data = self._states[coreGuiState]
	if not data then
		error(string.format("[CoreGuiEnabler] - State '%s' does not exist.", tostring(coreGuiState)))
	end

	data.disabledBy[key] = value

	local newState = next(data.disabledBy) == nil
	if data.lastState ~= newState then
		data.lastState = newState
		data.onChangeCallback(newState)
		self._stateSubs:Fire(coreGuiState, newState)
	end
end

--[=[
	Disables a CoreGuiState
	@param key any
	@param coreGuiState string | CoreGuiType
	@return function -- Callback function to re-enable the state
]=]
function CoreGuiEnabler:Disable(key, coreGuiState)
	assert(key ~= nil, "Bad key")

	if not self._states[coreGuiState] then
		error(string.format("[CoreGuiEnabler] - State '%s' does not exist.", tostring(coreGuiState)))
	end

	self:_setDisabledByKey(coreGuiState, key, true)

	return function()
		self:Enable(key, coreGuiState)
	end
end

function CoreGuiEnabler:PushDisable(coreGuiState)
	local maid = Maid.new()

	local key = HttpService:GenerateGUID(false)

	maid:GiveTask(self:Disable(key, coreGuiState))

	return function()
		maid:DoCleaning()
	end
end

--[=[
	Enables a state for a given key
	@param key any
	@param coreGuiState string | CoreGuiType
]=]
function CoreGuiEnabler:Enable(key, coreGuiState)
	assert(key ~= nil, "Bad key")

	if not self._states[coreGuiState] then
		error(string.format("[CoreGuiEnabler] - State '%s' does not exist.", tostring(coreGuiState)))
	end

	self:_setDisabledByKey(coreGuiState, key, nil)
end

return CoreGuiEnabler.new()
