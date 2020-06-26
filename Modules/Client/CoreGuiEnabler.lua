--- Key based CoreGuiEnabler, singleton
-- Use this class to load/unload CoreGuis / other GUIs, by disabling based upon keys
-- Keys are additive, so if you have more than 1 disabled, it's ok.
-- @module CoreGuiEnabler

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

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
		if isEnabled then
			UserInputService.MouseIconEnabled = isEnabled
		else
			UserInputService.MouseIconEnabled = false
			self._maid:GiveTask(UserInputService:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
				UserInputService.MouseIconEnabled = false
			end))
		end
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

function CoreGuiEnabler:AddState(key, coreGuiStateChangeFunc)
	assert(type(coreGuiStateChangeFunc) == "function", "must have coreGuiStateChangeFunc as function")
	assert(self._states[key] == nil, "state already exists")

	local realState = {}
	local lastState = true

	local function isEnabled()
		return next(realState) == nil
	end

	self._states[key] = setmetatable({}, {
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

function CoreGuiEnabler:Disable(key, coreGuiState)
	if not self._states[coreGuiState] then
		error(("[CoreGuiEnabler] - State '%s' does not exist."):format(tostring(coreGuiState)))
	end

	self._states[coreGuiState][key] = true

	return function()
		self:Enable(key, coreGuiState)
	end
end

function CoreGuiEnabler:Enable(key, coreGuiState)
	if not self._states[coreGuiState] then
		error(("[CoreGuiEnabler] - State '%s' does not exist."):format(tostring(coreGuiState)))
	end

	self._states[coreGuiState][key] = nil
end

return CoreGuiEnabler.new()