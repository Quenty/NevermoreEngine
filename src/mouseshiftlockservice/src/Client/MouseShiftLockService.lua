--!strict
--[=[
	Utility service to enable or disable mouse shift lock on the fly on Roblox.

	See: https://devforum.roblox.com/t/custom-center-locked-mouse-camera-control-toggle/205323

	```lua
	local mouseShiftLockService = serviceBag:GetService(MouseShiftLockService)
	mouseShiftLockService:DisableShiftLock()
	```

	@class MouseShiftLockService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Promise = require("Promise")

local MouseShiftLockService = {}
MouseShiftLockService.ServiceName = "MouseShiftLockService"

export type MouseShiftLockService = typeof(setmetatable(
	{} :: {
		_enabled: BoolValue,
		_promiseReady: Promise.Promise<()>?,
		_boundKeys: StringValue,
		_lastBoundKeyValues: string,
		_playerModule: any,
		_wasMouseLockEnabled: boolean?,
	},
	{} :: typeof({ __index = MouseShiftLockService })
))

--[=[
	Initializes the mouse shift lock service. Should be done via [ServiceBag].
]=]

function MouseShiftLockService.Init(self: MouseShiftLockService): ()
	assert((self :: any) ~= MouseShiftLockService, "Call via serviceBag")
	assert(not (self :: any)._enabled, "Not enabled")
	self._enabled = Instance.new("BoolValue")
	self._enabled.Value = true

	if not StarterPlayer.EnableMouseLockOption then
		return
	end

	local promiseReady = self:_buildPromiseReady()
	self._promiseReady = promiseReady

	promiseReady:Then(function()
		self._enabled.Changed:Connect(function()
			self:_update()
		end)

		if not self._enabled.Value then
			self:_update()
		end
	end)
end

function MouseShiftLockService._buildPromiseReady(self: MouseShiftLockService): Promise.Promise<()>
	if not UserInputService.MouseEnabled then
		-- TODO: Handle mouse being plugged in later
		return Promise.rejected() :: Promise.Promise<()>
	end

	return Promise.spawn(function(resolve, reject)
		local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
		local playerModuleScript = playerScripts:WaitForChild("PlayerModule")
		local cameraModuleScript = playerModuleScript:WaitForChild("CameraModule")

		local mouseLockControllerScript = cameraModuleScript:WaitForChild("MouseLockController")
		local boundKeys = mouseLockControllerScript:WaitForChild("BoundKeys") :: StringValue
		self._boundKeys = boundKeys
		self._lastBoundKeyValues = boundKeys.Value

		local ok, err = pcall(function()
			self._playerModule = (require :: any)(playerModuleScript)
		end)

		if not ok then
			return reject(err)
		end

		return resolve()
	end)
end

--[=[
	Enables mouse shift lock
]=]
function MouseShiftLockService.EnableShiftLock(self: MouseShiftLockService): ()
	assert((self :: any) ~= MouseShiftLockService, "Call via serviceBag")
	assert(self._enabled, "Not enabled")

	self._enabled.Value = true
end

--[=[
	Disables mouse shift lock
]=]

function MouseShiftLockService.DisableShiftLock(self: MouseShiftLockService): ()
	assert((self :: any) ~= MouseShiftLockService, "Call via serviceBag")
	assert(self._enabled, "Not enabled")

	self._enabled.Value = false
end

function MouseShiftLockService._update(self: MouseShiftLockService): ()
	local promiseReady = self._promiseReady
	assert(promiseReady, "Not initialized")
	assert(promiseReady:IsFulfilled())

	if self._enabled.Value then
		self:_updateEnable()
	else
		self:_updateDisable()
	end
end

function MouseShiftLockService._updateEnable(self: MouseShiftLockService): ()
	local cameras = self._playerModule:GetCameras()
	local cameraController = cameras.activeCameraController
	if not cameraController then
		warn("[MouseShiftLockService._updateEnable] - No activeCameraController")
		return
	end

	local mouseLockController = cameras.activeMouseLockController
	if not mouseLockController then
		warn("[MouseShiftLockService._updateEnable] - No activeMouseLockController")
		return
	end

	self._boundKeys.Value = self._lastBoundKeyValues
	if self._wasMouseLockEnabled then
		cameraController:SetIsMouseLocked(self._wasMouseLockEnabled)
		mouseLockController:OnMouseLockToggled()
	end
end

function MouseShiftLockService._updateDisable(self: MouseShiftLockService): ()
	local cameras = self._playerModule:GetCameras()
	local cameraController = cameras.activeCameraController
	if not cameraController then
		warn("[MouseShiftLockService._updateDisable] - No activeCameraController")
		return
	end

	local mouseLockController = cameras.activeMouseLockController
	if not mouseLockController then
		warn("[MouseShiftLockService._updateDisable] - No activeMouseLockController")
		return
	end

	if #self._boundKeys.Value > 0 then
		self._lastBoundKeyValues = self._boundKeys.Value
	end

	self._wasMouseLockEnabled = cameraController:GetIsMouseLocked()
	self._boundKeys.Value = ""

	if self._wasMouseLockEnabled then
		cameraController:SetIsMouseLocked(false)
		mouseLockController:OnMouseLockToggled()
	end
end

return MouseShiftLockService
