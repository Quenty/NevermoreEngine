--[=[
	Serverside implementation of IKRig
	@server
	@class IKRig
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local IKRigBase = require("IKRigBase")
local IKRigInterface = require("IKRigInterface")
local Motor6DStackHumanoid = require("Motor6DStackHumanoid")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")

local IKRig = setmetatable({}, IKRigBase)
IKRig.ClassName = "IKRig"
IKRig.__index = IKRig

function IKRig.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(IKRigBase.new(humanoid, serviceBag), IKRig)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	Motor6DStackHumanoid:Tag(self._obj)

	self:_setupRemoting()

	self._maid:Add(IKRigInterface.Server:Implement(self._obj, self))

	return self
end

--[=[
	Returns where the rig is looking at

	@return Vector3?
]=]
function IKRig:GetAimPosition(): Vector3?
	return self._aimPosition
end

--[=[
	Sets the IK Rig target and replicates it to the client

	@param target Vector3?
]=]
function IKRig:SetAimPosition(target: Vector3?)
	assert(typeof(target) == "Vector3" or target == nil, "Bad target")

	self:_applyAimPosition(target)
	self._remoting.SetAimPosition:FireAllClients(target)
end

function IKRig:_setupRemoting()
	self._remoting = self._maid:Add(Remoting.Server.new(self._obj, "IKRig"))

	self._maid:GiveTask(self._remoting.SetAimPosition:Connect(function(player, target)
		assert(player == self:GetPlayer(), "Bad player")

		self:_applyAimPosition(target)
		self._remoting.SetAimPosition:FireAllClientsExcept(player, target)
	end))
end

function IKRig:_applyAimPosition(target: Vector3?)
	assert(typeof(target) == "Vector3" or target == nil, "Bad target")

	-- Guard against NaN
	if target ~= target then
		return
	end

	self._aimPosition = target

	local torso = self:GetTorso()
	if torso then
		torso:Point(self._aimPosition)
	end
end

return Binder.new("IKRig", IKRig)
