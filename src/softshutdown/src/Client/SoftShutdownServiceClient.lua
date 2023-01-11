--[=[
	@class SoftShutdownServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

local AttributeValue = require("AttributeValue")
local Maid = require("Maid")
local PlayerGuiUtils = require("PlayerGuiUtils")
local Rx = require("Rx")
local SoftShutdownConstants = require("SoftShutdownConstants")
local SoftShutdownTranslator = require("SoftShutdownTranslator")
local SoftShutdownUI = require("SoftShutdownUI")
local RxValueBaseUtils = require("RxValueBaseUtils")
local CoreGuiEnabler = require("CoreGuiEnabler")

local SoftShutdownServiceClient = {}
SoftShutdownServiceClient.ServiceName = "SoftShutdownServiceClient"

local DISABLE_CORE_GUI_TYPES = {
	Enum.CoreGuiType.PlayerList;
	Enum.CoreGuiType.Health;
	Enum.CoreGuiType.Backpack;
	Enum.CoreGuiType.Chat;
	Enum.CoreGuiType.EmotesMenu;
	Enum.CoreGuiType.All;
}

function SoftShutdownServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
	self._translator = self._serviceBag:GetService(SoftShutdownTranslator)

	self._isLobby = AttributeValue.new(Workspace, SoftShutdownConstants.IS_SOFT_SHUTDOWN_LOBBY_ATTRIBUTE, false)
	self._isUpdating = AttributeValue.new(Workspace, SoftShutdownConstants.IS_SOFT_SHUTDOWN_UPDATING_ATTRIBUTE, false)

	self._localTeleportDataSaysIsLobby = Instance.new("BoolValue")
	self._localTeleportDataSaysIsLobby.Value = false
	self._maid:GiveTask(self._localTeleportDataSaysIsLobby)

	self._isArrivingAfterShutdown = Instance.new("BoolValue")
	self._isArrivingAfterShutdown.Value = false
	self._maid:GiveTask(self._isArrivingAfterShutdown)

	task.spawn(function()
		if self:_queryLocalTeleportInfo() then
			self._localTeleportDataSaysIsLobby.Value = true
		end
		if self:_queryIsArrivingAfterShutdown() then
			self._isArrivingAfterShutdown.Value = true;
		end
	end)

	self._maid:GiveTask(Rx.combineLatest({
		isLobby = self._isLobby:Observe();
		isShuttingDown = self._isUpdating:Observe();
		localTeleportDataSaysIsLobby = RxValueBaseUtils.observeValue(self._localTeleportDataSaysIsLobby);
		isArrivingAfterShutdown = RxValueBaseUtils.observeValue(self._isArrivingAfterShutdown);
	}):Subscribe(function(state)
		if state.isLobby or state.localTeleportDataSaysIsLobby then
			self._maid._shutdownUI = nil
			if not self._maid._lobbyUI then
				local screenGui
				self._maid._lobbyUI, screenGui = self:_showSoftShutdownUI("shutdown.lobby.title", "shutdown.lobby.subtitle", true)

				TeleportService:SetTeleportGui(screenGui)
			end
		elseif state.isShuttingDown then
			local screenGui
			self._maid._shutdownUI, screenGui = self:_showSoftShutdownUI("shutdown.restart.title", "shutdown.restart.subtitle")

			TeleportService:SetTeleportGui(screenGui)

			self._maid._lobbyUI = nil
		elseif state.isArrivingAfterShutdown then
			-- Construct
			local maid = self:_showSoftShutdownUI("shutdown.complete.title", "shutdown.complete.subtitle", true)
			self._maid._shutdownUI = maid
			self._maid._lobbyUI = nil

			-- Defer
			task.delay(1, function()
				if self._maid._shutdownUI == maid then
					self._maid._shutdownUI = nil
				end
			end)
		else
			self._maid._shutdownUI = nil
			self._maid._lobbyUI = nil
		end
	end))
end

function SoftShutdownServiceClient:_queryIsArrivingAfterShutdown()
	local data = TeleportService:GetLocalPlayerTeleportData()
	if type(data) == "table" and data.isSoftShutdownArrivingIntoUpdatedServer then
		return true
	else
		return false
	end
end

function SoftShutdownServiceClient:_queryLocalTeleportInfo()
	local data = TeleportService:GetLocalPlayerTeleportData()
	if type(data) == "table" and data.isSoftShutdownReserveServer then
		return true
	else
		return false
	end
end

function SoftShutdownServiceClient:_showSoftShutdownUI(titleKey, subtitleKey, doNotAnimateShow)
	local maid = Maid.new()

	local renderMaid = Maid.new()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SoftShutdownScreenGui"
	screenGui.ResetOnSpawn = false
	screenGui.AutoLocalize = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1e9
	screenGui.Parent = PlayerGuiUtils.getPlayerGui()
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	renderMaid:GiveTask(screenGui)

	local softShutdownUI = SoftShutdownUI.new()
	renderMaid:GiveTask(softShutdownUI)

	maid:GiveTask(function()
		softShutdownUI:Hide()

		task.delay(1, function()
			renderMaid:Destroy()
		end)
	end)

	self:_hideCoreGuiUI(renderMaid, screenGui)

	maid:GivePromise(self._translator:PromiseFormatByKey(subtitleKey)):Then(function(subtitle)
		softShutdownUI:SetSubtitle(subtitle)
	end)

	maid:GivePromise(self._translator:PromiseFormatByKey(titleKey)):Then(function(title)
		softShutdownUI:SetTitle(title)
	end)

	softShutdownUI:Show(doNotAnimateShow)

	softShutdownUI.Gui.Parent = screenGui

	return maid, screenGui
end

function SoftShutdownServiceClient:_hideCoreGuiUI(maid, ignoreScreenGui)
	-- Hide all other ui
	if not UserInputService.ModalEnabled then
		UserInputService.ModalEnabled = true
		maid:GiveTask(function()
			UserInputService.ModalEnabled = false
		end)
	end

	local playerGui = PlayerGuiUtils.getPlayerGui()

	local enabledScreenGuis = {}

	local function handleChild(child)
		if child:IsA("ScreenGui") and child ~= ignoreScreenGui and child.Enabled then
			enabledScreenGuis[child] = child
			child.Enabled = false
		end
	end

	for _, child in pairs(playerGui:GetChildren()) do
		handleChild(child)
	end

	maid:GiveTask(playerGui.ChildAdded:Connect(function(child)
		handleChild(child)
	end))

	maid:GiveTask(playerGui.ChildRemoved:Connect(function(child)
		enabledScreenGuis[child] = nil
	end))

	maid:GiveTask(function()
		for screenGui, _ in pairs(enabledScreenGuis) do
			screenGui.Enabled = true
		end
	end)

	for _, coreGuiType in pairs(DISABLE_CORE_GUI_TYPES) do
		maid:GiveTask(CoreGuiEnabler:Disable(self, coreGuiType))
	end
end

function SoftShutdownServiceClient:Destroy()
	self._maid:DoCleaning()
end

return SoftShutdownServiceClient