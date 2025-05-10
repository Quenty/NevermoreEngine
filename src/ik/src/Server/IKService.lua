--[=[
	Handles the replication of inverse kinematics (IK) from clients to servers

	* Supports animation playback on top of existing animations
	* Battle-tested code
	* Handles streaming enabled
	* Supports NPCs
	* Client-side animations scale with distance
	* Client-side animations keep thinks silky

	:::tip
	Be sure to also initialize the client side service [IKServiceClient] on each
	client to make sure the IK works.
	:::

	@server
	@class IKService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local SERVER_UPDATE_RATE = 1 / 10

local IKService = {}
IKService.ServiceName = "IKService"

--[=[
	Initializes the IKService. Should be done via the ServiceBag.

	```lua
	local serviceBag = require("ServiceBag").new()
	serviceBag:GetService(require("IKService"))

	serviceBag:Init()
	serviceBag:Start()
	```

	@param serviceBag ServiceBag
]=]
function IKService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._maid, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("Motor6DService"))
	self._serviceBag:GetService(require("TieRealmService"))
	self._humanoidTrackerService = self._serviceBag:GetService(require("HumanoidTrackerService"))

	-- Internal
	self._serviceBag:GetService(require("IKDataService"))

	-- Binders
	self._ikRigBinder = self._serviceBag:GetService(require("IKRig"))
	self._serviceBag:GetService(require("IKRightGrip"))
	self._serviceBag:GetService(require("IKLeftGrip"))
end

--[=[
	Starts the IKService. Should be done via the ServiceBag.
]=]
function IKService:Start()
	assert(self._maid, "Not initialized")

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_handlePlayer(player)
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_handlePlayerRemoving(player)
	end))

	for _, player in Players:GetPlayers() do
		self:_handlePlayer(player)
	end

	self._maid:GiveTask(RunService.Stepped:Connect(function()
		self:_updateStepped()
	end))
end

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param humanoid Humanoid
	@return IKRig?
]=]
function IKService:GetRig(humanoid: Humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._ikRigBinder:Bind(humanoid)
end

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param humanoid Humanoid
	@return Promise<IKRig>
]=]
function IKService:PromiseRig(humanoid: Humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	self._ikRigBinder:Bind(humanoid)
	return self._ikRigBinder:Promise(humanoid)
end

--[=[
	Unbinds the rig from the humanoid.
	@param humanoid Humanoid
]=]
function IKService:RemoveRig(humanoid: Humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	self._ikRigBinder:Unbind(humanoid)
end

--[=[
	Updates the ServerIKRig target for an NPC

	```lua
	local IKService = require("IKService")

	-- Make the NPC look at a target
	serviceBag:GetService(IKService):UpdateServerRigTarget(workspace.NPC.Humanoid, Vector3.zero)
	```

	@param humanoid Humanoid
	@param target Vector3?
]=]
function IKService:UpdateServerRigTarget(humanoid: Humanoid, target)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")
	assert(typeof(target) == "Vector3", "Bad target")

	local serverRig = self._ikRigBinder:Bind(humanoid)
	if not serverRig then
		warn("[IKService.UpdateServerRigTarget] - No serverRig")
		return
	end

	serverRig:SetAimPosition(target)
end

function IKService:_handlePlayerRemoving(player: Player)
	self._maid[player] = nil
end

function IKService:_handlePlayer(player: Player)
	local maid = Maid.new()

	local humanoidTracker = self._humanoidTrackerService:GetHumanoidTracker(player)

	maid:GiveTask(humanoidTracker.AliveHumanoid.Changed:Connect(function(new, old)
		if old then
			self._ikRigBinder:Unbind(old)
		end
		if new then
			self._ikRigBinder:Bind(new)
		end
	end))

	if humanoidTracker.AliveHumanoid.Value then
		self._ikRigBinder:Bind(humanoidTracker.AliveHumanoid.Value)
	end

	self._maid[player] = maid
end

function IKService:_updateStepped()
	debug.profilebegin("IKUpdateServer")

	for _, rig in self._ikRigBinder:GetAll() do
		debug.profilebegin("RigUpdateServer")

		local lastUpdateTime = rig:GetLastUpdateTime()
		if (tick() - lastUpdateTime) >= SERVER_UPDATE_RATE then
			rig:Update() -- Update actual rig
		else
			rig:UpdateTransformOnly()
		end

		debug.profileend()
	end
	debug.profileend()
end

function IKService:Destroy()
	self._maid:DoCleaning()
end

return IKService
