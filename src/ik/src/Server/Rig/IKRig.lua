--!strict
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

export type IKRig =
	typeof(setmetatable(
		{} :: {
			_remoting: any,
			_aimPosition: Vector3?,
		},
		{} :: typeof({ __index = IKRig })
	))
	& IKRigBase.IKRigBase

function IKRig.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): IKRig
	local self: IKRig = setmetatable(IKRigBase.new(humanoid, serviceBag) :: any, IKRig)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	Motor6DStackHumanoid:Tag(self._obj :: Instance)

	self:_setupRemoting()

	self._maid:Add(IKRigInterface.Server:Implement(self._obj :: Instance, self))

	return self
end

--[=[
	Returns where the rig is looking at

	@return Vector3?
]=]
function IKRig.GetAimPosition(self: IKRig): Vector3?
	return self._aimPosition
end

--[=[
	Sets the IK Rig target and replicates it to the client

	@param target Vector3?
]=]
function IKRig.SetAimPosition(self: IKRig, target: Vector3?): ()
	assert(typeof(target) == "Vector3" or target == nil, "Bad target")

	self:_applyAimPosition(target)
	self._remoting.SetAimPosition:FireAllClients(target)
end

function IKRig._setupRemoting(self: IKRig): ()
	self._remoting = self._maid:Add(Remoting.Server.new(self._obj :: Instance, "IKRig"))

	self._maid:GiveTask(self._remoting.SetAimPosition:Connect(function(player: Player, target: Vector3?)
		assert(player == self:GetPlayer(), "Bad player")

		self:_applyAimPosition(target)
		self._remoting.SetAimPosition:FireAllClientsExcept(player, target)
	end))
end

function IKRig._applyAimPosition(self: IKRig, target: Vector3?): ()
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

return Binder.new("IKRig", IKRig :: any) :: Binder.Binder<IKRig>
