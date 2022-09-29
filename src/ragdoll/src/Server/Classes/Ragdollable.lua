--[=[
	Should be bound to any humanoid that is ragdollable. See [RagdollBindersServer].
	@server
	@class Ragdollable
]=]

local require = require(script.Parent.loader).load(script)

local RxBrioUtils = require("RxBrioUtils")
local BaseObject = require("BaseObject")
local RagdollBindersServer = require("RagdollBindersServer")
local RxRagdollUtils = require("RxRagdollUtils")
local Maid = require("Maid")
local RagdollAdditionalAttachmentUtils = require("RagdollAdditionalAttachmentUtils")
local RagdollCollisionUtils = require("RagdollCollisionUtils")
local RagdollBallSocketUtils = require("RagdollBallSocketUtils")

local Ragdollable = setmetatable({}, BaseObject)
Ragdollable.ClassName = "Ragdollable"
Ragdollable.__index = Ragdollable

--[=[
	Constructs a new Ragdollable. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return Ragdollable
]=]
function Ragdollable.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), Ragdollable)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBindersServer = self._serviceBag:GetService(RagdollBindersServer)

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

			self._maid._configure = maid
		else
			self._maid._configure = nil
		end
	end))

	self._maid:GiveTask(self._ragdollBindersServer.Ragdoll:ObserveInstance(self._obj, function()
		self:_onRagdollChanged()
	end))
	self:_onRagdollChanged()

	return self
end

function Ragdollable:_onRagdollChanged()
	if self._ragdollBindersServer.Ragdoll:Get(self._obj) then
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

return Ragdollable