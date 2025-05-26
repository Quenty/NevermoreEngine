--[=[
	Handles IK rigging for a humanoid
	@class IKRigClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local IKRigAimerLocalPlayer = require("IKRigAimerLocalPlayer")
local IKRigBase = require("IKRigBase")
local IKRigInterface = require("IKRigInterface")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")

local IKRigClient = setmetatable({}, IKRigBase)
IKRigClient.ClassName = "IKRigClient"
IKRigClient.__index = IKRigClient

function IKRigClient.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(IKRigBase.new(humanoid, serviceBag), IKRigClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_setupRemoting()

	if self:GetPlayer() == Players.LocalPlayer then
		self:_setupLocalPlayer()
	end

	self._maid:Add(IKRigInterface.Client:Implement(self._obj, self))

	return self
end

--[=[
	Retrieves where the IK rig's position is, if it exists

	@return Vector3?
]=]
function IKRigClient:GetPositionOrNil(): Vector3?
	local rootPart = self._obj.RootPart
	if not rootPart then
		return nil
	end

	return rootPart.Position
end

--[=[
	Retrieves the local player aimer if it exists

	@return IKRigAimerLocalPlayer?
]=]
function IKRigClient:GetLocalPlayerAimer()
	return self._localPlayerAimer
end

--[=[
	Returns where the rig is looking at

	@return Vector3?
]=]
function IKRigClient:GetAimPosition(): Vector3?
	if self._localPlayerAimer then
		return self._localPlayerAimer:GetAimPosition()
	end

	return self._target
end

function IKRigClient:_setAimPosition(newTarget: Vector3?)
	assert(typeof(newTarget) == "Vector3" or newTarget == nil, "Bad newTarget")

	local torso = self:GetTorso()

	if torso then
		torso:Point(newTarget)
	end

	self._target = newTarget
end

function IKRigClient:_setupRemoting()
	self._remoting = self._maid:Add(Remoting.Client.new(self._obj, "IKRig"))

	self._maid:GiveTask(self._remoting.SetAimPosition:Connect(function(...)
		self:_setAimPosition(...)
	end))
end

function IKRigClient:_setupLocalPlayer()
	self._localPlayerAimer = self._maid:Add(IKRigAimerLocalPlayer.new(self._serviceBag, self))
end

function IKRigClient:FireSetAimPosition(newTarget: Vector3?)
	assert(self:GetPlayer() == Players.LocalPlayer, "Canot only fire from client")

	self._remoting.SetAimPosition:FireServer(newTarget)
end

return Binder.new("IKRig", IKRigClient)
