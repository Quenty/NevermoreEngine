--[=[
	Handles IK for local client.

	:::tip
	Be sure to also initialize the client side service [IKService] on the server
	to keep IK work.
	:::

	@client
	@class IKServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local IKRigUtils = require("IKRigUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local IKServiceClient = {}
IKServiceClient.ServiceName = "IKServiceClient"

--[=[
	Initializes the service. Should be called via the [ServiceBag].

	```lua
	local serviceBag = require("ServiceBag").new()
	serviceBag:GetService(require("IKServiceClient"))

	serviceBag:Init()
	serviceBag:Start()

	-- Configure
	serviceBag:GetService(require("IKServiceClient")):SetLookAround(true)
	```

	@param serviceBag ServiceBag
]=]
function IKServiceClient:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
	self._lookAround = false

	-- External
	self._serviceBag:GetService(require("CameraStackService"))
	self._serviceBag:GetService(require("TieRealmService"))
	self._serviceBag:GetService(require("Motor6DServiceClient"))

	-- Internal
	self._serviceBag:GetService(require("IKDataService"))

	-- Binders
	self._ikRigBinderClient = self._serviceBag:GetService(require("IKRigClient"))
	self._serviceBag:GetService(require("IKRightGrip"))
	self._serviceBag:GetService(require("IKLeftGrip"))
end

--[=[
	Starts the service. Should be called via the [ServiceBag].
]=]
function IKServiceClient:Start()
	assert(self._serviceBag, "Not initialized")

	self._maid:GiveTask(RunService.Stepped:Connect(function()
		self:_updateStepped()
	end))
end

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param humanoid Humanoid
	@return IKRigClient?
]=]
function IKServiceClient:GetRig(humanoid: Humanoid)
	assert(self._serviceBag, "Not initialized")
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._ikRigBinderClient:Get(humanoid)
end

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param humanoid Humanoid
	@return Promise<IKRigClient>
]=]
function IKServiceClient:PromiseRig(humanoid: Humanoid)
	assert(self._serviceBag, "Not initialized")
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._ikRigBinderClient:Promise(humanoid)
end

--[=[
	Exposed API for guns and other things to start setting aim position
	which will override for a limited time.

	```lua
	-- Make the local character always look towards the origin

	local IKServiceClient = require("IKServiceClient")
	local IKAimPositionPriorites = require("IKAimPositionPriorites")

	RunService.Stepped:Connect(function()
		serviceBag:GetService(IKServiceClient):SetAimPosition(Vector3.zero, IKAimPositionPriorites.HIGH)
	end)
	```

	@param position Vector3? -- May be nil to set no position
	@param priority number?
]=]
function IKServiceClient:SetAimPosition(position: Vector3, priority: number?)
	assert(self._serviceBag, "Not initialized")

	if position ~= position then
		warn("[IKServiceClient.SetAimPosition] - position is NaN")
		return
	end

	local aimer = self:GetLocalAimer()
	if not aimer then
		return
	end

	aimer:SetAimPosition(position, priority)
end

--[=[
	If true, tells the local player to look around at whatever
	the camera is pointed at.

	```lua

	serviceBag:GetService(require("IKServiceClient")):SetLookAround(false)
	```

	@param lookAround boolean
]=]
function IKServiceClient:SetLookAround(lookAround)
	assert(self._serviceBag, "Not initialized")

	self._lookAround = lookAround
end

--[=[
	Retrieves the local aimer for the local player.

	@return IKRigAimerLocalPlayer
]=]
function IKServiceClient:GetLocalAimer()
	assert(self._serviceBag, "Not initialized")

	local rig = self:GetLocalPlayerRig()
	if not rig then
		return nil
	end

	return rig:GetLocalPlayerAimer()
end

--[=[
	Attempts to retrieve the local player's ik rig, if it exists.

	@return IKRigClient?
]=]
function IKServiceClient:GetLocalPlayerRig()
	assert(self._serviceBag, "Not initialized")
	assert(self._ikRigBinderClient, "Not initialize")

	return IKRigUtils.getPlayerIKRig(self._ikRigBinderClient, Players.LocalPlayer)
end

function IKServiceClient:_updateStepped()
	debug.profilebegin("IKUpdate")

	local localAimer = self:GetLocalAimer()
	if localAimer then
		localAimer:SetLookAround(self._lookAround)
		localAimer:UpdateStepped()
	end

	local camPosition = Workspace.CurrentCamera.CFrame.p

	for _, rig in self._ikRigBinderClient:GetAll() do
		debug.profilebegin("RigUpdate")

		local position = rig:GetPositionOrNil()

		if position then
			local lastUpdateTime = rig:GetLastUpdateTime()
			local distance = (camPosition - position).Magnitude
			local timeBeforeNextUpdate = IKRigUtils.getTimeBeforeNextUpdate(distance)

			if (tick() - lastUpdateTime) >= timeBeforeNextUpdate then
				rig:Update() -- Update actual rig
			else
				rig:UpdateTransformOnly()
			end
		end

		debug.profileend()
	end

	debug.profileend()
end

function IKServiceClient:Destroy()
	self._maid:DoCleaning()
end

return IKServiceClient
