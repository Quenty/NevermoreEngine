--[=[
	Initialize via [RagdollServiceClient].

	@client
	@class RagdollableClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local RagdollClient = require("RagdollClient")
local RagdollableBase = require("RagdollableBase")
local RagdollableInterface = require("RagdollableInterface")
local Rx = require("Rx")
local RxRagdollUtils = require("RxRagdollUtils")

local RagdollableClient = setmetatable({}, RagdollableBase)
RagdollableClient.ClassName = "RagdollableClient"
RagdollableClient.__index = RagdollableClient

--[=[
	Constructs a new RagdollableClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollableClient
]=]
function RagdollableClient.new(humanoid, serviceBag)
	local self = setmetatable(RagdollableBase.new(humanoid), RagdollableClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

	self._maid:GiveTask(self._ragdollBinder:Observe(self._obj):Subscribe(function(ragdoll)
		self:_onRagdollChanged(ragdoll)
	end))

	self._maid:GiveTask(RagdollableInterface.Client:Implement(self._obj, self))

	return self
end

function RagdollableClient:ObserveIsRagdolled()
	return self._ragdollBinder:Observe(self._obj):Pipe({
		Rx.map(function(value)
			return value and true or false
		end),
	})
end

function RagdollableClient:_onRagdollChanged(ragdoll)
	if ragdoll then
		self._maid._ragdoll = RxRagdollUtils.runLocal(self._obj)
	else
		self._maid._ragdoll = nil
	end
end

return Binder.new("Ragdollable", RagdollableClient)
