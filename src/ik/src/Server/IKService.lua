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
local HumanoidTracker = require("HumanoidTracker")

local SERVER_UPDATE_RATE = 1/10

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
function IKService:Init(serviceBag)
	assert(not self._maid, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("Motor6DService"))

	-- Internal
	self._ikBinders = self._serviceBag:GetService(require("IKBindersServer"))
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

	for _, player in pairs(Players:GetPlayers()) do
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
function IKService:GetRig(humanoid)
	return self._ikBinders.IKRig:Bind(humanoid)
end

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param humanoid Humanoid
	@return Promise<IKRig>
]=]
function IKService:PromiseRig(humanoid)
	assert(typeof(humanoid) == "Instance", "Bad humanoid")

	self._ikBinders.IKRig:Bind(humanoid)
	return self._ikBinders.IKRig:Promise(humanoid)
end

--[=[
	Unbinds the rig from the humanoid.
	@param humanoid Humanoid
]=]
function IKService:RemoveRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	self._ikBinders.IKRig:Unbind(humanoid)
end

--[=[
	Updates the ServerIKRig target for an NPC

	```lua
	local IKService = require("IKService")

	-- Make the NPC look at a target
	serviceBag:GetService(IKService):UpdateServerRigTarget(workspace.NPC.Humanoid, Vector3.new(0, 0, 0))
	```

	@param humanoid Humanoid
	@param target Vector3?
]=]
function IKService:UpdateServerRigTarget(humanoid, target)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")
	assert(typeof(target) == "Vector3", "Bad target")

	local serverRig = self._ikBinders.IKRig:Bind(humanoid)
	if not serverRig then
		warn("[IKService.UpdateServerRigTarget] - No serverRig")
		return
	end

	serverRig:SetRigTarget(target)
end

function IKService:_handlePlayerRemoving(player)
	self._maid[player] = nil
end

function IKService:_handlePlayer(player)
	local maid = Maid.new()

	local humanoidTracker = HumanoidTracker.new(player)
	maid:GiveTask(humanoidTracker)

	maid:GiveTask(humanoidTracker.AliveHumanoid.Changed:Connect(function(new, old)
		if old then
			self._ikBinders.IKRig:Unbind(old)
		end
		if new then
			self._ikBinders.IKRig:Bind(new)
		end
	end))

	if humanoidTracker.AliveHumanoid.Value then
		self._ikBinders.IKRig:Bind(humanoidTracker.AliveHumanoid.Value)
	end

	self._maid[player] = maid
end

function IKService:_updateStepped()
	debug.profilebegin("IKUpdateServer")

	for _, rig in pairs(self._ikBinders.IKRig:GetAll()) do
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

return IKService