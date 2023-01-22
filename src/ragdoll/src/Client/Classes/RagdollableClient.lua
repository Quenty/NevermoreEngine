--[=[
	Should be bound via [RagdollBindersClient].

	@client
	@class RagdollableClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RagdollBindersClient = require("RagdollBindersClient")
local RxRagdollUtils = require("RxRagdollUtils")

local RagdollableClient = setmetatable({}, BaseObject)
RagdollableClient.ClassName = "RagdollableClient"
RagdollableClient.__index = RagdollableClient

--[=[
	Constructs a new RagdollableClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollableClient
]=]
function RagdollableClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollableClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBindersClient = self._serviceBag:GetService(RagdollBindersClient)

	self._maid:GiveTask(self._ragdollBindersClient.Ragdoll:ObserveInstance(self._obj, function()
		self:_onRagdollChanged()
	end))
	self:_onRagdollChanged()

	return self
end

function RagdollableClient:_onRagdollChanged()
	if self._ragdollBindersClient.Ragdoll:Get(self._obj) then
		self._maid._ragdoll = RxRagdollUtils.runLocal(self._obj)
	else
		self._maid._ragdoll = nil
	end
end

return RagdollableClient