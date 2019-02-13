--- Key based CoreGuiEnabler, singleton
-- Use this class to load/unload CoreGuis / other GUIs, by disabling based upon keys
-- Keys are additive, so if you have more than 1 disabled, it's ok.
-- @module CoreGuiEnabler

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local CharacterUtil = require("CharacterUtil")

local CoreGuiEnabler = {}
CoreGuiEnabler.__index = CoreGuiEnabler
CoreGuiEnabler.ClassName = "CoreGuiEnabler"

function CoreGuiEnabler.new()
	local self = setmetatable({}, CoreGuiEnabler)

	self._states = {}

	self:AddState(Enum.CoreGuiType.Backpack, function(isEnabled)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, isEnabled)
		CharacterUtil.UnequipTools(Players.LocalPlayer)
	end)

	for _, coreGuiType in pairs(Enum.CoreGuiType:GetEnumItems()) do
		if not self._states[coreGuiType] then
			self:AddState(coreGuiType, function(isEnabled)
				StarterGui:SetCoreGuiEnabled(coreGuiType, isEnabled)
			end)
		end
	end

	self.TopbarEnabledState = Instance.new("BoolValue")
	self.TopbarEnabledState.Value = false

	self:AddState("TopbarEnabled", function(isEnabled)
		self.TopbarEnabledState.Value = isEnabled
		local success, err = pcall(function()
			StarterGui:SetCore("TopbarEnabled", isEnabled)
		end)
		if not success then
			warn("Failed to set topbar", err)
		end
	end)

	self:AddState("ModalEnabled", function(isEnabled)
		UserInputService.ModalEnabled = not isEnabled
	end)

	self:AddState("MouseIconEnabled", function(isEnabled)
		UserInputService.MouseIconEnabled = isEnabled
	end)

	return self
end

function CoreGuiEnabler:AddState(key, coreGuiStateChangeFunc)
	assert(type(coreGuiStateChangeFunc) == "function", "must have coreGuiStateChangeFunc as function")
	assert(self._states[key] == nil, "state already exists")

	local realState = {}
	local lastState = true

	local function isEnabled()
		for _, _ in pairs(realState) do
			return false
		end
		return true
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