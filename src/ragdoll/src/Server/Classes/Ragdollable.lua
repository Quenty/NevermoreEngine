--[=[
	Should be bound to any humanoid that is ragdollable. This class exports a [Binder].
	@server
	@class Ragdollable
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Motor6DBindersServer = require("Motor6DBindersServer")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")
local RagdollAdditionalAttachmentUtils = require("RagdollAdditionalAttachmentUtils")
local RagdollBallSocketUtils = require("RagdollBallSocketUtils")
local RagdollCollisionUtils = require("RagdollCollisionUtils")
local RagdollMotorUtils = require("RagdollMotorUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxRagdollUtils = require("RxRagdollUtils")

local Ragdollable = setmetatable({}, BaseObject)
Ragdollable.ClassName = "Ragdollable"
Ragdollable.__index = Ragdollable

--[=[
	Constructs a new Ragdollable. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return Ragdollable
]=]
function Ragdollable.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), Ragdollable)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)
	self._motor6DBindersServer = self._serviceBag:GetService(Motor6DBindersServer)

	self._motor6DBindersServer.Motor6DStackHumanoid:Bind(self._obj)

	-- Ensure predefined physics rig immediatelly on the server.
	-- We do this so during replication loop-back there's no chance of death.
	self._maid:GiveTask(RxBrioUtils.flatCombineLatest({
		character = RxRagdollUtils.observeCharacterBrio(self._obj);
		rigType = RxRagdollUtils.observeRigType(self._obj);
	}):Subscribe(function(state)
		if state.character and state.rigType then
			local maid = Maid.new()

			maid:GiveTask(RagdollAdditionalAttachmentUtils.ensureAdditionalAttachments(state.character, state.rigType))
			maid:GiveTask(RagdollBallSocketUtils.ensureBallSockets(state.character, state.rigType))
			maid:GiveTask(RagdollCollisionUtils.ensureNoCollides(state.character, state.rigType))

			-- Not super guarded against race conditions but it should be fine, as this is for debugging.
			RagdollMotorUtils.initMotorAttributes(state.character, state.rigType)

			self._maid._configure = maid
		else
			self._maid._configure = nil
		end
	end))

	self._maid:GiveTask(self._ragdollBinder:ObserveInstance(self._obj, function()
		self:_onRagdollChanged()
	end))
	self:_onRagdollChanged()

	return self
end

function Ragdollable:_onRagdollChanged()
	if self._ragdollBinder:Get(self._obj) then
		self:_setRagdollEnabled(true)
	else
		self:_setRagdollEnabled(false)
	end
end

function Ragdollable:_setRagdollEnabled(isEnabled)
	if isEnabled then
		if self._maid._ragdoll then
			return
		end

		self._maid._ragdoll = RxRagdollUtils.runLocal(self._obj)
	else
		self._maid._ragdoll = nil
	end
end

return PlayerHumanoidBinder.new("Ragdollable", Ragdollable)