--[=[
	Serverside implementation of IKRig
	@server
	@class IKRig
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local IKRigBase = require("IKRigBase")
local IKConstants = require("IKConstants")
local CharacterUtils = require("CharacterUtils")
local Motor6DStackHumanoid = require("Motor6DStackHumanoid")
local Binder = require("Binder")

local IKRig = setmetatable({}, IKRigBase)
IKRig.ClassName = "IKRig"
IKRig.__index = IKRig

function IKRig.new(humanoid, serviceBag)
	local self = setmetatable(IKRigBase.new(humanoid, serviceBag), IKRig)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._remoteEvent = Instance.new("RemoteEvent")
	self._remoteEvent.Name = IKConstants.REMOTE_EVENT_NAME
	self._remoteEvent.Archivable = false
	self._remoteEvent.Parent = self._obj
	self._maid:GiveTask(self._remoteEvent)

	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_onServerEvent(...)
	end))

	Motor6DStackHumanoid:Tag(self._obj)

	self._target = nil

	return self
end

--[=[
	Returns where the rig is looking at

	@return Vector3?
]=]
function IKRig:GetTarget()
	return self._target
end

--[=[
	Sets the IK Rig target and replicates it to the client

	@param target Vector3?
]=]
function IKRig:SetRigTarget(target)
	assert(typeof(target) == "Vector3" or target == nil, "Bad target")

	self._target = target

	local torso = self:GetTorso()
	if torso then
		torso:Point(self._target)
	end

	self._remoteEvent:FireAllClients(target)
end

function IKRig:_onServerEvent(player, target)
	assert(player == CharacterUtils.getPlayerFromCharacter(self._obj), "Bad player")
	assert(typeof(target) == "Vector3" or target == nil, "Bad target")

	-- Guard against NaN
	if target ~= target then
		return
	end

	self._target = target

	local torso = self:GetTorso()
	if torso then
		torso:Point(self._target)
	end

	-- Do replication
	for _, other in pairs(Players:GetPlayers()) do
		if other ~= player then
			self._remoteEvent:FireClient(other, target) -- target may nil
		end
	end
end

return Binder.new("IKRig", IKRig)