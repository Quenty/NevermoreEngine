--[=[
	When a humanoid is tagged with this, it will unragdoll automatically.
	@server
	@class UnragdollAutomatically
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local RagdollBindersServer = require("RagdollBindersServer")
local CharacterUtils = require("CharacterUtils")
local AttributeValue = require("AttributeValue")
local Maid = require("Maid")
local UnragdollAutomaticallyConstants = require("UnragdollAutomaticallyConstants")

local UnragdollAutomatically = setmetatable({}, BaseObject)
UnragdollAutomatically.ClassName = "UnragdollAutomatically"
UnragdollAutomatically.__index = UnragdollAutomatically

--[=[
	Constructs a new UnragdollAutomatically. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return UnragdollAutomatically
]=]
function UnragdollAutomatically.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), UnragdollAutomatically)

	self._ragdollBindersServer = serviceBag:GetService(RagdollBindersServer)
	self._player = CharacterUtils.getPlayerFromCharacter(self._obj)

	self._disabledUnragdoll = AttributeValue.new(self._obj, UnragdollAutomaticallyConstants.DISABLE_UNRAGDOLL_AUTOMATICALLY_ATTRIBUTE, false)
	self._maid:GiveTask(self._disabledUnragdoll:Observe():Subscribe(function(isDisabled)
		if isDisabled then
			self._maid._updater = nil
			return
		end

		local maid = Maid.new()

		maid:GiveTask(self._ragdollBindersServer.Ragdoll:ObserveInstance(self._obj, function()
			self:_handleRagdollChanged(maid)
		end))
		self:_handleRagdollChanged(maid)

		self._maid._updater = maid
	end))

	return self
end

function UnragdollAutomatically:_getTime()
	if self._player then
		return 2
	else
		return 5
	end
end

function UnragdollAutomatically:_handleRagdollChanged(maid)
	if self._ragdollBindersServer.Ragdoll:Get(self._obj) then
		self._ragdollTime = tick()

		maid._conn = RunService.Stepped:Connect(function()
			if tick() - self._ragdollTime >= self:_getTime() then
				if self._obj.Health > 0 then
					self._ragdollBindersServer.Ragdoll:Unbind(self._obj)
				end
			end
		end)
	else
		maid._conn = nil
	end
end

return UnragdollAutomatically