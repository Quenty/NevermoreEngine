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
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local CharacterUtils = require("CharacterUtils")
local Maid = require("Maid")

local CoreGuiEnabler = {}
CoreGuiEnabler.__index = CoreGuiEnabler
CoreGuiEnabler.ClassName = "CoreGuiEnabler"

function CoreGuiEnabler.new()
	local self = setmetatable({}, CoreGuiEnabler)

	self._maid = Maid.new()

	self._states = {}

	self:AddState(Enum.CoreGuiType.Backpack, function(isEnabled)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, isEnabled)
		CharacterUtils.unequipTools(Players.LocalPlayer)
	end)

	for _, coreGuiType in pairs(Enum.CoreGuiType:GetEnumItems()) do
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

	self:AddState("MouseIconEnabled", function(isEnabled)
		UserInputService.MouseIconEnabled = isEnabled
	end)

	return self
end

function CoreGuiEnabler:_addStarterGuiState(stateName)
	local boolValueName = stateName .. "State"
	self[boolValueName] = Instance.new("BoolValue")
	self[boolValueName].Value = false

	self:AddState(stateName, function(isEnabled)
		self[boolValueName].Value = isEnabled
		local success, err = pcall(function()
			StarterGui:SetCore(stateName, isEnabled)
		end)
		if not success then
			warn("Failed to set core", err)
		end
	end)
end

--[=[
	Adds a state that can be disabled or enabled.
	@param coreGuiState string | CoreGuiType
	@param coreGuiStateChangeFunc (isEnabled: boolean)
]=]
function CoreGuiEnabler:AddState(coreGuiState, coreGuiStateChangeFunc)
	assert(type(coreGuiStateChangeFunc) == "function", "must have coreGuiStateChangeFunc as function")
	assert(self._states[coreGuiState] == nil, "state already exists")

	local realState = {}
	local lastState = true

	local function isEnabled()
		return next(realState) == nil
	end

	self._states[coreGuiState] = setmetatable({}, {
		__newindex = function(_, index, value)
			rawset(realState, index, value)

			local newState = isEnabled()
			if lastState ~= newState then
				lastState = newState
				coreGuiStateChangeFunc(newState)
			end
		end;
	})
end

--[=[
	Disables a CoreGuiState
	@param key any
	@param coreGuiState string | CoreGuiType
	@return function -- Callback function to re-enable the state
]=]
function CoreGuiEnabler:Disable(key, coreGuiState)
	if not self._states[coreGuiState] then
		error(("[CoreGuiEnabler] - State '%s' does not exist."):format(tostring(coreGuiState)))
	end

	self._states[coreGuiState][key] = true

	return function()
		self:Enable(key, coreGuiState)
	end
end

--[=[
	Enables a state for a given key
	@param key any
	@param coreGuiState string | CoreGuiType
]=]
function CoreGuiEnabler:Enable(key, coreGuiState)
	if not self._states[coreGuiState] then
		error(("[CoreGuiEnabler] - State '%s' does not exist."):format(tostring(coreGuiState)))
	end

	self._states[coreGuiState][key] = nil
end

return CoreGuiEnabler.new()